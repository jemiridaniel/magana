import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../app_scope.dart';
import '../capture/camera_frames.dart';
import '../capture/feedback.dart';
import '../capture/frame_analysis.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../offline/offline_reader.dart';
import '../offline/photo_queue.dart';
import '../offline/read_timing.dart';
import '../library.dart';
import '../papers.dart';
import '../platform.dart';
import '../policy.dart';
import '../tasks.dart';
import '../theme.dart';
import 'reader.dart';

/// Live camera preview with spoken framing guidance about every second,
/// auto-capture when the page is whole and steady, a torch, and the gallery.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    this.picker,
    this.findCameras = availableCameras,
    this.feedback,
    this.paper,
    this.detect = false,
  });

  /// An everyday paper (health or money mode); null for schoolwork and other pages.
  final Paper? paper;

  /// "Read any paper": read in the strict letter mode, then work out the kind.
  final bool detect;

  /// Gallery (and fallback camera) picker; injectable for tests.
  final Future<XFile?> Function(ImageSource source)? picker;

  /// The device's cameras; tests pass none, which uses the system camera instead.
  final Future<List<CameraDescription>> Function() findCameras;

  /// Framing tone, vibration and capture sound; injectable for tests.
  final CaptureFeedback? feedback;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _starting = false;
  bool _streaming = false;
  bool _torchOn = false;
  bool _torchWorks = torchSupported;
  bool _auto = true;
  bool _busy = false;
  bool _analysing = false;
  DateTime _lastFrame = DateTime(0);
  final _analyzer = FrameAnalyzer();
  Advice? _advice;
  String? _status; // replaces guidance: reading, errors, backend tips
  Timer? _guideTimer;
  Timer? _tickTimer;
  Timer? _statusTimer;
  late final CaptureFeedback _feedback = widget.feedback ?? CaptureFeedback();
  DateTime _quietSince = DateTime.now();

  AppLocalizations get _l => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _say(_l.framingGuidance);
      _startCamera();
    });
    _guideTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _guide(),
    );
    _tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guideTimer?.cancel();
    _tickTimer?.cancel();
    _statusTimer?.cancel();
    if (widget.feedback == null) _feedback.dispose();
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released when the app leaves the screen (gallery, calls).
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  // ---------- camera

  Future<void> _startCamera() async {
    if (_starting || _camera != null || !mounted) return;
    _starting = true;
    try {
      final cameras = await widget.findCameras();
      if (cameras.isEmpty || !mounted) return;
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: cameraFrameFormat,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      _camera = camera;
      _analyzer.reset();
      if (_torchOn) await _setTorch(true);
      await _startFraming();
      setState(() {});
    } on CameraException {
      _setStatus(_l.cameraUnavailable); // usually camera permission refused
    } catch (_) {
      // No camera plugin or device: Take photo falls back to the system camera.
    } finally {
      _starting = false;
    }
  }

  Future<void> _startFraming() async {
    final camera = _camera;
    if (camera == null ||
        _streaming ||
        !liveFramingSupported ||
        !camera.supportsImageStreaming()) {
      return;
    }
    await camera.startImageStream(_onFrame);
    _streaming = true;
  }

  Future<void> _stopFraming() async {
    if (!_streaming) return;
    _streaming = false;
    try {
      await _camera?.stopImageStream();
    } on CameraException {
      // Already stopped.
    }
  }

  Future<void> _stopCamera() async {
    final camera = _camera;
    _camera = null;
    _streaming = false;
    _advice = null;
    if (camera != null) await camera.dispose();
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    // About five frames a second is plenty and keeps low-cost phones cool.
    if (_analysing ||
        _busy ||
        now.difference(_lastFrame).inMilliseconds < 200) {
      return;
    }
    _analysing = true;
    _lastFrame = now;
    try {
      final advice = _analyzer.analyze(
        lumaGridFrom(image, _camera?.description.sensorOrientation ?? 90),
      );
      if (advice != _advice && mounted) setState(() => _advice = advice);
      if (_auto && advice == Advice.ready) _captureWithCamera();
    } finally {
      _analysing = false;
    }
  }

  Future<void> _setTorch(bool on) async {
    try {
      await _camera?.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchOn = on);
    } on CameraException {
      if (mounted) setState(() => _torchWorks = false);
    }
  }

  // ---------- guidance

  /// One-word cues: short enough to repeat every second without talking over the tone.
  String? _adviceText(Advice? a) => switch (a) {
    null => null,
    Advice.tooDark => _l.cueMoreLight,
    Advice.noPage => _l.cueNoPage,
    Advice.moveCloser => _l.cueCloser,
    Advice.liftPhone => _l.cueFurther,
    Advice.moveUp => _l.cueHigher,
    Advice.moveDown => _l.cueLower,
    Advice.moveLeft => _l.cueLeft,
    Advice.moveRight => _l.cueRight,
    Advice.tiltToward => _l.cueTiltToward,
    Advice.tiltAway => _l.cueTiltAway,
    Advice.blurry => _l.cueBlurry,
    Advice.holdStill || Advice.ready => _l.cueHoldStill,
  };

  /// A tick and light vibration, repeating faster as the page fits; silent
  /// with no page in view, or while a photo is being read.
  void _tick() {
    if (!mounted) return;
    final interval = (!_busy && _streaming)
        ? tickInterval(_analyzer.fit)
        : null;
    if (interval == null) {
      _tickTimer = Timer(const Duration(milliseconds: 300), _tick);
      return;
    }
    _feedback.tick();
    _tickTimer = Timer(interval, _tick);
  }

  /// Speaks the current advice whenever the voice has been quiet for a second.
  void _guide() {
    if (!mounted || _busy || _status != null || !_streaming) return;
    final speaker = AppScope.of(context).speaker;
    final now = DateTime.now();
    if (speaker.speaking) {
      _quietSince = now;
      return;
    }
    final text = _adviceText(_advice);
    if (text == null ||
        now.difference(_quietSince) < const Duration(seconds: 1)) {
      return;
    }
    _quietSince = now;
    speaker.say(text);
  }

  void _say(String text) {
    if (mounted) AppScope.of(context).speaker.say(text);
  }

  void _setStatus(String? text) {
    if (!mounted) return;
    setState(() => _status = text);
    if (text != null) _say(text);
  }

  // ---------- capture

  Future<void> _captureWithCamera() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    setState(() => _busy = true);
    _feedback.captured();
    try {
      await _stopFraming();
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      await discardCapture(photo);
      await _send(bytes, 'page.jpg');
    } on CameraException {
      _setStatus(_l.cameraFailed);
      _resume();
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    final XFile? photo;
    try {
      photo =
          await (widget.picker?.call(source) ??
              // Large enough for small print, small enough to upload on a slow connection.
              ImagePicker().pickImage(
                source: source,
                maxWidth: 2400,
                imageQuality: 88,
              ));
    } catch (_) {
      _setStatus(_l.cameraFailed);
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    await _send(await photo.readAsBytes(), photo.name);
  }

  /// How long to wait for the server before reading on this phone (board 5e).
  static const serverWait = Duration(seconds: 8);

  /// Codes that mean "the server can't read it now" (no internet, asleep, failed):
  /// these fall back to reading on the phone. Anything else (not allowed, a bad
  /// photo) is the answer and is said as it is.
  static const _fallBack = {'unreachable', 'server_sleeping', 'failed'};

  Future<void> _send(Uint8List bytes, String filename) async {
    final scope = AppScope.of(context);
    final l = _l;
    final mode = widget.detect
        ? Paper.letter.mode
        : widget.paper?.mode ?? 'school';
    final paper = widget.detect ? null : widget.paper;
    final profile = scope.profile;
    final mayKeep =
        profile.can(Feature.library) && profile.tier != Tier.classroom;
    ReadTiming.start();
    _setStatus(l.readingPage);
    final online = scope.api.read(bytes, filename: filename, mode: mode);
    ReadResult? result;
    OfflineReason? why;
    try {
      result = await online.timeout(serverWait);
    } on TimeoutException {
      why = OfflineReason.slow;
    } on ApiException catch (e) {
      if (!_fallBack.contains(e.code)) {
        _setStatus(messageFor(l, e.code));
        _resume();
        return;
      }
      why = e.code == 'unreachable'
          ? OfflineReason.noInternet
          : OfflineReason.slow;
    }
    var queued = false;
    var dropped = 0; // oldest waiting pages dropped to keep at most 20
    if (result == null) {
      ReadResult? local;
      try {
        local = await readOnPhone(bytes, mode: mode);
      } catch (_) {
        local = null;
      }
      if (local == null) {
        // This phone can't read offline (the web): wait for the server after all.
        try {
          result = await online;
          why = null;
        } on ApiException catch (e) {
          _setStatus(messageFor(l, e.code));
          _resume();
          return;
        }
      } else {
        result = local;
        if (mayKeep && await FullReadingSetting.get()) {
          queued = true;
          // A slow server may still answer: its reading goes to My library. If it
          // doesn't, the photo waits, encrypted, for the next time we're online.
          online.then<void>(
            (full) => Library.save(full, paper),
            onError: (Object _) async {
              dropped = await photoQueue.add(bytes, mode: mode, paper: paper);
              if (dropped > 0) scope.speaker.say(l.queueDropped(dropped));
            },
          );
        } else {
          online.ignore();
        }
      }
    } else if (mayKeep) {
      // Online again: pages that waited get their full reading now.
      photoQueue.drain(scope.api).then((n) {
        if (n > 0) scope.speaker.say(l.fullReadingsReady(n));
      });
    }
    final page = result;
    if (!mounted) return;
    if (page.readableCount == 0) {
      _setStatus(
        [
          for (final tip in page.tips) messageFor(l, tip),
          for (final f in page.items.where((i) => i.isFaint))
            messageFor(l, 'faint_region', where: pagePosition(l, f.where)),
          // Held back for safety is not "no text": the tip already says why.
          if (!page.tips.contains('money_amounts_unreliable')) l.noTextFound,
        ].join(' '),
      );
      _resume();
      return;
    }
    final kind = widget.detect ? detectPaper(page) : widget.paper;
    await TaskLog.record(TaskKind.forPaper(kind));
    await _stopCamera();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          result: page,
          paper: kind,
          detected: widget.detect,
          offlineReason: why,
          queued: queued,
        ),
      ),
    );
  }

  /// Back to framing after a failed read. With a live camera the message stays
  /// on screen for a few seconds, then live guidance takes over again.
  Future<void> _resume() async {
    if (!mounted) return;
    setState(() => _busy = false);
    _analyzer.reset();
    await _startFraming();
    _statusTimer?.cancel();
    if (_streaming) {
      _statusTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && !_busy) setState(() => _status = null);
      });
    }
  }

  // ---------- UI

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final camera = _camera;
    final live = camera != null && camera.value.isInitialized;
    final text = _status ?? _adviceText(_advice) ?? l.framingGuidance;
    final VoidCallback? takePhoto = _busy
        ? null
        : () => live ? _captureWithCamera() : _pick(ImageSource.camera);
    final VoidCallback? openGallery = _busy
        ? null
        : () => _pick(ImageSource.gallery);
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
                    onTap: () => Navigator.of(context).maybePop(),
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
                        widget.detect
                            ? l.readAnyPaper
                            : widget.paper?.title(l) ?? l.readPage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (live && _torchWorks)
                    Semantics(
                      button: true,
                      toggled: _torchOn,
                      label: _torchOn ? l.torchOff : l.torchOn,
                      excludeSemantics: true,
                      onTap: () => _setTorch(!_torchOn),
                      child: OutlinedButton(
                        onPressed: () => _setTorch(!_torchOn),
                        style: onDark.copyWith(
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.zero,
                          ),
                          backgroundColor: WidgetStatePropertyAll(
                            _torchOn ? MaganaColors.amber : Colors.transparent,
                          ),
                          foregroundColor: WidgetStatePropertyAll(
                            _torchOn ? MaganaColors.ink : Colors.white,
                          ),
                        ),
                        child: Icon(
                          _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                          size: 28,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: minTarget),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Semantics(
                  image: true,
                  label: l.cameraView,
                  excludeSemantics: true,
                  child: _Viewfinder(
                    camera: live ? camera : null,
                    advice: _advice,
                    busy: _busy,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Not a live region: the app already speaks this every second,
              // and TalkBack reading each change too would double the speech.
              Semantics(
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
                          text,
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
                    child: live && _streaming
                        ? _AutoCaptureToggle(
                            value: _auto,
                            onChanged: (v) => setState(() => _auto = v),
                          )
                        : Semantics(
                            button: true,
                            label: l.repeatInstructions,
                            excludeSemantics: true,
                            onTap: _busy ? null : () => _say(text),
                            child: OutlinedButton(
                              onPressed: _busy ? null : () => _say(text),
                              style: onDark,
                              child: Text(
                                l.repeat,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    button: true,
                    label: l.takePhoto,
                    enabled: !_busy,
                    excludeSemantics: true,
                    onTap: takePhoto,
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: FilledButton(
                        onPressed: takePhoto,
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
                      onTap: openGallery,
                      child: OutlinedButton(
                        onPressed: openGallery,
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

/// Camera preview with an amber bar on any edge where the page is cut off.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.camera,
    required this.advice,
    required this.busy,
  });
  final CameraController? camera;
  final Advice? advice;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final camera = this.camera;
    final size = camera?.value.previewSize;
    Widget bar(Alignment a, {bool vertical = false}) => Align(
      alignment: a,
      child: Container(
        width: vertical ? 10 : double.infinity,
        height: vertical ? double.infinity : 10,
        color: MaganaColors.amber,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF2A2F33)),
          if (camera != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              // Preview sizes are reported in sensor (landscape) orientation.
              child: SizedBox(
                width: size?.height ?? 300,
                height: size?.width ?? 400,
                child: CameraPreview(camera),
              ),
            )
          else
            const Icon(Icons.crop_free, size: 120, color: Color(0xFFA9A496)),
          if (advice == Advice.moveUp) bar(Alignment.topCenter),
          if (advice == Advice.moveDown) bar(Alignment.bottomCenter),
          if (advice == Advice.moveLeft)
            bar(Alignment.centerLeft, vertical: true),
          if (advice == Advice.moveRight)
            bar(Alignment.centerRight, vertical: true),
          if (busy)
            const Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  color: MaganaColors.amber,
                  strokeWidth: 6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AutoCaptureToggle extends StatelessWidget {
  const _AutoCaptureToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).autoCapture;
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTarget),
          child: Row(
            children: [
              Icon(
                value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 32,
                color: MaganaColors.amber,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
