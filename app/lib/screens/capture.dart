import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../theme.dart';
import 'reader.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.picker});

  /// Injectable for tests.
  final Future<XFile?> Function(ImageSource source)? picker;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  String? _status; // null: show the framing guidance
  bool _busy = false;

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _say(_l.framingGuidance),
    );
  }

  void _say(String text) {
    if (mounted) AppScope.of(context).speaker.say(text);
  }

  void _setStatus(String text) {
    setState(() => _status = text);
    _say(text);
  }

  Future<XFile?> _pick(ImageSource source) {
    if (widget.picker != null) return widget.picker!(source);
    // Large enough for small print, small enough to upload on a slow connection.
    return ImagePicker().pickImage(
      source: source,
      maxWidth: 2400,
      imageQuality: 88,
    );
  }

  Future<void> _capture(ImageSource source) async {
    if (_busy) return;
    final scope = AppScope.of(context);
    final XFile? photo;
    try {
      photo = await _pick(source);
    } catch (_) {
      _setStatus(_l.cameraFailed);
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    _setStatus(_l.readingPage);
    try {
      final result = await scope.api.read(
        await photo.readAsBytes(),
        filename: photo.name,
      );
      if (!mounted) return;
      if (result.readableCount == 0) {
        _setStatus(
          [
            for (final tip in result.tips) messageFor(_l, tip),
            for (final f in result.items.where((i) => i.isFaint))
              messageFor(_l, 'faint_region', where: pagePosition(_l, f.where)),
            _l.noTextFound,
          ].join(' '),
        );
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReaderScreen(result: result)),
      );
    } on ApiException catch (e) {
      _setStatus(messageFor(_l, e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final status = _status ?? l.framingGuidance;
    final onDark = outlinedTile(
      radius: 32,
      bg: Colors.transparent,
      fg: Colors.white,
      border: Colors.white,
    );
    return Scaffold(
      backgroundColor: MaganaColors.camera,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: l.backToHome,
                    excludeSemantics: true,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: onDark.copyWith(
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      ),
                      child: const Icon(Icons.chevron_left, size: 32),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l.readPage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: minTarget),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ExcludeSemantics(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2F33),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    alignment: Alignment.center,
                    child: _busy
                        ? const SizedBox(
                            width: 64,
                            height: 64,
                            child: CircularProgressIndicator(
                              color: MaganaColors.amber,
                              strokeWidth: 6,
                            ),
                          )
                        : const Icon(
                            Icons.crop_free,
                            size: 120,
                            color: Color(0xFFA9A496),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                container: true,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ExcludeSemantics(
                        child: Icon(
                          Icons.volume_up_outlined,
                          size: 30,
                          color: MaganaColors.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: MaganaColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l.repeatInstructions,
                      excludeSemantics: true,
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _say(status),
                        style: onDark,
                        child: Text(l.repeat, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: l.takePhoto,
                    enabled: !_busy,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _capture(ImageSource.camera),
                        style: FilledButton.styleFrom(
                          backgroundColor: MaganaColors.amber,
                          foregroundColor: MaganaColors.ink,
                          shape: const CircleBorder(
                            side: BorderSide(color: Colors.white, width: 5),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l.galleryLabel,
                      enabled: !_busy,
                      excludeSemantics: true,
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _capture(ImageSource.gallery),
                        style: onDark,
                        child: Text(l.gallery, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
