import 'package:flutter/material.dart';

import '../api.dart';
import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../library.dart';
import '../papers.dart';
import '../policy.dart';
import '../widgets.dart';
import 'health_worker.dart';
import '../messages.dart';
import '../speech.dart';
import '../theme.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5];

/// Reads a page aloud item by item (lines, or table rows) with Repeat,
/// Previous and Next. Low-confidence items carry a spoken warning.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.result,
    this.paper,
    this.savedId,
  });
  final ReadResult result;

  /// Set when opened from My library: offers Delete instead of Save.
  final String? savedId;

  /// An everyday paper: adds its "read exactly as printed" note and, for health
  /// papers, the "Ask a pharmacist or nurse" button.
  final Paper? paper;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Speaker _speaker;
  int _index = 0;
  bool _playing = false;
  bool _saved = false;
  int _run = 0; // bumps on every command so an old reading loop stops
  int _speed = 1;

  List<ReadItem> get _items => widget.result.items;
  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play(0, intro: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _speaker = AppScope.of(context).speaker;
  }

  @override
  void dispose() {
    _run++;
    _speaker.stop();
    super.dispose();
  }

  String _position(ReadItem item) => switch (item) {
    ReadItem(isFaint: true) => _l.faintPrint,
    ReadItem(isRow: false) => _l.linePosition(item.number, item.total),
    ReadItem(table: final int t) => _l.rowPositionInTable(
      item.number,
      item.total,
      t,
    ),
    _ => _l.rowPosition(item.number, item.total),
  };

  String _where(ReadItem item) => switch (item.kind) {
    ItemKind.line => _l.whereLine(item.number),
    ItemKind.row => _l.whereRow(item.number),
    ItemKind.faint => pagePosition(_l, item.where),
  };

  String? _warning(ReadItem item) {
    final code = item.code;
    return code == null ? null : messageFor(_l, code, where: _where(item));
  }

  /// Text exactly as printed, except that a number the backend could not read
  /// reliably is said as "unclear number", never as the digit OCR guessed.
  String _spoken(ReadItem item) {
    final body = switch (item.kind) {
      ItemKind.faint => '',
      ItemKind.line => [
        for (final (i, w) in item.words.indexed)
          item.unclearWords.contains(i) ? _l.unclearNumber : w,
      ].join(' '),
      ItemKind.row =>
        '${_position(item)}. ${[for (final c in item.cells) (c.header.isEmpty ? '' : '${c.header}: ') + (c.unclear ? _l.unclearNumber : c.value)].join('. ')}',
    };
    final warning = _warning(item);
    final spoken = [if (body.isNotEmpty) body, ?warning].join('. ');
    return item.isRow && warning == null ? '$spoken.' : spoken;
  }

  String _counts() {
    final lines = _items.where((i) => i.kind == ItemKind.line).length;
    final rows = _items.where((i) => i.isRow).length;
    return [
      if (lines > 0) _l.lineCount(lines),
      if (rows > 0) _l.rowCount(rows),
    ].join(', ');
  }

  String _intro() {
    final unsure = widget.result.unsureCount;
    return [
      for (final tip in widget.result.tips) messageFor(_l, tip),
      _l.pageRead,
      '${_counts()}.',
      if (unsure > 0) _l.unsureSummary(unsure),
    ].join(' ');
  }

  /// Reads from [from] to the end, unless interrupted by another command.
  Future<void> _play(int from, {bool intro = false}) async {
    final run = ++_run;
    setState(() {
      _index = from;
      _playing = true;
    });
    // If TalkBack speaks over a line, say it again; if it is cut off again
    // (the learner is exploring), stop on that line. Never skip a line, a
    // dose or an amount unheard.
    void pause() {
      if (run == _run && mounted) setState(() => _playing = false);
    }

    bool wanted() => run == _run && mounted;
    if (intro && !await _speaker.sayThrough(_intro(), wanted: wanted)) {
      return pause();
    }
    for (var i = from; i < _items.length; i++) {
      if (!wanted()) return;
      setState(() => _index = i);
      if (!await _speaker.sayThrough(_spoken(_items[i]), wanted: wanted)) {
        return pause();
      }
    }
    if (run != _run || !mounted) return;
    setState(() => _playing = false);
    // Everyday papers end with their safety note (no advice; PIN never asked).
    await _speaker.say([_l.endOfPageHint, ?widget.paper?.note(_l)].join(' '));
  }

  Future<void> _sayOnly(int i) async {
    _run++;
    setState(() {
      _index = i;
      _playing = false;
    });
    await _speaker.say(_spoken(_items[i]));
  }

  void _prev() => _index > 0
      ? _go(_index - 1)
      : _speaker.say(_items[_index].isRow ? _l.firstRow : _l.firstLine);
  void _next() =>
      _index < _items.length - 1 ? _go(_index + 1) : _speaker.say(_l.endOfPage);
  void _repeat() => _go(_index);
  void _go(int i) => _playing ? _play(i) : _sayOnly(i);

  void _togglePause() {
    if (_playing) {
      _run++;
      _speaker.stop();
      setState(() => _playing = false);
    } else {
      _play(_index);
    }
  }

  Future<void> _cycleSpeed() async {
    setState(() => _speed = (_speed + 1) % _speeds.length);
    await _speaker.setRate(_speeds[_speed]);
    await _speaker.say(_l.speed(_speedValue()));
    if (_playing) _play(_index);
  }

  bool get _canSave =>
      AppScope.of(context).profile.can(Feature.library) &&
      widget.result.json != null;

  /// Keeps the page text (never the photo) on the phone for 30 days.
  Future<void> _save() async {
    _run++;
    await Library.save(widget.result, widget.paper);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _playing = false;
    });
    _speaker.say(_l.savedToLibrary);
  }

  Future<void> _delete() async {
    final l = _l;
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          l.deleteConfirm,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        actions: [
          SecondaryButton(
            label: l.cancel,
            onTap: () => Navigator.of(dialog).pop(false),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: l.deleteYes,
            onTap: () => Navigator.of(dialog).pop(true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await Library.delete(widget.savedId!);
    _speaker.say(l.deletedFromLibrary);
    if (mounted) Navigator.of(context).pop();
  }

  // "1×" not "1.0×", the same on web and Android.
  String _speedValue() =>
      '${_speeds[_speed].toString().replaceFirst(RegExp(r'\.0$'), '')}×';

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final item = _items[_index];
    final row = item.isRow;
    final warning = _warning(item);
    final unsure = widget.result.unsureCount;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: l.backToHome,
                    excludeSemantics: true,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: outlinedTile(radius: 32).copyWith(
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      ),
                      child: const Icon(Icons.chevron_left, size: 32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.paper?.title(l) ?? l.yourPage,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${widget.paper != null ? '${l.readExactly} · ' : ''}${_counts()}${unsure > 0 ? ' · ${l.unclearCount(unsure)}' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: MaganaColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ItemCard(
                        item: item,
                        position: _position(item),
                        status: _playing ? l.nowReading : null,
                      ),
                      if (warning != null) ...[
                        const SizedBox(height: 16),
                        _WarningNote(text: warning),
                      ],
                      if (_canSave) ...[
                        const SizedBox(height: 16),
                        if (widget.savedId != null)
                          SecondaryButton(
                            label: l.deleteFromLibrary,
                            onTap: _delete,
                          )
                        else if (_saved)
                          Semantics(
                            liveRegion: true,
                            child: NoteBox(
                              text: l.savedToLibrary,
                              kind: NoteKind.privacy,
                            ),
                          )
                        else
                          SecondaryButton(label: l.saveToLibrary, onTap: _save),
                      ],
                      if (widget.paper case final paper?) ...[
                        const SizedBox(height: 16),
                        NoteBox(text: paper.note(l)),
                        if (paper.isHealth) ...[
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: l.askPharmacistOrNurse,
                            onTap: () => openHealthWorker(
                              context,
                              reason: paper == Paper.report
                                  ? 'results'
                                  : 'medicine',
                            ),
                          ),
                          const SizedBox(height: 12),
                          const EmergencyBanner(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ControlButton(
                      label: l.previous,
                      semantics: row ? l.previousRow : l.previousLine,
                      onPressed: _prev,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ControlButton(
                      label: l.repeat,
                      semantics: row ? l.repeatRow : l.repeatLine,
                      onPressed: _repeat,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ControlButton(
                      label: l.next,
                      semantics: row ? l.nextRow : l.nextLine,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ControlButton(
                label: l.speed(_speedValue()),
                semantics: l.speedLabel(_speedValue()),
                onPressed: _cycleSpeed,
              ),
              const SizedBox(height: 10),
              Semantics(
                button: true,
                label: _playing ? l.pauseLabel : l.playLabel,
                excludeSemantics: true,
                onTap: _togglePause,
                child: OutlinedButton.icon(
                  onPressed: _togglePause,
                  icon: Icon(
                    _playing ? Icons.pause : Icons.play_arrow,
                    size: 30,
                  ),
                  label: Text(_playing ? l.pause : l.play),
                  style: outlinedTile(radius: 36, bg: MaganaColors.amber)
                      .copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(72),
                        ),
                        side: const WidgetStatePropertyAll(
                          BorderSide(color: MaganaColors.ink, width: 3),
                        ),
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: fontFamily,
                            fontFamilyFallback: fontFallback,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.position, this.status});
  final ReadItem item;
  final String position;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: position,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MaganaColors.green, width: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Text(
                status == null ? position : '$position · $status',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: MaganaColors.green,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (item.isRow)
              for (final c in item.cells)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (c.header.isNotEmpty)
                        Text(
                          c.header,
                          style: const TextStyle(
                            fontSize: 15,
                            color: MaganaColors.muted,
                          ),
                        ),
                      Text.rich(
                        c.unclear ? _unclear(context) : TextSpan(text: c.value),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
            else if (!item.isFaint)
              Text.rich(
                TextSpan(
                  children: [
                    for (final (i, w) in item.words.indexed) ...[
                      if (i > 0) const TextSpan(text: ' '),
                      item.unclearWords.contains(i)
                          ? _unclear(context)
                          : TextSpan(text: w),
                    ],
                  ],
                ),
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A number the backend could not read reliably: shown as "[unclear number]",
/// highlighted, never as the digit OCR guessed.
TextSpan _unclear(BuildContext context) => TextSpan(
  text: '[${AppLocalizations.of(context).unclearNumber}]',
  style: const TextStyle(
    backgroundColor: MaganaColors.warnFill,
    color: MaganaColors.warnInk,
  ),
);

class _WarningNote extends StatelessWidget {
  const _WarningNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MaganaColors.warnFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MaganaColors.warnBorder, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: 26,
                color: MaganaColors.warnBorder,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color: MaganaColors.warnInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.label,
    required this.semantics,
    required this.onPressed,
  });
  final String label;
  final String semantics;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      onTap: onPressed,
      child: OutlinedButton(
        onPressed: onPressed,
        style: outlinedTile(),
        child: Text(label),
      ),
    );
  }
}
