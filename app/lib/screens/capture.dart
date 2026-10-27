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
import '../diagnostics.dart';
import '../l10n/app_localizations.dart';
import '../messages.dart';
import '../offline/offline_reader.dart';
import '../platform/shrink_photo.dart';
import '../offline/photo_queue.dart';
import '../offline/read_timing.dart';
import '../library.dart';
import '../papers.dart';
import '../platform.dart';
import '../policy.dart';
import '../tasks.dart';
import '../theme.dart';
import '../layout.dart';
import '../version.dart';
import '../widgets.dart';
import 'reader.dart';

/// How long to wait for the server before reading on this phone (board 5e). A full page
/// takes the server 5–7 s, plus the upload on mobile data: the old 8 s sent most real pages
/// to the phone while the server answered moments later (logs, 27 Oct 2026).
const serverWait = Duration(seconds: 25);

/// "Still reading…" after this long, so a wait is never silent.
const stillReadingAfter = Duration(seconds: 5);

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

  /// On a tablet: lay the page flat and hold the tablet above it (board T1). The same
  /// auto-capture rules: never stuck (FrameAnalyzer.captureAnywayAfter).
  String get _guidance =>
      isTablet(context) ? _l.framingGuidanceTablet : _l.framingGuidance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _say(_guidance);
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
    _deadline?.cancel();
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
        // 1080p: reads every number on the 40-page set that 720p missed, at about 37 KB a page
        // once shrunk (shrinkPhoto); 1600 px added nothing (docs/FINDINGS.md, 27 Oct 2026).
        ResolutionPreset.veryHigh,
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

  bool _tiltSaid = false;

  /// Capture's own clock, apart from the frames: if they stall, the photo is still taken.
  Timer? _deadline;

  /// "Hold still" at most twice per attempt; the clocks take the photo anyway.
  int _holdStillSaid = 0;
  static const holdStillMax = 2;

  /// The last photo was taken without text ever seen: "I couldn't find text" if none is read.
  bool _noTextCapture = false;

  void _armDeadline() {
    _deadline?.cancel();
    _deadline = Timer(
      FrameAnalyzer.captureNoTextAfter + const Duration(seconds: 1),
      () {
        if (mounted &&
            !_busy &&
            _auto &&
            _camera?.value.isInitialized == true) {
          _captureWithCamera('deadline');
        }
      },
    );
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
    _holdStillSaid = 0;
    _armDeadline();
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
      // The torch shining back off the page: turn it off and say so, don't keep waiting.
      if (_torchOn && _analyzer.glare) {
        _setTorch(false);
        _say(_l.torchGlareOff);
      }
      if (advice != _advice && mounted) setState(() => _advice = advice);
      // Tilt is a tip, said once; it never holds the photo back.
      final tilt = _analyzer.tiltTip;
      if (!_tiltSaid && tilt != null) {
        _tiltSaid = true;
        _say(_adviceText(tilt)!);
      }
      if (_auto && advice == Advice.ready) {
        final r = _analyzer.report;
        _captureWithCamera(
          r.anyway
              ? 'steady_text'
              : r.smallItem
              ? 'small_item'
              : 'auto',
        );
      }
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
    if (text == _l.cueHoldStill && _holdStillSaid >= holdStillMax) return;
    if (text == _l.cueHoldStill) _holdStillSaid++;
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

  Future<void> _captureWithCamera([String how = 'button']) async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    diagnostics.begin(how, _analyzer.report);
    _deadline?.cancel();
    _noTextCapture = how == 'deadline' || _analyzer.capturedWithoutText;
    setState(() => _busy = true);
    // Shutter sound, vibration and words before every photo: a blind user always knows.
    _feedback.captured();
    _setStatus(_l.pictureTaken);
    try {
      await _stopFraming();
      final photo = await camera.takePicture();
      final bytes = await shrinkPhoto(await photo.readAsBytes());
      await discardCapture(photo);
      await _send(bytes, 'page.jpg');
    } on CameraException {
      _setStatus(_l.cameraFailed);
      _resume();
    }
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    diagnostics.begin(
      source == ImageSource.gallery ? 'gallery' : 'system_camera',
      null,
    );
    final XFile? photo;
    try {
      // From the gallery, the picture as it is: a screenshot is sent whole (below). From the
      // camera, large enough for small print, small enough to upload on a slow connection.
      photo =
          await (widget.picker?.call(source) ??
              (source == ImageSource.gallery
                  ? ImagePicker().pickImage(source: source)
                  : ImagePicker().pickImage(
                      source: source,
                      maxWidth: 2400,
                      imageQuality: 88,
                    )));
    } catch (_) {
      _setStatus(_l.cameraFailed);
      return;
    }
    if (photo == null || !mounted) return;
    setState(() => _busy = true);
    final raw = await photo.readAsBytes();
    // A screenshot at full resolution, never re-compressed; a photo large enough for small
    // print and small enough to upload on a slow connection.
    final whole =
        source == ImageSource.gallery && await looksLikeScreenshot(raw);
    final bytes = whole || source == ImageSource.camera
        ? raw
        : await shrinkTo(raw, galleryMaxWidth, galleryQuality);
    diagnostics.last?.screenshot = whole;
    await _send(bytes, photo.name);
  }

  /// A failed send or a server error is tried once more within [serverWait].
  static const _retryable = {'unreachable', 'server_sleeping', 'failed'};

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
    final attempt = diagnostics.last;
    attempt?.photoBytes = bytes.length;
    // A camera photo was announced already ("Picture taken. Reading…").
    if (_status != l.pictureTaken) _setStatus(l.readingPage);
    final sent = DateTime.now();
    final still = Timer(stillReadingAfter, () {
      if (mounted && _busy) _setStatus(l.stillReading);
    });
    var online = scope.api.read(bytes, filename: filename, mode: mode);
    ReadResult? result;
    OfflineReason? why;
    for (var tries = 1; ; tries++) {
      final left = serverWait - DateTime.now().difference(sent);
      try {
        result = await online.timeout(left.isNegative ? Duration.zero : left);
        why = null;
      } on TimeoutException {
        why = OfflineReason.slow;
      } on ApiException catch (e) {
        why = OfflineReason.forCode(e.code, web: runningOnWeb);
        if (why == null) {
          // Not allowed, a bad photo...: that is the answer, said as it is.
          still.cancel();
          _setStatus(messageFor(l, e.code));
          _resume();
          return;
        }
        final again = serverWait - DateTime.now().difference(sent);
        if (tries == 1 &&
            _retryable.contains(e.code) &&
            again > const Duration(seconds: 3)) {
          attempt?.retried = e.code;
          online = scope.api.read(bytes, filename: filename, mode: mode);
          continue;
        }
      }
      break;
    }
    still.cancel();
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
            (full) async {
              attempt?.serverLate = true;
              await Library.save(full, paper);
            },
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
    attempt
      ?..path = why == null ? 'server' : 'phone (${why.name})'
      ..read(page);
    if (!mounted) return;
    if (page.readableCount == 0) {
      _setStatus(
        [
          for (final tip in page.tips) messageFor(l, tip),
          for (final f in page.items.where((i) => i.isFaint))
            messageFor(l, 'faint_region', where: pagePosition(l, f.where)),
          // Held back for safety is not "no text": the tip already says why.
          if (!page.tips.contains('money_amounts_unreliable'))
            _noTextCapture ? l.noTextMoveBack : l.noTextFound,
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
    final text = _status ?? _adviceText(_advice) ?? _guidance;
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
                  Labelled(
                    label: l.backToHome,
                    counted: false,
                    radius: 32,
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
                    child: Column(
                      children: [
                        Semantics(
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
                        // The installed build, for testers; not read aloud.
                        ExcludeSemantics(
                          child: FutureBuilder<String>(
                            future: appVersionLabel(),
                            builder: (context, v) => Text(
                              v.data ?? '',
                              style: const TextStyle(
                                color: Color(0xFFB8BEC4),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (live && _torchWorks)
                    Labelled(
                      toggled: _torchOn,
                      label: _torchOn ? l.torchOff : l.torchOn,
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
                        : Labelled(
                            label: l.repeatInstructions,
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
                  Labelled(
                    label: l.takePhoto,
                    onTap: !_busy ? takePhoto : null,
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
                    child: Labelled(
                      label: l.galleryLabel,
                      onTap: !_busy ? openGallery : null,
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
