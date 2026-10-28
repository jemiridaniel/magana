import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../amount_check.dart';
import '../api.dart';
import '../app_scope.dart';
import '../commands.dart';
import '../help_check.dart';
import '../language.dart';
import '../offline/offline_reader.dart';
import '../offline/photo_queue.dart';
import '../offline/read_timing.dart';
import '../l10n/app_localizations.dart';
import '../library.dart';
import '../papers.dart';
import '../policy.dart';
import '../layout.dart';
import '../widgets.dart';
import 'capture.dart';
import '../questions.dart';
import '../voice_input.dart';
import 'explain.dart';
import 'health_worker.dart';
import 'reminders.dart';
import 'report_problem.dart';
import '../messages.dart';
import '../speech.dart';
import '../spoken_numbers.dart';
import '../theme.dart';
import '../warnings.dart';
import '../touch.dart';

const _speeds = [0.75, 1.0, 1.25, 1.5];

/// Reads a page aloud item by item (lines, or table rows) with Repeat,
/// Previous and Next. Low-confidence items carry a spoken warning.
/// Boards 5c, 5d, 5e: a page in columns is read column by column, with "Next
/// column", headings and a small page map; a Hausa, Yorùbá or Igbo page warns once
/// that special letters can be missed and marks words that may have lost one
/// ("Spell word", "Ask someone"; a word is never changed); a page read on the
/// phone without the server says so and what it can't do.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.result,
    this.paper,
    this.savedId,
    this.detected = false,
    this.offlineReason,
    this.queued = false,
    this.helpTask = HelpTask.page,
  });

  /// Asked about when the page is finished: "Did you read this page on your own?" (board 8).
  final HelpTask helpTask;

  /// Read on this phone (board 5e): why, for the banner. Null when the server read it.
  final OfflineReason? offlineReason;

  /// The photo waits, encrypted, for a full reading when the phone is online.
  final bool queued;

  /// "Read any paper": [paper] was worked out from the page's words.
  final bool detected;
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
  bool _askedAboutResult = false; // E2: "What does this mean?"
  String? _resultQuestion;
  bool _questionSaved = false;
  int _run = 0; // bumps on every command so an old reading loop stops
  int _speed = 1;
  bool _fullReading = true; // "Full reading when online" (offline pages)
  bool _listening = false;
  final _heard =
      <int>{}; // items said to the end: the page is finished at the last or 80%
  bool _helpAsked = false;

  List<ReadItem> get _items => widget.result.items;
  int get _columns => widget.result.columns;

  /// Each line's place within its column: (number, total), for "Line 2 of 9".
  late final List<(int, int)> _inColumn = () {
    final totals = <int, int>{};
    final out = <(int, int)>[];
    for (final i in _items) {
      if (i.kind == ItemKind.line) {
        totals[i.column] = (totals[i.column] ?? 0) + 1;
      }
    }
    final seen = <int, int>{};
    for (final i in _items) {
      final n = seen[i.column] = (seen[i.column] ?? 0) + 1;
      out.add((n, totals[i.column] ?? 0));
    }
    return out;
  }();

  String get _languageName => appLanguages
      .firstWhere(
        (a) => a.code == widget.result.pageLanguage,
        orElse: () => appLanguages.first,
      )
      .name;
  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play(0, intro: true));
    if (widget.result.offline) {
      FullReadingSetting.get().then((on) {
        if (mounted) setState(() => _fullReading = on);
      });
    }
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
    ReadItem(isFaint: true, code: 'missed_line') => _l.missedLineLabel,
    ReadItem(isFaint: true) => _l.faintPrint,
    ReadItem(isRow: false, column: final int c) when _columns > 1 && c > 0 =>
      _l.columnPosition(
        c,
        _columns,
        _inColumn[_items.indexOf(item)].$1,
        _inColumn[_items.indexOf(item)].$2,
      ),
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
    final i = _items.indexOf(item);
    final body = _body(item);
    final warning = _warning(item);
    final page = item.pageStart
        ? _l.pageOf(item.page!, widget.result.pageCount)
        : null;
    // Entering a column: "Column 2 of 2" first (TalkBack users hear where they are).
    final column =
        _columns > 1 &&
            item.column > 0 &&
            (i <= 0 || _items[i - 1].column != item.column)
        ? _l.columnStart(item.column, _columns)
        : null;
    final marked = _marked(item);
    // Doubt is said briefly at the spot ("unclear number" in place of digits, "Unclear." at the
    // end of a line); the full warnings are on request ("what's unclear?", warnings.dart). A
    // band of faint print is its own item: its warning is what it says.
    final marks = PageWarnings.marks(_l, item);
    final spoken = [
      ?page,
      ?column,
      // Said, not shown: naira amounts and long numbers (account numbers) read naturally.
      if (body.isNotEmpty)
        item.heading
            ? _l.headingSpoken(spokenNumbers(body))
            : spokenNumbers(body),
      if (marked.isNotEmpty) _l.letterCheckWords(marked.join(', ')),
      ...marks,
      if (item.isFaint) ?warning,
    ].join('. ');
    return item.isRow && marks.isEmpty ? '$spoken.' : spoken;
  }

  late final _warnings = PageWarnings(_items);

  /// "What's unclear?": every spot and its full warning, in reading order.
  void _whatsUnclear() {
    _run++;
    setState(() => _playing = false);
    final details = _warnings.details(_l, _where);
    _speaker.say(details.isEmpty ? _l.whatsUnclearNone : details.join(' '));
  }

  /// Words on [item] that may have lost a special letter, as read (never changed).
  /// A word with a digit inside is already said as "unclear letter": never named here,
  /// so its digit is never said as a number.
  List<String> _marked(ReadItem item) => [
    for (final i in item.letterMarks.toList()..sort())
      if (i < item.words.length && !item.unclearLetters.contains(i))
        item.words[i],
  ];

  /// "Spell word": each marked word on this line, letter by letter.
  Future<void> _spell() async {
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    final item = _items[_index];
    final marked = [
      for (final i in item.letterMarks.toList()..sort())
        if (i < item.words.length) i,
    ];
    if (marked.isEmpty) {
      _speaker.say(_l.spellNone);
      return;
    }
    // Letter by letter; a digit inside a word is said as "unclear letter", and that word is
    // named "unclear letter" too, so the digit is never said as a number.
    String letter(String c) => RegExp(r'\d').hasMatch(c) ? _l.unclearLetter : c;
    _speaker.say(
      [
        for (final i in marked)
          '${item.unclearLetters.contains(i) ? _l.unclearLetter : item.words[i]}: '
              '${item.words[i].replaceAll(RegExp(r"[^\p{L}\d'’]", unicode: true), '').characters.map(letter).join(', ')}',
      ].join('. '),
    );
  }

  /// "Ask someone": only a person can say which letter the word has.
  Future<void> _askSomeone() async {
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    _speaker.say(_l.askSomeoneText(_languageName));
  }

  /// "Next column": the first line of the next column.
  void _nextColumn() {
    final here = _items[_index].column;
    for (var i = _index + 1; i < _items.length; i++) {
      final c = _items[i].column;
      if (c > 0 && c != here && _items[i - 1].column != c) return _go(i);
    }
    _speaker.say(_columns > 1 ? _l.lastColumn : _l.noColumns);
  }

  /// "Speak a command": next, back, repeat, pause, read, next column, headings, spell.
  Future<void> _command() async {
    final l = _l;
    final voice = voiceInputFor(context);
    if (_listening) {
      await voice.stop();
      return;
    }
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    if (!await voice.init()) {
      _speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    setState(() => _listening = true);
    List<String> heard;
    try {
      heard = await voice.listen(language: 'en');
    } on VoiceStepFailed {
      heard = const [];
    }
    if (!mounted) return;
    setState(() => _listening = false);
    if (heard.isEmpty) {
      _speaker.say(l.commandNothingHeard);
      return;
    }
    switch (matchReaderCommand(heard.first)) {
      case null:
        _speaker.say(l.commandNotUnderstood(heard.first));
      case ReaderCommand.nextColumn:
        _nextColumn();
      case ReaderCommand.headings:
        _jump(only: _JumpKind.headings);
      case ReaderCommand.spell:
        _spell();
      case ReaderCommand.next:
        _next();
      case ReaderCommand.previous:
        _prev();
      case ReaderCommand.repeat:
        _repeat();
      case ReaderCommand.pause:
        break; // listening already paused the reading
      case ReaderCommand.play:
        _play(_index);
      case ReaderCommand.help:
        _speaker.say(l.readerCommandHelp);
      case ReaderCommand.unclear:
        _whatsUnclear();
      case ReaderCommand.report:
        _run++;
        _speaker.stop();
        openReportProblem(context, screen: 'reader', pageText: _pageText());
    }
  }

  /// The page as read, for a problem report (sent only if the person switches it on).
  String _pageText() => [
    for (final i in _items)
      if (!i.isFaint)
        i.isRow ? i.cells.map((c) => c.value).join(' | ') : i.text,
  ].join('\n');

  /// An item's text without its warning; unclear numbers stay "unclear number".
  String _body(ReadItem item) {
    return switch (item.kind) {
      ItemKind.faint => '',
      ItemKind.line => [
        for (final (i, w) in item.words.indexed)
          if (!item.heldSign(i))
            item.unclearAmounts.contains(i)
                ? _l.amountUnclear
                : item.unclearWords.contains(i)
                ? _l.unclearNumber
                : item.currencyUnclear.contains(i)
                ? '${digitsOf(w, sign: item.signBefore(i))}, ${_l.currencyUnclear}'
                : item.unclearLetters.contains(i)
                ? _l.unclearLetter
                : w,
      ].join(' '),
      ItemKind.row =>
        '${_position(item)}. ${[for (final c in item.cells) (c.header.isEmpty ? '' : '${c.header}: ') + (c.unclear
                  ? (c.amount ? _l.amountUnclear : _l.unclearNumber)
                  : c.currencyUnclear
                  ? '${digitsOf(c.value)}, ${_l.currencyUnclear}'
                  : c.value)].join('. ')}',
    };
  }

  /// E2 "What does this mean?": Magana never interprets a result. It says so,
  /// and offers to save the question for the next visit or ask a nurse.
  Future<void> _askAboutResult() async {
    final lang = Localizations.localeOf(context).languageCode;
    final voice = voiceInputFor(context);
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    String? question;
    try {
      if (await voice.init()) {
        final heard = await voice.listen(language: lang);
        if (heard.isNotEmpty) question = heard.first;
      }
    } on VoiceStepFailed {
      // No recogniser this account may use: the fixed answer still follows.
    }
    if (!mounted) return;
    setState(() {
      _askedAboutResult = true;
      _resultQuestion = question;
      _questionSaved = false;
    });
    _speaker.say(
      [if (question != null) _l.youAsked(question), _l.resultAnswer].join(' '),
    );
  }

  Future<void> _saveQuestion() async {
    final question = _resultQuestion ?? _l.askAboutResult;
    await SavedQuestions.add(
      _l.questionAbout(question, _position(_items[_index])),
    );
    if (!mounted) return;
    setState(() => _questionSaved = true);
    _speaker.say(_l.questionSaved);
  }

  /// E3: the balance lines of a statement, read exactly as printed.
  List<String> get _balances => [
    for (final item in _items)
      if (!item.isRow &&
          !item.isFaint &&
          item.text.toLowerCase().contains('balance'))
        _body(item),
  ];

  /// E3 "Find a transaction": the next row (or line) holding the words, date or
  /// amount the learner says or types. Commas are ignored ("6,450" = "6450"). A number or
  /// amount held back is never matched: finding it would say what it is.
  Future<void> _find() async {
    final l = _l;
    _run++;
    setState(() => _playing = false);
    await _speaker.stop();
    if (!mounted) return;
    _speaker.say(l.findPrompt);
    final query = await showDialog<String>(
      context: context,
      builder: (_) => const _FindDialog(),
    );
    final q = query?.trim() ?? '';
    if (q.isEmpty || !mounted) return;
    String norm(String t) => t.toLowerCase().replaceAll(',', '');
    final target = norm(q);
    final n = _items.length;
    for (var step = 1; step <= n; step++) {
      final i = (_index + step) % n;
      final item = _items[i];
      final text = item.isRow
          ? item.cells.where((c) => !c.unclear).map((c) => c.value).join(' ')
          : [
              for (final (i, w) in item.words.indexed)
                if (!item.unclearWords.contains(i)) w,
            ].join(' ');
      if (norm(text).contains(target)) return _go(i);
    }
    _speaker.say(l.findNoMatch(q));
  }

  /// Explain this (a preview until N-ATLAS is hosted): the page as Magana read
  /// it, so an explanation can only build on what was read reliably.
  void _explain() {
    _run++;
    setState(() => _playing = false);
    _speaker.stop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExplainScreen(
          lines: [
            for (final item in _items)
              if (!item.isFaint) _body(item),
          ],
          source: widget.paper?.title(_l) ?? _l.yourPage,
          mode: widget.paper?.mode ?? 'school',
        ),
      ),
    );
  }

  /// Jump within page: the start, each heading, column and table, or the next
  /// thing Magana is unsure about. [only] shows one kind (the Headings, Columns
  /// and Tables chips). Diagrams need layout the backend doesn't send yet.
  Future<void> _jump({_JumpKind? only}) async {
    final l = _l;
    final tables = <int, int>{}; // table number -> first row index
    for (final (i, item) in _items.indexed) {
      if (item.isRow && item.number == 1) tables[item.table ?? 1] = i;
    }
    final headings = [
      for (final (i, item) in _items.indexed)
        if (item.heading) (item.text, i),
    ];
    final columns = <int, int>{}; // column -> first line index
    if (_columns > 1) {
      for (final (i, item) in _items.indexed) {
        if (item.column > 0) columns.putIfAbsent(item.column, () => i);
      }
    }
    final unsure = _items.indexed
        .where((e) => e.$1 > _index && e.$2.unsure)
        .map((e) => e.$1)
        .firstOrNull;
    final empty = switch (only) {
      _JumpKind.headings when headings.isEmpty => l.noHeadings,
      _JumpKind.columns when columns.isEmpty => l.noColumns,
      _JumpKind.tables when tables.isEmpty => l.noTables,
      _ => null,
    };
    if (empty != null) {
      _speaker.say(empty);
      return;
    }
    final choices = [
      if (only == null) (l.jumpStart, 0),
      if (only == null || only == _JumpKind.headings)
        for (final (text, i) in headings) ('${l.headingLabel}: $text', i),
      if (only == null || only == _JumpKind.columns)
        for (final MapEntry(key: c, value: i) in columns.entries)
          (l.columnLabel(c), i),
      if (only == null || only == _JumpKind.tables)
        for (final MapEntry(key: n, value: i) in tables.entries)
          (l.jumpTable(n), i),
      if (only == null && unsure != null) (l.jumpWarnings, unsure),
    ];
    final target = await showModalBottomSheet<int>(
      context: context,
      // TalkBack lands on the sheet's question, not a "Dismiss" handle above it.
      showDragHandle: !screenReaderOn(context),
      backgroundColor: MaganaColors.ground,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.jumpWithinPage,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final (label, index) in choices) ...[
                SecondaryButton(
                  label: label,
                  onTap: () => Navigator.of(sheet).pop(index),
                ),
                const SizedBox(height: 10),
              ],
              if (only == null) NoteBox(text: l.jumpNotYet),
            ],
          ),
        ),
      ),
    );
    if (target != null && mounted) _go(target);
  }

  String _counts() {
    final lines = _items.where((i) => i.kind == ItemKind.line).length;
    final rows = _items.where((i) => i.isRow).length;
    return [
      if (lines > 0) _l.lineCount(lines),
      if (rows > 0) _l.rowCount(rows),
    ].join(', ');
  }

  String? get _offlineBanner => switch (widget.offlineReason) {
    OfflineReason.noInternet => _l.offlineBanner,
    OfflineReason.sendFailed => _l.offlineBannerSendFailed,
    OfflineReason.slow => _l.offlineBannerTimeout(serverWait.inSeconds),
    OfflineReason.serverError => _l.offlineBannerServerError,
    OfflineReason.waking => _l.offlineBannerWaking,
    OfflineReason.busy => _l.offlineBannerBusy,
    OfflineReason.dailyLimit => _l.offlineBannerDailyLimit,
    null => widget.result.offline ? _l.offlineBanner : null,
  };

  String _intro() {
    final marks = widget.result.letterMarkCount;
    return [
      if (widget.result.offline) ...[
        ?_offlineBanner,
        _l.offlineNote,
        if (widget.queued) _l.offlineQueued,
      ],
      if (widget.detected && widget.paper != null)
        _l.detectedPaper(widget.paper!.title(_l)),
      if (_columns > 1) _l.columnsNote(_columns),
      for (final tip in widget.result.tips) messageFor(_l, tip),
      if (widget.result.pageLanguage != null && marks > 0)
        _l.letterCount(marks),
      _l.pageRead,
      '${_counts()}.',
      ..._warnings.summary(_l),
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
    if (intro) ReadTiming.firstWord(offline: widget.result.offline);
    if (intro && !await _speaker.sayThrough(_intro(), wanted: wanted)) {
      return pause();
    }
    for (var i = from; i < _items.length; i++) {
      if (!wanted()) return;
      setState(() => _index = i);
      if (!await _speaker.sayThrough(_spoken(_items[i]), wanted: wanted)) {
        return pause();
      }
      _heard.add(i);
    }
    if (run != _run || !mounted) return;
    setState(() => _playing = false);
    // Everyday papers end with their safety note (no advice; PIN never asked).
    await _speaker.say([_l.endOfPageHint, ?widget.paper?.note(_l)].join(' '));
    if (run == _run) await _askForHelp();
  }

  Future<void> _sayOnly(int i) async {
    final run = ++_run;
    setState(() {
      _index = i;
      _playing = false;
    });
    if (await _speaker.say(_spoken(_items[i]))) _heard.add(i);
    if (run == _run) await _askForHelp();
  }

  /// "Did you read this page on your own?" once the page is finished: its last item heard,
  /// or 80% of its items. At most once a day (help_check.dart).
  Future<void> _askForHelp() async {
    final n = _items.length;
    final finished =
        n > 0 && (_heard.contains(n - 1) || _heard.length >= (n * 0.8).ceil());
    if (_helpAsked || !finished || !mounted) return;
    _helpAsked = true;
    await maybeAskForHelp(context, widget.helpTask);
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

  /// Explain needs the server: not on a page read offline.
  bool get _canExplain =>
      !widget.result.offline &&
      AppScope.of(context).profile.can(Feature.explain);

  Future<void> _toggleFullReading() async {
    final on = !_fullReading;
    setState(() => _fullReading = on);
    await FullReadingSetting.set(on);
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
    if (!mounted) return;
    // Said once the Reader has closed (a change of screen stops its own voice).
    final voice = AppScope.app(context).speaker;
    Navigator.of(context).pop();
    voice.say(l.deletedFromLibrary);
  }

  // "1×" not "1.0×", the same on web and Android.
  String _speedValue() =>
      '${_speeds[_speed].toString().replaceFirst(RegExp(r'\.0$'), '')}×';

  // ---------- Board T2: the page itself, for low-vision readers on a tablet

  /// Text size and colours of the page view; kept from page to page.
  static double _zoom = 26;
  static bool _contrast = false;
  static const _zoomMin = 18.0, _zoomMax = 48.0;
  final _lineKeys = <int, GlobalKey>{};
  int? _shownIndex;

  /// An item as the page view shows it: unclear numbers never as digits.
  String _plain(ReadItem item) {
    final unclear = '[${_l.unclearNumber}]';
    final amount = '[${_l.amountUnclear}]';
    if (item.isRow) {
      return [
        for (final c in item.cells)
          [
            if (c.header.isNotEmpty) '${c.header}:',
            c.unclear
                ? (c.amount ? amount : unclear)
                : c.currencyUnclear
                ? '${digitsOf(c.value)} [${_l.currencyUnclear}]'
                : c.value,
          ].join(' '),
      ].join(' · ');
    }
    if (item.isFaint) return '…';
    return [
      for (final (i, w) in item.words.indexed)
        if (!item.heldSign(i))
          item.unclearAmounts.contains(i)
              ? amount
              : item.unclearWords.contains(i)
              ? unclear
              : item.currencyUnclear.contains(i)
              ? '${digitsOf(w, sign: item.signBefore(i))} [${_l.currencyUnclear}]'
              : w,
    ].join(' ');
  }

  /// Every line of the page, the one being read highlighted and kept in view. Visual only:
  /// a screen reader hears the same text from the reading panel, so it isn't read twice.
  Widget _pageView() {
    final ground = _contrast ? Colors.black : Colors.white;
    final ink = _contrast ? Colors.white : MaganaColors.ink;
    if (_shownIndex != _index) {
      _shownIndex = _index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _lineKeys[_index]?.currentContext;
        if (c != null && c.mounted) {
          Scrollable.ensureVisible(
            c,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
    return Semantics(
      container: true,
      label: _l.pageViewLabel,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: ground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MaganaColors.ink, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in _items.indexed)
                  GestureDetector(
                    onTap: () => _go(i),
                    child: Container(
                      key: _lineKeys.putIfAbsent(i, GlobalKey.new),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: i == _index
                          ? BoxDecoration(
                              color: _contrast
                                  ? MaganaColors.amber
                                  : const Color(0xFFFFE7A3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _contrast
                                    ? Colors.white
                                    : const Color(0xFF8A4B00),
                                width: 4,
                              ),
                            )
                          : null,
                      child: Text(
                        _plain(item),
                        style: TextStyle(
                          fontSize: _zoom,
                          height: 1.5,
                          color: i == _index && _contrast ? Colors.black : ink,
                          fontWeight: item.heading
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Zoom and high contrast for the page view (board T2).
  Widget _viewControls() {
    final l = _l;
    void zoom(double by) =>
        setState(() => _zoom = (_zoom + by).clamp(_zoomMin, _zoomMax));
    return Row(
      children: [
        Expanded(
          child: _ControlButton(
            label: l.zoomOut,
            semantics: l.zoomOut,
            onPressed: () => zoom(-4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ControlButton(
            label: l.zoomIn,
            semantics: l.zoomIn,
            onPressed: () => zoom(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Labelled(
            label: l.highContrast,
            toggled: _contrast,
            onTap: () => setState(() => _contrast = !_contrast),
            child: OutlinedButton(
              onPressed: () => setState(() => _contrast = !_contrast),
              style:
                  outlinedTile(bg: _contrast ? MaganaColors.ink : Colors.white)
                      .copyWith(
                        foregroundColor: WidgetStatePropertyAll(
                          _contrast ? Colors.white : MaganaColors.ink,
                        ),
                      ),
              child: Text(l.highContrast, textAlign: TextAlign.center),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final item = _items[_index];
    final row = item.isRow;
    final warning = _warning(item);
    final unsure = widget.result.unsureCount;
    // TalkBack lands on the first item: the title, then Back, Jump and Speak a command.
    Widget order(double n, Widget child) =>
        Semantics(container: true, sortKey: OrdinalSortKey(n), child: child);
    final titleRow = Semantics(
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: [
          order(
            1,
            Labelled(
              label: l.backToHome,
              counted: false,
              radius: 32,
              onTap: () => Navigator.of(context).maybePop(),
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: outlinedTile(radius: 32).copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                child: const Icon(Icons.chevron_left, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(0),
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
                    [
                      if (widget.paper != null) l.readExactly,
                      if (widget.result.pageLanguage != null)
                        l.languagePage(_languageName),
                      if (_columns > 1) l.columnsSubtitle(_columns),
                      _counts(),
                      if (unsure > 0) l.unclearCount(unsure),
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 16,
                      color: MaganaColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          order(
            2,
            Labelled(
              label: l.jumpWithinPage,
              onTap: _jump,
              child: OutlinedButton(
                onPressed: _jump,
                style: outlinedTile(radius: 32).copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                child: const Icon(Icons.list, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 8),
          order(
            3,
            Labelled(
              label: _listening ? l.listeningCommand : l.speakCommand,
              onTap: _command,
              child: OutlinedButton(
                onPressed: _command,
                style: outlinedTile(radius: 32, bg: MaganaColors.amber)
                    .copyWith(
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    ),
                child: Icon(_listening ? Icons.stop : Icons.mic_none, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
    final extras = <Widget>[
      if (!widget.result.offline) ...[
        const SizedBox(height: 12),
        Semantics(
          container: true,
          label: l.jumpWithinPage,
          child: Row(
            children: [
              for (final (label, kind) in [
                (l.jumpHeadings, _JumpKind.headings),
                (l.jumpColumns, _JumpKind.columns),
                (l.jumpTables, _JumpKind.tables),
              ]) ...[
                if (kind != _JumpKind.headings) const SizedBox(width: 8),
                Expanded(
                  child: _ControlButton(
                    label: label,
                    semantics: label,
                    onPressed: () => _jump(only: kind),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      if (_columns > 1) ...[
        const SizedBox(height: 12),
        _PageMap(columns: _columns, current: item.column),
      ],
    ];
    final details = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.result.offline) ...[
            Semantics(
              container: true,
              liveRegion: true,
              child: NoteBox(
                text: _offlineBanner!,
                kind: NoteKind.emergency,
                icon: Icons.wifi_off,
              ),
            ),
            const SizedBox(height: 12),
            NoteBox(
              bold: l.offlineNote,
              text: widget.queued ? l.offlineQueued : '',
            ),
            if (widget.queued) ...[
              const SizedBox(height: 12),
              Semantics(
                toggled: _fullReading,
                label: l.fullReadingWhenOnline,
                excludeSemantics: true,
                onTap: _toggleFullReading,
                child: SwitchListTile(
                  value: _fullReading,
                  onChanged: (_) => _toggleFullReading(),
                  title: Text(
                    l.fullReadingWhenOnline,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  minTileHeight: 64,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: MaganaColors.ink, width: 2),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
          if (_columns > 1) ...[
            NoteBox(text: l.columnsNote(_columns)),
            const SizedBox(height: 16),
          ],
          // A money photo whose amounts aren't all reliable: only the parts that
          // passed every check are here (backend safety.money_photo_check).
          if (widget.result.tips.contains('money_amounts_unreliable')) ...[
            NoteBox(
              text:
                  '${messageFor(l, 'money_amounts_unreliable')} ${messageFor(l, 'reading_incomplete')}',
              kind: NoteKind.warning,
            ),
            const SizedBox(height: 16),
          ],
          _ItemCard(
            item: item,
            position: _position(item),
            status: _playing ? l.nowReading : null,
          ),
          if (widget.result.pageLanguage case final lang?) ...[
            const SizedBox(height: 16),
            NoteBox(
              text: [
                messageFor(l, 'letters_$lang'),
                if (widget.result.letterMarkCount > 0)
                  l.letterCount(widget.result.letterMarkCount),
              ].join(' '),
              kind: NoteKind.warning,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ControlButton(
                    label: l.spellWord,
                    semantics: l.spellWord,
                    onPressed: _spell,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ControlButton(
                    label: l.askSomeone,
                    semantics: l.askSomeone,
                    onPressed: _askSomeone,
                  ),
                ),
              ],
            ),
          ],
          if (warning != null) ...[
            const SizedBox(height: 16),
            _WarningNote(text: warning),
          ],
          if (_warnings.any) ...[
            const SizedBox(height: 16),
            SecondaryButton(label: l.whatsUnclear, onTap: _whatsUnclear),
          ],
          if (_canSave) ...[
            const SizedBox(height: 16),
            if (widget.savedId != null)
              SecondaryButton(label: l.deleteFromLibrary, onTap: _delete)
            else if (_saved)
              Semantics(
                liveRegion: true,
                child: NoteBox(text: l.savedToLibrary, kind: NoteKind.privacy),
              )
            else
              SecondaryButton(label: l.saveToLibrary, onTap: _save),
          ],
          if (widget.paper case final paper?) ...[
            const SizedBox(height: 16),
            NoteBox(text: paper.note(l)),
            const SizedBox(height: 12),
            SecondaryButton(label: l.readAgain, onTap: () => _play(0)),
            if (paper == Paper.statement) ...[
              if (_balances.isNotEmpty) ...[
                const SizedBox(height: 12),
                NoteBox(
                  bold: '${l.fromTheStatement}:',
                  text: _balances.join('. '),
                ),
              ],
              const SizedBox(height: 12),
              SecondaryButton(label: l.findTransaction, onTap: _find),
            ],
            if (paper == Paper.report) ...[
              const SizedBox(height: 12),
              SecondaryButton(label: l.askAboutResult, onTap: _askAboutResult),
              if (_askedAboutResult) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: NoteBox(
                    bold: _resultQuestion == null
                        ? null
                        : l.youAsked(_resultQuestion!),
                    text: l.resultAnswer,
                  ),
                ),
                const SizedBox(height: 12),
                if (_questionSaved)
                  NoteBox(text: l.questionSaved, kind: NoteKind.success)
                else
                  SecondaryButton(label: l.saveQuestion, onTap: _saveQuestion),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: l.askANurse,
                  onTap: () => openHealthWorker(context, reason: 'results'),
                ),
              ],
            ],
            if (paper.isHealth) ...[
              const SizedBox(height: 12),
              if (paper == Paper.medicine &&
                  AppScope.of(context).profile.can(Feature.reminders)) ...[
                SecondaryButton(
                  label: l.remindersCard,
                  onTap: () => openReminders(context),
                ),
                const SizedBox(height: 12),
              ],
              SecondaryButton(
                label: l.askPharmacistOrNurse,
                onTap: () => openHealthWorker(
                  context,
                  reason: paper == Paper.report ? 'results' : 'medicine',
                ),
              ),
              const SizedBox(height: 12),
              const EmergencyBanner(),
            ],
          ],
        ],
      ),
    );
    final controls = <Widget>[
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
      if (_columns > 1) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ControlButton(
                label: l.nextColumn,
                semantics: l.nextColumn,
                onPressed: _nextColumn,
              ),
            ),
            if (_canExplain) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _ControlButton(
                  label: l.explainThis,
                  semantics: l.explainThis,
                  onPressed: _explain,
                ),
              ),
            ],
          ],
        ),
      ] else if (_canExplain) ...[
        const SizedBox(height: 10),
        SecondaryButton(label: l.explainThis, onTap: _explain),
      ],
      const SizedBox(height: 10),
      Labelled(
        label: _playing ? l.pauseLabel : l.playLabel,
        onTap: _togglePause,
        child: OutlinedButton.icon(
          onPressed: _togglePause,
          icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 30),
          label: Text(_playing ? l.pause : l.play),
          style: outlinedTile(radius: 36, bg: MaganaColors.amber).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(72)),
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
    ];
    final tablet = isTablet(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: tablet
              ? const EdgeInsets.fromLTRB(36, 24, 36, 24)
              : const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: !tablet
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleRow,
                    ...extras,
                    const SizedBox(height: 16),
                    Expanded(child: details),
                    ...controls,
                  ],
                )
              : isTabletLandscape(context)
              // Board T2: the page on the left, current line highlighted (zoom, high
              // contrast) for low-vision readers; the reading panel on the right.
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleRow,
                          const SizedBox(height: 12),
                          Expanded(child: _pageView()),
                          const SizedBox(height: 12),
                          _viewControls(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...extras,
                          const SizedBox(height: 12),
                          Expanded(child: details),
                          ...controls,
                        ],
                      ),
                    ),
                  ],
                )
              // Portrait tablet: the same, stacked.
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleRow,
                    ...extras,
                    const SizedBox(height: 12),
                    Expanded(flex: 5, child: _pageView()),
                    const SizedBox(height: 10),
                    _viewControls(),
                    const SizedBox(height: 16),
                    Expanded(flex: 4, child: details),
                    ...controls,
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
                        c.unclear
                            ? _unclear(context, amount: c.amount)
                            : c.currencyUnclear
                            ? TextSpan(
                                children: [
                                  TextSpan(text: '${digitsOf(c.value)} '),
                                  _unclear(context, sign: true),
                                ],
                              )
                            : TextSpan(text: c.value),
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
                    for (final (i, w) in item.words.indexed)
                      if (!item.heldSign(i)) ...[
                        if (i > 0) const TextSpan(text: ' '),
                        item.unclearWords.contains(i)
                            ? _unclear(
                                context,
                                amount: item.unclearAmounts.contains(i),
                              )
                            : item.currencyUnclear.contains(i)
                            ? TextSpan(
                                children: [
                                  TextSpan(
                                    text: digitsOf(w, sign: item.signBefore(i)),
                                  ),
                                  const TextSpan(text: ' '),
                                  _unclear(context, sign: true),
                                ],
                              )
                            : item.letterMarks.contains(i)
                            ? TextSpan(text: w, style: _marked)
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
/// highlighted, never as the digit OCR guessed. A money amount two readings didn't agree
/// on: "[I can't read the amount clearly]".
TextSpan _unclear(
  BuildContext context, {
  bool amount = false,
  bool sign = false,
}) => TextSpan(
  text: sign
      ? '[${AppLocalizations.of(context).currencyUnclear}]'
      : amount
      ? '[${AppLocalizations.of(context).amountUnclear}]'
      : '[${AppLocalizations.of(context).unclearNumber}]',
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
    // Board T2: 72 px targets and 20 px text on a tablet.
    final tablet = isTablet(context);
    return Labelled(
      label: semantics,
      onTap: onPressed,
      radius: 18,
      child: OutlinedButton(
        onPressed: onPressed,
        style: tablet
            ? outlinedTile().copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(72, 72)),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: fontFamily,
                    fontFamilyFallback: fontFallback,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : outlinedTile(),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

/// "Find a transaction": type, or speak, a word, date or amount. Owns its text
/// field's controller so it lives as long as the dialog (closing animates).
class _FindDialog extends StatefulWidget {
  const _FindDialog();

  @override
  State<_FindDialog> createState() => _FindDialogState();
}

class _FindDialogState extends State<_FindDialog> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _speak() async {
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    final voice = voiceInputFor(context);
    if (!await voice.init()) {
      speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    final List<String> heard;
    try {
      heard = await voice.listen(language: 'en');
    } on VoiceStepFailed {
      speaker.say(l.voiceCommandsUnavailable);
      return;
    }
    if (heard.isNotEmpty && mounted) Navigator.of(context).pop(heard.first);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        l.findTransaction,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.findPrompt, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: _field,
              autofocus: true,
              style: const TextStyle(fontSize: 22),
              decoration: InputDecoration(
                labelText: l.findField,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
      ),
      actions: [
        SecondaryButton(label: l.findSpeak, onTap: _speak),
        const SizedBox(height: 8),
        PrimaryButton(
          label: l.findSearch,
          onTap: () => Navigator.of(context).pop(_field.text),
        ),
      ],
    );
  }
}

enum _JumpKind { headings, columns, tables }

/// A word that may have lost a special letter (board 5d): shown as read, marked.
const _marked = TextStyle(
  backgroundColor: MaganaColors.warnFill,
  color: MaganaColors.warnInk,
  decoration: TextDecoration.underline,
  decorationStyle: TextDecorationStyle.dashed,
  decorationColor: MaganaColors.warnBorder,
  decorationThickness: 2,
);

/// The small page map on a page in columns (board 5c): which column is being read.
/// Visual only; the spoken position says "Column 1 of 2".
class _PageMap extends StatelessWidget {
  const _PageMap({required this.columns, required this.current});
  final int columns;
  final int current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: MaganaColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (var c = 1; c <= columns; c++) ...[
              if (c > 1) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c == current
                        ? Colors.white
                        : const Color(0xFFF6F4EE),
                    borderRadius: BorderRadius.circular(8),
                    border: c == current
                        ? Border.all(color: MaganaColors.green, width: 3)
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        c == current
                            ? '$c ▸ ${l.mapNow}'
                            : c == current + 1
                            ? '$c ${l.mapNext}'
                            : '$c',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (var k = 0; k < 4; k++)
                        Container(
                          height: 5,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9AA0A6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
