import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// One voice installed on this phone (flutter_tts getVoices).
@immutable
class Voice {
  const Voice({
    required this.name,
    required this.locale,
    this.quality = '',
    this.network = false,
    this.identifier = '',
  });

  /// Android: "en-ng-x-tfn-local"; iPhone: "Samantha".
  final String name;

  /// "en-NG", "en_GB": as the phone gives it.
  final String locale;

  /// Android: "very high", "high", "normal", …; iPhone: "default", "enhanced", "premium".
  final String quality;

  /// Android: the voice needs the internet.
  final bool network;

  /// iPhone: "com.apple.voice.compact.en-US.Samantha".
  final String identifier;

  /// "en", "ha": the language part of [locale].
  String get language => locale.split(RegExp('[-_]')).first.toLowerCase();

  /// "NG", "GB", or "".
  String get region {
    final parts = locale.split(RegExp('[-_]'));
    return parts.length > 1 ? parts[1].toUpperCase() : '';
  }

  /// For flutter_tts setVoice.
  Map<String, String> get asMap => {
    'name': name,
    'locale': locale,
    if (identifier.isNotEmpty) 'identifier': identifier,
  };

  static Voice? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = '${raw['name'] ?? ''}';
    final locale = '${raw['locale'] ?? ''}';
    if (name.isEmpty || locale.isEmpty) return null;
    final net = '${raw['network_required'] ?? ''}'.toLowerCase();
    return Voice(
      name: name,
      locale: locale,
      quality: '${raw['quality'] ?? ''}'.toLowerCase(),
      network: net == '1' || net == 'true',
      identifier: '${raw['identifier'] ?? ''}',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Voice && other.name == name && other.locale == locale;
  @override
  int get hashCode => Object.hash(name, locale);
  @override
  String toString() => '$name ($locale, $quality)';
}

/// Hausa, Yorùbá and Igbo are never read with another language's voice (Nurse Balogun, build
/// 7): without a voice of their own, Magana says it has none and shows the text instead.
const ownVoiceOnly = {'ha', 'yo', 'ig'};

/// How good [v] is for [lang]: the language must match. Then Nigeria first (en-NG), British
/// English next for English (closer to Nigerian English than American), higher quality
/// (enhanced, premium, neural) over compact or low, and voices that work offline.
/// Null when [v] can't speak [lang].
int? voiceScore(Voice v, String lang) {
  if (v.language != lang) return null;
  final id = '${v.name} ${v.identifier}'.toLowerCase();
  var score = 0;
  if (v.region == 'NG') score += 100;
  if (lang == 'en' && v.region == 'GB') score += 5;
  score += switch (v.quality) {
    'premium' || 'very high' || 'very_high' => 30,
    'enhanced' || 'high' => 20,
    'low' => -10,
    'very low' || 'very_low' => -20,
    _ => 0,
  };
  if (id.contains('neural') || id.contains('wavenet') || id.contains('premium')) {
    score += 10;
  }
  if (id.contains('enhanced')) score += 5;
  if (id.contains('compact')) score -= 15;
  // iPhone novelty and robot voices ("Bells", "Bad News", Eloquence's "Grandpa").
  if (id.contains('speech.synthesis.voice') || id.contains('eloquence')) {
    score -= 50;
  }
  if (v.network) score -= 5;
  return score;
}

/// The best of [voices] for [lang], or null when none speaks it.
Voice? bestVoice(Iterable<Voice> voices, String lang) {
  Voice? best;
  int? bestScore;
  for (final v in voices) {
    final s = voiceScore(v, lang);
    if (s != null && (bestScore == null || s > bestScore)) {
      best = v;
      bestScore = s;
    }
  }
  return best;
}

/// [voices] that speak [lang], best first (Settings → Voice).
List<Voice> voicesFor(Iterable<Voice> voices, String lang) {
  final out = [
    for (final v in voices)
      if (voiceScore(v, lang) != null) v,
  ];
  out.sort((a, b) => voiceScore(b, lang)!.compareTo(voiceScore(a, lang)!));
  return out;
}

/// Is a better English voice to be had than the best one installed? Then Magana tells the
/// person once how to get it (Settings → Voice too): on Android, the Nigerian English voice
/// from Speech Services by Google; on an iPhone, an enhanced or premium voice.
bool betterEnglishVoiceAvailable(Iterable<Voice> voices) {
  final best = bestVoice(voices, 'en');
  if (best == null) return true;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return voiceScore(best, 'en')! < 20; // compact or default only
  }
  return best.region != 'NG';
}

/// The person's own choices (Settings → Voice), kept on this phone.
class VoiceSettings {
  static String _key(String lang) => 'voice_$lang';
  static const _rateKey = 'voice_rate';
  static const _hintKey = 'voice_hint_told';

  /// The voice chosen for [lang] (its name), or null for "best available".
  static Future<String?> chosen(String lang) async =>
      (await SharedPreferences.getInstance()).getString(_key(lang));

  static Future<void> choose(String lang, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    name == null
        ? await prefs.remove(_key(lang))
        : await prefs.setString(_key(lang), name);
  }

  /// The speed, 1.0 being normal (0.75–1.5, as the Reader's speed button).
  static Future<double> rate() async =>
      (await SharedPreferences.getInstance()).getDouble(_rateKey) ?? 1.0;

  static Future<void> setRate(double rate) async =>
      (await SharedPreferences.getInstance()).setDouble(_rateKey, rate);

  /// "A better voice can be downloaded" is said once only.
  static Future<bool> hintTold() async =>
      (await SharedPreferences.getInstance()).getBool(_hintKey) ?? false;

  static Future<void> markHintTold() async =>
      (await SharedPreferences.getInstance()).setBool(_hintKey, true);
}

/// The speeds offered (Settings → Voice and the Reader's speed button).
const speechSpeeds = [0.75, 1.0, 1.25, 1.5];
