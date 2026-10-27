import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'l10n/app_localizations.dart';
import 'theme.dart';

/// "Touch to hear" (board 10): for blind and low-vision users whose phone's screen reader
/// is off. The first touch on a control (or a finger sliding onto it) says its name, hint
/// and place ("3 of 7") and outlines it in thick yellow; a second tap on the same control
/// within [again] opens it; a long press says it again. With VoiceOver or TalkBack on, it
/// does nothing: the screen reader already does this, with the same labels ([Labelled]).
class TouchToHear extends ChangeNotifier {
  // Named constructor parameters can't be private initializing formals.
  // ignore: prefer_initializing_formals
  TouchToHear({bool? on, this.defaultOn = false}) : _on = on;

  bool? _on;

  /// Before anyone chooses (first run): on in the app, off in tests.
  final bool defaultOn;

  bool get on => _on ?? defaultOn;

  /// Chosen on the first-run practice (board 10b) or in Settings.
  bool get chosen => _on != null;

  static const again = Duration(seconds: 3);
  static const _key = 'touch_to_hear';

  Future<void> load() async {
    try {
      _on = (await SharedPreferences.getInstance()).getBool(_key);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> set(bool on) async {
    _on = on;
    focused.value = null;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, on);
    } catch (_) {}
  }

  /// In use on this screen: switched on, and no screen reader running.
  bool activeIn(BuildContext context) => on && !screenReaderOn(context);

  final _targets = <TouchTarget>{};
  void register(TouchTarget t) => _targets.add(t);
  void unregister(TouchTarget t) {
    _targets.remove(t);
    if (focused.value == t) focused.value = null;
  }

  /// The control last touched, outlined until another is touched.
  final focused = ValueNotifier<TouchTarget?>(null);
  DateTime? _focusedAt;

  /// What was last said about it, shown at the foot of the screen (board 10) for
  /// [captionFor], so it doesn't keep covering the controls at the foot.
  final caption = ValueNotifier<String?>(null);
  static const captionFor = Duration(seconds: 5);

  bool isFresh(TouchTarget t) =>
      focused.value == t &&
      _focusedAt != null &&
      DateTime.now().difference(_focusedAt!) <= again;

  /// The control under [position] on the screen in front, or null.
  TouchTarget? targetAt(Offset position) {
    TouchTarget? best;
    var area = double.infinity;
    for (final t in _targets) {
      final box = t.box;
      if (!t.mounted || box == null || !(t.route?.isCurrent ?? true)) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final a = rect.width * rect.height;
      if (rect.contains(position) && a < area) {
        best = t;
        area = a;
      }
    }
    return best;
  }

  /// The controls of the screen [t] is on, in reading order, without "Back".
  List<TouchTarget> choicesOf(ModalRoute<Object?>? route) {
    final list = [
      for (final t in _targets)
        if (t.counted && t.mounted && t.route == route && t.box != null) t,
    ];
    list.sort((a, b) {
      final pa = a.box!.localToGlobal(Offset.zero);
      final pb = b.box!.localToGlobal(Offset.zero);
      final dy = pa.dy - pb.dy;
      return dy.abs() > 8 ? dy.sign.toInt() : pa.dx.compareTo(pb.dx);
    });
    return list;
  }

  /// Says [t] and outlines it, interrupting whatever was being said.
  void focus(BuildContext context, TouchTarget t) {
    final l = AppLocalizations.of(context);
    final choices = choicesOf(t.route);
    final i = choices.indexOf(t);
    final text = [
      _sentence(t.label),
      if (t.hint != null) _sentence(t.hint!),
      if (i >= 0 && choices.length > 1) '${l.touchOf(i + 1, choices.length)}.',
      if (t.enabled) l.touchTapAgain,
    ].join(' ');
    focused.value = t;
    _focusedAt = DateTime.now();
    caption.value = text;
    t.reveal();
    AppScope.of(context).speaker.say(text);
  }

  void activate(TouchTarget t) {
    focused.value = null;
    caption.value = null;
    _focusedAt = null;
    t.onTap?.call();
  }

  /// Opens the control on [route] whose name [heard] says ("medicine label"), if one does.
  bool openByName(ModalRoute<Object?>? route, String heard) {
    final t = bestMatch(heard, [
      for (final t in choicesOf(route))
        if (t.enabled) t,
    ], (t) => t.label);
    if (t == null) return false;
    activate(t);
    return true;
  }
}

String _sentence(String s) {
  final t = s.trim();
  return t.isEmpty || '.!?'.contains(t[t.length - 1]) ? t : '$t.';
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r"[^\p{L}\p{N}' ]", unicode: true), ' ')
    .replaceAll(RegExp(r' +'), ' ')
    .trim();

/// The item whose name (its label up to the first ". ") [heard] says: the whole name, or
/// failing that the most of its words (at least half, and at least one). Ties: none.
T? bestMatch<T>(String heard, List<T> items, String Function(T) label) {
  final said = ' ${_norm(heard)} ';
  if (said.trim().isEmpty) return null;
  String name(T t) => _norm(label(t).split('. ').first);
  final whole = [
    for (final t in items)
      if (said.contains(' ${name(t)} ')) t,
  ];
  if (whole.isNotEmpty) {
    whole.sort((a, b) => name(b).length.compareTo(name(a).length));
    return whole.first;
  }
  T? best;
  var bestScore = 0.0;
  var tie = false;
  for (final t in items) {
    final words = name(t).split(' ').where((w) => w.length > 2).toList();
    if (words.isEmpty) continue;
    final hits = words
        .where((w) => RegExp(' ${RegExp.escape(w)}s? ').hasMatch(said))
        .length;
    final score = hits / words.length;
    if (hits == 0 || score < 0.5) continue;
    if (score > bestScore) {
      best = t;
      bestScore = score;
      tie = false;
    } else if (score == bestScore) {
      tie = true;
    }
  }
  return tie ? null : best;
}

/// The phone's screen reader (VoiceOver, TalkBack) is running.
bool screenReaderOn(BuildContext context) =>
    MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

/// One control as Touch to hear knows it: the same label and hint the screen reader reads.
abstract class TouchTarget {
  String get label;
  String? get hint;
  VoidCallback? get onTap;
  bool get enabled => onTap != null;

  /// Counted in "3 of 7" and the screen's choices; not the Back button.
  bool get counted;
  bool get mounted;
  ModalRoute<Object?>? get route;
  RenderBox? get box;

  /// Scrolls it fully into view.
  void reveal();
}

/// Watches every touch on the app (it never takes them from the controls below) and turns
/// them into Touch to hear: say, open on a second tap, repeat on a long press, and follow a
/// sliding finger. Also shows what was said at the foot of the screen.
class TouchExplorer extends StatefulWidget {
  const TouchExplorer({super.key, required this.child});
  final Widget child;

  @override
  State<TouchExplorer> createState() => _TouchExplorerState();
}

class _TouchExplorerState extends State<TouchExplorer> {
  int? _pointer;
  Offset _down = Offset.zero;
  TouchTarget? _target;
  bool _again = false, _slid = false, _repeated = false;
  Timer? _long;

  static const longPress = Duration(milliseconds: 600);

  TouchToHear get _touch => AppScope.of(context).touch;

  /// The control under [position] on the screen in front: the smallest whose box holds it.
  /// By geometry, not hit testing, so it works while a list is moving.
  TouchTarget? _at(Offset position) => _touch.targetAt(position);

  void _onDown(PointerDownEvent e) {
    if (_pointer != null || !_touch.activeIn(context)) return;
    _pointer = e.pointer;
    _down = e.position;
    _slid = _repeated = false;
    final t = _target = _at(e.position);
    _again = t != null && _touch.isFresh(t);
    if (t != null && !_again) _touch.focus(context, t);
    _long = Timer(longPress, () {
      if (_pointer == null || _slid || _target == null || !mounted) return;
      _repeated = true;
      _touch.focus(context, _target!);
    });
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if (!_slid && (e.position - _down).distance > kTouchSlop) {
      _slid = true;
      _long?.cancel();
    }
    if (!_slid) return;
    final t = _at(e.position);
    if (t != null && _touch.focused.value != t) _touch.focus(context, t);
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _end();
    final t = _target;
    if (t != null && _again && !_slid && !_repeated) {
      _touch.activate(t);
    }
  }

  void _end() {
    _long?.cancel();
    _pointer = null;
  }

  // The caption shows for TouchToHear.captionFor after each new text.
  TouchToHear? _listened;
  Timer? _captionTimer;
  bool _captionShown = false;

  void _onCaption() {
    _captionTimer?.cancel();
    setState(() => _captionShown = _listened?.caption.value != null);
    if (_captionShown) {
      _captionTimer = Timer(TouchToHear.captionFor, () {
        if (mounted) setState(() => _captionShown = false);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final touch = AppScope.of(context).touch;
    if (touch != _listened) {
      _listened?.caption.removeListener(_onCaption);
      _listened = touch..caption.addListener(_onCaption);
    }
  }

  @override
  void dispose() {
    _long?.cancel();
    _captionTimer?.cancel();
    _listened?.caption.removeListener(_onCaption);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final touch = AppScope.of(context).touch;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: (e) {
        if (e.pointer == _pointer) _end();
      },
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // One finger explores, so it doesn't also drag lists: a touched control scrolls
          // itself fully into view instead (TouchTarget.reveal), as with VoiceOver.
          ListenableBuilder(
            listenable: touch,
            builder: (context, child) => touch.activeIn(context)
                ? ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(dragDevices: const {}),
                    child: child!,
                  )
                : child!,
            child: widget.child,
          ),
          // What was just said, for low vision (board 10): out of the screen reader's way.
          ValueListenableBuilder<String?>(
            valueListenable: touch.caption,
            builder: (context, text, _) =>
                text == null || !_captionShown || !touch.activeIn(context)
                ? const SizedBox.shrink()
                : Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16 + MediaQuery.paddingOf(context).bottom,
                    child: IgnorePointer(
                      child: ExcludeSemantics(child: _Caption(text: text)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Material(
    color: MaganaColors.ink,
    elevation: 8,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const Icon(
            Icons.volume_up_outlined,
            color: MaganaColors.amber,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The yellow outline on the touched control (board 10), drawn over it.
class TouchOutline extends StatelessWidget {
  const TouchOutline({
    super.key,
    required this.child,
    this.show = true,
    this.radius = 20,
  });
  final Widget child;
  final bool show;
  final double radius;

  // Always a Stack, so showing the outline never rebuilds the control under it.
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    // The control keeps the size it would have without the outline (a button in a row
    // still fills its share).
    fit: StackFit.passthrough,
    children: [
      child,
      if (show)
        Positioned(
          left: -5,
          top: -5,
          right: -5,
          bottom: -5,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + 5),
                border: Border.all(color: MaganaColors.amber, width: 6),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: MaganaColors.ink, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Says what a screen is when it opens (board 10): its own words ([intro], e.g. its title)
/// then how many choices it has and "Touch to explore, or say a name." With a screen reader
/// on, one short announcement instead (the title and the count), so nothing is said twice.
/// A screen without choices only says its own words.
void introduceScreen(BuildContext context, String Function() intro) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final scope = context.mounted ? AppScope.maybeOf(context) : null;
    if (scope == null) return;
    final route = ModalRoute.of(context);
    final l = AppLocalizations.of(context);
    final text = intro();
    final count = scope.touch.choicesOf(route).length;
    final choices = count > 1 ? l.touchChoices(count) : null;
    if (screenReaderOn(context)) {
      if (choices == null) return; // the screen reader reads the screen itself
      final title = text.split(RegExp(r'(?<=[.!?])\s')).first;
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${_sentence(title)} ${_sentence(choices)}',
        Directionality.of(context),
      );
      return;
    }
    scope.speaker.say(
      [
        if (text.isNotEmpty) _sentence(text),
        if (choices != null) _sentence(choices),
        if (choices != null && scope.touch.activeIn(context)) l.touchExplore,
      ].join(' '),
    );
  });
}
