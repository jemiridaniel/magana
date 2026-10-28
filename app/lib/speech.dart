import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'clips.dart';
import 'diagnostics.dart';
import 'guidance.dart';
import 'platform.dart';
import 'platform/speech_support.dart';
import 'voices.dart';

/// A piece of what is said, in its own language: a page line in the page's language, Magana's
/// own words in the app's ([Speaker.sayParts]).
class SpeechPart {
  const SpeechPart(this.text, this.language, {this.guidance = true});
  final String text;
  final String language;

  /// Magana's own words (menus, cues, warnings), which may be said in English when [language]
  /// has no voice (guidance.dart). False for page text: never said by another language's voice.
  final bool guidance;
}

/// How one utterance ended.
enum Spoken {
  finished,

  /// Magana stopped it (a new utterance, or the person pressed something).
  stoppedByMagana,

  /// Something else cut it off: TalkBack announcing a screen, or the browser
  /// reporting "interrupted" or "canceled" when Magana didn't stop it.
  cutOff,

  /// The browser refused to speak before the first press (Chrome's autoplay
  /// rule, "not-allowed"); it is said after "Start Magana".
  blocked,

  /// Any other engine error ("synthesis-failed", "audio-busy", ...).
  failed,
}

/// Text-to-speech wrapper. [say] completes when the utterance finishes or is
/// interrupted, so callers can read items one after another. It returns false
/// when it was cut off, so reading loops pause there instead of skipping ahead.
/// Something other than Magana cutting it off gets one more try (see [say]).
class Speaker {
  Speaker({FlutterTts? tts, ClipLibrary? clips, ClipPlayer? clipPlayer})
    : _ttsInstance = tts,
      clips = clips ?? ClipLibrary(),
      // ignore: prefer_initializing_formals
      _clipPlayer = clipPlayer {
    if (tts != null) _listen(tts);
  }

  /// Recorded prompts, played instead of the phone's voice where a clip exists (clips.dart).
  ClipLibrary clips;

  /// Magana's own words in English when Hausa, Yorùbá or Igbo has no voice (guidance.dart).
  EnglishGuidance guidance = EnglishGuidance();

  /// Settings → Voice: "Spoken guidance in English" (on unless turned off).
  bool englishGuidance = true;

  /// The English sentence said once per language before the first English guidance ("Spoken
  /// guidance is in English for now. Hausa voice is coming."), and the app shows it
  /// ([onEnglishGuidance], main.dart). Languages already told (kept on the phone).
  String Function(String language)? englishGuidanceNotice;
  void Function(String language)? onEnglishGuidance;
  final englishGuidanceTold = <String>{};
  ClipPlayer? _clipPlayer;
  ClipPlayer get clipPlayer => _clipPlayer ??= AssetClipPlayer();
  set clipPlayer(ClipPlayer p) => _clipPlayer = p;

  /// Called once per language, the first time something in [ownVoiceOnly] can't be said for
  /// want of a voice: the app says "I don't have a Hausa voice yet" and the text stays on the
  /// screen (main.dart).
  void Function(String language)? onNoVoice;
  final _noVoiceTold = <String>{};

  /// The language the engine's voice is set for now.
  String? _voiceLang;
  Voice? _voice;

  /// The voice used for the app language, once chosen (Settings → Voice).
  Voice? get voice => _voice;
  List<Voice>? _installed;

  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= _listen(FlutterTts());
  Completer<Spoken>? _pending;
  String _text = '';
  bool _started = false;
  bool _active =
      false; // the engine is speaking (or has not yet reported a stop)
  int _turn = 0; // goes up with every say() and stop()
  double _rate = 1.0;
  String _languageCode = 'en';

  /// Web only: true until the first press, while the browser won't speak. The
  /// app then covers the screen with "Start Magana" (see [start]).
  final needsStart = ValueNotifier<bool>(false);
  String? _waiting; // the latest text that couldn't be spoken yet

  double get rate => _rate;

  /// VoiceOver or TalkBack is on: when it cuts Magana off, the person is moving around the
  /// screen, so the words are not said again.
  bool screenReaderOn = false;

  /// True while an utterance is playing or about to.
  bool get speaking => _pending != null;

  FlutterTts _listen(FlutterTts tts) {
    tts.setStartHandler(() {
      _started = _active = true;
      diagnostics.spoke(started: true);
    });
    // A stop() can deliver the old utterance's cancel event late; only finish
    // the current utterance once it has actually started.
    tts.setCompletionHandler(() {
      _active = false;
      _finish(Spoken.finished, onlyIfStarted: true);
    });
    tts.setCancelHandler(() {
      _active = false;
      _finish(Spoken.cutOff, onlyIfStarted: true);
    });
    // On the web the plugin passes SpeechSynthesisErrorEvent.error.
    tts.setErrorHandler((error) {
      _active = false;
      _onError('$error');
    });
    return tts;
  }

  void _onError(String error) {
    // Magana's own stop finished the utterance already: the engine's report is normal.
    final ours =
        _pending == null && (error == 'interrupted' || error == 'canceled');
    devLog(
      ours
          ? 'speech "$error" after Magana stopped "$_text" (normal)'
          : 'speech error "$error" while saying "$_text"',
    );
    switch (error) {
      case 'not-allowed' when runningOnWeb:
        _waiting = _text;
        needsStart.value = true;
        _finish(Spoken.blocked);
      // Magana's own stops finish the utterance before the engine reports them,
      // so an interruption that reaches a started utterance came from elsewhere.
      case 'interrupted' || 'canceled':
        _finish(Spoken.cutOff, onlyIfStarted: true);
      default:
        _finish(Spoken.failed);
    }
  }

  /// The app language: Magana's own words are said in it. Its voice is chosen when first
  /// needed ([voiceReady]).
  Future<void> setLanguage(String code) async {
    _languageCode = code;
    _voiceLang = null;
    if (_ttsInstance != null) await voiceReady(code);
  }

  String get language => _languageCode;

  /// The voices on this phone, or null when the phone can't say (tests; some browsers until
  /// their voices load).
  Future<List<Voice>?> installedVoices() async {
    if (_installed case final list? when list.isNotEmpty) return list;
    try {
      final raw = await _tts.getVoices;
      final list = [
        if (raw is List)
          for (final v in raw) ?Voice.fromMap(v),
      ];
      return _installed = list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  /// A voice was chosen in Settings, or voices were installed: choose again.
  void refreshVoices() {
    _installed = null;
    _voiceLang = null;
    _voiceOk.clear();
  }

  /// Can [lang] be said aloud: a recorded clip or a voice of its own (for Hausa, Yorùbá and
  /// Igbo), or any voice (English)? The Reader asks before reading a page in [lang].
  Future<bool> canSpeak(String lang) async {
    if (!ownVoiceOnly.contains(lang)) return true;
    final voices = await installedVoices();
    if (voices != null) return bestVoice(voices, lang) != null;
    return _engineHas(lang);
  }

  /// Without a voice list: does the engine say it has [lang]? Unknown (tests) counts as yes.
  Future<bool> _engineHas(String lang) async {
    try {
      for (final l in ['$lang-NG', lang]) {
        if (await _tts.isLanguageAvailable(l) == true) return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }

  /// Sets the engine's voice for [lang]: the one chosen in Settings, else the best installed
  /// ([bestVoice]: Nigerian English first, then enhanced or neural voices). False when [lang]
  /// is Hausa, Yorùbá or Igbo and the phone has no voice for it: never another language's.
  @protected
  Future<bool> voiceReady(String lang) async {
    if (lang == _voiceLang) return true;
    final tts = _tts;
    final voices = await installedVoices();
    if (voices != null) {
      final chosen = await VoiceSettings.chosen(lang);
      final v =
          voices
              .where((v) => v.name == chosen && v.language == lang)
              .firstOrNull ??
          bestVoice(voices, lang);
      if (v != null) {
        try {
          await tts.setVoice(v.asMap);
        } catch (e) {
          devLog('speech: voice $v not set ($e)');
        }
        _voiceLang = lang;
        if (lang == _languageCode) _voice = v;
        await _applyRate(tts);
        return true;
      }
      if (ownVoiceOnly.contains(lang)) return false;
    } else if (ownVoiceOnly.contains(lang) && !await _engineHas(lang)) {
      return false;
    }
    // English with no voice list, or a language with no voice of its own that may borrow one.
    for (final l in [
      if (ownVoiceOnly.contains(lang)) ...['$lang-NG', lang],
      if (!ownVoiceOnly.contains(lang)) ...[
        '$lang-NG',
        lang,
        'en-NG',
        'en-GB',
        'en-US',
      ],
    ]) {
      try {
        if (await tts.isLanguageAvailable(l) == true) {
          await tts.setLanguage(l);
          break;
        }
      } catch (_) {}
    }
    _voiceLang = lang;
    await _applyRate(tts);
    return true;
  }

  /// Whether [lang] has a voice, when already known: speech then starts without waiting.
  final _voiceOk = <String, bool>{};
  @protected
  bool? voiceKnown(String lang) =>
      lang == _voiceLang ? true : (_voiceOk[lang] == false ? false : null);

  Future<bool> _checkVoice(String lang) async =>
      _voiceOk[lang] = await voiceReady(lang);

  /// "Play sample" (Settings → Voice): [text] in [v], then the usual voice again.
  Future<bool> preview(Voice v, String text) async {
    await stop();
    try {
      await _tts.setVoice(v.asMap);
      await _applyRate(_tts);
    } catch (_) {}
    _voiceLang = null; // the next utterance sets the chosen voice again
    return await utter(text) == Spoken.finished;
  }

  Future<void> _applyRate(FlutterTts tts) async {
    try {
      await tts.setSpeechRate(normalSpeechRate * _rate);
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    await _applyRate(_tts);
  }

  /// Says [text] in [language] (the app language unless given). If something other than
  /// Magana cuts it off (TalkBack announcing a new screen, say), waits [retryDelay] and says it
  /// once more, unless Magana has moved on or [wanted] turned false. True if it was heard to
  /// the end, or there was nothing to hear (no voice for the language: the text is on screen).
  Future<bool> say(String text, {bool Function()? wanted, String? language}) =>
      sayParts([SpeechPart(text, language ?? _languageCode)], wanted: wanted);

  /// Says [parts] in turn, each in its own language's voice; neighbours in the same language
  /// are said as one sentence ("Line 2. Take one tablet."). A recorded clip is played where
  /// there is one ([clips]). Hausa, Yorùbá or Igbo without a voice of its own is not said:
  /// [onNoVoice] tells the person once.
  Future<bool> sayParts(
    List<SpeechPart> parts, {
    bool Function()? wanted,
  }) async {
    final turn = ++_turn;
    final merged = <SpeechPart>[];
    for (final p in parts) {
      if (p.text.trim().isEmpty) continue;
      // Page text and Magana's words stay apart only where it matters: in a language that may
      // have no voice (Magana's words then go into English, the page's never).
      if (merged.isNotEmpty &&
          merged.last.language == p.language &&
          (merged.last.guidance == p.guidance ||
              !ownVoiceOnly.contains(p.language))) {
        merged.last = SpeechPart(
          '${merged.last.text}. ${p.text}',
          p.language,
          guidance: merged.last.guidance && p.guidance,
        );
      } else {
        merged.add(p);
      }
    }
    if (needsStart.value) {
      _waiting = merged.map((p) => p.text).join(' '); // said after "Start Magana"
      devLog('speech waits for Start Magana: "$_waiting"');
      return false;
    }
    var first = true;
    for (final part in merged) {
      final pieces =
          clips.planNow(part.language, part.text) ??
          [ClipPart(part.text, null)];
      for (final piece in pieces) {
        // After the first piece: stop if Magana moved on or the person pressed something.
        if (turn != _turn || (!first && !(wanted?.call() ?? true))) return false;
        first = false;
        final ok = piece.clip != null
            ? await _playClip(piece, part.language, turn, wanted)
            : await _sayWithVoice(
                piece.text,
                part.language,
                turn,
                wanted,
                guidance: part.guidance,
              );
        if (!ok) return false;
      }
    }
    return true;
  }

  Future<bool> _sayWithVoice(
    String text,
    String lang,
    int turn,
    bool Function()? wanted, {
    bool guidance = true,
  }) async {
    if (!(voiceKnown(lang) ?? await _checkVoice(lang))) {
      // Magana's own words: in English, if the person hasn't turned that off.
      if (guidance && englishGuidance && ownVoiceOnly.contains(lang)) {
        final english = await this.guidance.toEnglish(lang, text);
        if (turn != _turn) return false;
        if (english != null && (voiceKnown('en') ?? await _checkVoice('en'))) {
          var say = english;
          if (englishGuidanceTold.add(lang)) {
            onEnglishGuidance?.call(lang);
            if (englishGuidanceNotice?.call(lang) case final notice?) {
              say = '$notice $english';
            }
          }
          return _sayWithVoice(say, 'en', turn, wanted);
        }
      }
      devLog('speech: no $lang voice on this phone; not said: "$text"');
      if (_noVoiceTold.add(lang)) onNoVoice?.call(lang);
      return true; // nothing to hear: the text is on the screen
    }
    if (turn != _turn) return false;
    final first = await utter(text);
    if (first != Spoken.cutOff || screenReaderOn) {
      return first == Spoken.finished;
    }
    devLog('speech cut off by something else; saying it once more: "$text"');
    await Future<void>.delayed(retryDelay);
    if (turn != _turn || !(wanted?.call() ?? true)) return false;
    return await utter(text) == Spoken.finished;
  }

  /// A recorded clip; if it can't play, the phone's voice says the words instead.
  Future<bool> _playClip(
    ClipPart piece,
    String lang,
    int turn,
    bool Function()? wanted,
  ) async {
    await _halt();
    if (screenReaderOn) {
      await screenReaderQuiet();
      if (turn != _turn) return false;
    }
    diagnostics.asked('[clip ${piece.clip}] ${piece.text}');
    final done = await clipPlayer.play(piece.clip!);
    if (turn != _turn) return false;
    return done || await _sayWithVoice(piece.text, lang, turn, wanted);
  }

  /// For reading loops: [say], stopping if [wanted] turns false (the learner
  /// pressed something) before the second try.
  Future<bool> sayThrough(
    String text, {
    required bool Function() wanted,
    String? language,
  }) => say(text, wanted: wanted, language: language);

  static const retryDelay = Duration(milliseconds: 1500);

  /// iPhone: speech plays with the silent switch on, and next to VoiceOver. The playback
  /// category ignores the switch; spokenAudio mode, ducking other sound, pauses other spoken
  /// audio (podcasts). Set before every utterance: recording a voice note or an answer
  /// switches the session to record mode, which would send speech to the quiet earpiece.
  static Future<void> iosAudio(FlutterTts tts) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await tts.setSharedInstance(true);
      await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions
            .interruptSpokenAudioAndMixWithOthers,
      ], IosTextToSpeechAudioMode.spokenAudio);
    } catch (e) {
      devLog('speech: iOS audio session not set ($e)');
    }
  }

  /// One utterance, no retry. Replaceable in tests.
  @protected
  Future<Spoken> utter(String text) async {
    await _halt();
    // Never over TalkBack: it is reading what the person touched (docs/TALKBACK_AUDIT.md).
    if (screenReaderOn) {
      final turn = _turn;
      await screenReaderQuiet();
      // Stopped or replaced meanwhile.
      if (turn != _turn) return Spoken.stoppedByMagana;
    }
    await iosAudio(_tts);
    diagnostics.asked(
      text,
    ); // the exact text sent to the voice (diagnostics screen)
    _text = text;
    final done = _pending = Completer<Spoken>();
    _started = false;
    await _tts.speak(text);
    // Never hang a reading loop on an utterance the engine silently dropped.
    Timer(const Duration(seconds: 3), () {
      if (identical(_pending, done) && !_started) _finish(Spoken.finished);
    });
    return done.future;
  }

  /// The first press on the web: speech is allowed from now on, and the text
  /// that was waiting is said.
  Future<void> start() async {
    needsStart.value = false;
    final text = _waiting;
    _waiting = null;
    if (text != null) await say(text);
  }

  Future<void> stop() async {
    _turn++;
    await _halt();
  }

  Future<void> _halt() async {
    _finish(Spoken.stoppedByMagana);
    if (_clipPlayer != null) await _clipPlayer!.stop();
    try {
      await _tts.stop();
    } catch (e) {
      devLog('speech: stop failed ($e)');
    }
    // The web engine ignores speak() until the cancelled utterance reports
    // back, so wait briefly for that before the next say().
    for (var i = 0; i < 20 && _active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    _active = false;
  }

  void _finish(Spoken how, {bool onlyIfStarted = false}) {
    if (onlyIfStarted && !_started) return;
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) {
      diagnostics.spoke(started: false, outcome: how.name);
      c.complete(how);
    }
  }
}
