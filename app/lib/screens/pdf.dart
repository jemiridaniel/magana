import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../papers.dart';
import '../platform/shared_pdf.dart';
import '../policy.dart';
import '../help_check.dart';
import '../tasks.dart';
import '../widgets.dart';
import 'reader.dart';

/// Picks a PDF from the phone's files. Replaceable in tests.
Future<SharedPdf?> Function() pickPdf = () async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ],
  );
  if (file == null) return null;
  return SharedPdf(await file.readAsBytes(), file.name);
};

/// Read a PDF: a bank statement, result or letter sent to the phone. Every page is
/// read in one go (backend pdfs.py): pages with a text layer exactly as printed,
/// scanned pages through OCR and its warnings. A locked PDF asks for its password,
/// which opens the file for that one request and is never saved.
class PdfScreen extends StatefulWidget {
  const PdfScreen({super.key, this.shared});

  /// Opened with Magana from another app; otherwise the user chooses a file.
  final SharedPdf? shared;

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  SharedPdf? _pdf;
  bool _busy = false;
  bool _locked = false;
  String? _status;
  final _password = TextEditingController();

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _pdf = widget.shared;
    speakOnOpen(context, () {
      final l = AppLocalizations.of(context);
      return widget.shared != null
          ? l.pdfShared(widget.shared!.name)
          : '${l.pdfTitle}. ${l.pdfBody}';
    });
    if (widget.shared != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _pdf = null;
    super.dispose();
  }

  void _say(String text) {
    setState(() => _status = text);
    AppScope.of(context).speaker.say(text);
  }

  /// Everyday papers for 18+ (worked out from the words, with the strict checks);
  /// schoolwork for everyone else.
  String get _mode => AppScope.of(context).profile.can(Feature.everydayLetters)
      ? Paper.letter.mode
      : 'school';

  Future<void> _choose() async {
    if (_busy) return;
    final SharedPdf? pdf;
    try {
      pdf = await pickPdf();
    } catch (_) {
      _say(messageFor(_l, 'unreadable_pdf'));
      return;
    }
    if (!mounted) return;
    if (pdf == null) {
      _say(_l.pdfNotChosen);
      return;
    }
    setState(() {
      _pdf = pdf;
      _locked = false;
      _password.clear();
    });
    await _send();
  }

  Future<void> _send() async {
    final pdf = _pdf;
    if (pdf == null || _busy) return;
    if (_locked && _password.text.isEmpty) {
      _say(_l.pdfPasswordEmpty);
      return;
    }
    final scope = AppScope.of(context);
    final mode = _mode;
    setState(() => _busy = true);
    _say(_l.pdfReading);
    try {
      final result = await scope.api.readPdf(
        pdf.bytes,
        filename: pdf.name,
        mode: mode,
        password: _locked ? _password.text : null,
      );
      _password.clear();
      if (!mounted) return;
      final detect = mode == Paper.letter.mode;
      final paper = detect ? detectPaper(result) : null;
      await TaskLog.record(TaskKind.forPaper(paper));
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            result: result,
            paper: paper,
            detected: detect,
            helpTask: HelpTask.pdf,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final locked =
          e.code == 'pdf_password_needed' || e.code == 'pdf_password_wrong';
      setState(() {
        _busy = false;
        _locked = locked || _locked;
        if (!locked) _pdf = null;
      });
      _password.clear();
      _say(messageFor(_l, e.code));
    }
  }

  String _spelled(String text) => text.split('').join(', ');

  @override
  Widget build(BuildContext context) {
    final l = _l;
    return PageScaffold(
      body: [
        ScreenHeader(title: l.pdfTitle, subtitle: _locked ? null : l.pdfBody),
        if (_locked) ...[
          Semantics(
            header: true,
            child: Text(
              l.pdfPasswordTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            l.pdfPasswordBody,
            style: const TextStyle(fontSize: 18, height: 1.45),
          ),
          // Shown as typed, not as dots: TalkBack says each character, and a
          // low-vision user can check it. Never saved, never sent anywhere else.
          TextField(
            controller: _password,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontSize: 26, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: l.pdfPasswordLabel,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _send(),
          ),
          SecondaryButton(
            label: l.pdfPasswordReadBack,
            onTap: () => AppScope.of(context).speaker.say(
              _password.text.isEmpty
                  ? l.pdfPasswordEmpty
                  : l.pdfPasswordSays(_spelled(_password.text)),
            ),
          ),
          NoteBox(text: l.pdfPasswordNote, kind: NoteKind.privacy),
        ],
        if (_status != null)
          Semantics(
            liveRegion: true,
            child: Text(_status!, style: const TextStyle(fontSize: 20)),
          ),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ],
      bottom: [
        if (_locked)
          PrimaryButton(label: l.pdfOpen, onTap: _busy ? null : _send)
        else
          PrimaryButton(label: l.pdfChoose, onTap: _busy ? null : _choose),
      ],
    );
  }
}
