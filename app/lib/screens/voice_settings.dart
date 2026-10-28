import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../language.dart';
import '../voices.dart';
import '../widgets.dart';

/// Settings → Voice (Nurse Balogun, build 7): which installed voice reads each language, with a
/// sample, and the speed. "Best voice on this phone" is the default ([bestVoice]). Hausa, Yorùbá
/// and Igbo are never given another language's voice: without one, this says so.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  List<Voice>? _voices;
  bool _loaded = false;
  final _chosen = <String, String?>{};
  double _rate = 1.0;

  /// The app language, and English for English pages when the app is in another language.
  List<String> get _languages {
    final app = Localizations.localeOf(context).languageCode;
    return [app, if (app != 'en') 'en'];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    speakOnOpen(context, () => AppLocalizations.of(context).voiceTitle);
  }

  Future<void> _load() async {
    final speaker = AppScope.of(context).speaker;
    final voices = await speaker.installedVoices();
    final rate = await VoiceSettings.rate();
    for (final lang in _languages) {
      _chosen[lang] = await VoiceSettings.chosen(lang);
    }
    if (mounted) {
      setState(() {
        _voices = voices;
        _rate = rate;
        _loaded = true;
      });
    }
  }

  String _name(String lang) => appLanguages
      .firstWhere((a) => a.code == lang, orElse: () => appLanguages.first)
      .name;

  Future<void> _choose(String lang, Voice? v) async {
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    await VoiceSettings.choose(lang, v?.name);
    speaker.refreshVoices();
    setState(() => _chosen[lang] = v?.name);
    final sample = lookupAppLocalizations(Locale(lang)).voiceSample;
    final voice = v ?? bestVoice(_voices ?? const [], lang);
    if (voice != null) {
      await speaker.preview(voice, sample);
    } else {
      await speaker.say(l.voiceBest);
    }
  }

  Future<void> _sample(String lang) async {
    final speaker = AppScope.of(context).speaker;
    final voices = _voices ?? const <Voice>[];
    final v =
        voices.where((v) => v.name == _chosen[lang]).firstOrNull ??
        bestVoice(voices, lang);
    final sample = lookupAppLocalizations(Locale(lang)).voiceSample;
    v == null
        ? await speaker.say(sample, language: lang)
        : await speaker.preview(v, sample);
  }

  Future<void> _setRate(double rate) async {
    final l = AppLocalizations.of(context);
    final speaker = AppScope.of(context).speaker;
    await VoiceSettings.setRate(rate);
    await speaker.setRate(rate);
    setState(() => _rate = rate);
    await speaker.say(l.voiceSpeedSet(speedLabel(rate)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final voices = _voices;
    return PageScaffold(
      body: [
        ScreenHeader(title: l.voiceTitle),
        if (_loaded)
          for (final lang in _languages)
            ..._section(l, lang, voicesFor(voices ?? const [], lang)),
        if (_loaded && voices != null && betterEnglishVoiceAvailable(voices))
          NoteBox(
            text: '${l.voiceGetBetter}. ${_hint(l)}',
            kind: NoteKind.info,
          ),
        Semantics(
          header: true,
          child: Text(
            l.voiceSpeedTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        for (final rate in speechSpeeds)
          ChoiceCard(
            title: l.speed(speedLabel(rate)),
            selected: rate == _rate,
            inGroup: true,
            leading: Icon(
              rate == _rate
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 28,
            ),
            onTap: () => _setRate(rate),
          ),
      ],
    );
  }

  List<Widget> _section(AppLocalizations l, String lang, List<Voice> list) {
    final name = _name(lang);
    final chosen = _chosen[lang];
    final header = Semantics(
      header: true,
      child: Text(
        l.voiceFor(name),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
    // No voice list (some browsers): the phone's default voice, nothing to choose.
    if (_voices == null) {
      return [
        header,
        SecondaryButton(label: l.voicePlaySample, onTap: () => _sample(lang)),
      ];
    }
    if (list.isEmpty) {
      return [
        header,
        NoteBox(text: l.voiceNone(name), kind: NoteKind.warning),
      ];
    }
    Widget radio(bool on) => Icon(
      on ? Icons.radio_button_checked : Icons.radio_button_off,
      size: 28,
    );
    final picked = list.any((v) => v.name == chosen) ? chosen : null;
    return [
      header,
      ChoiceCard(
        title: l.voiceBest,
        detail: l.voiceBestDetail,
        selected: picked == null,
        inGroup: true,
        leading: radio(picked == null),
        onTap: () => _choose(lang, null),
      ),
      for (final v in list)
        ChoiceCard(
          title: voiceLabel(v, name),
          detail: v.name,
          selected: v.name == picked,
          inGroup: true,
          leading: radio(v.name == picked),
          onTap: () => _choose(lang, v),
        ),
      SecondaryButton(label: l.voicePlaySample, onTap: () => _sample(lang)),
    ];
  }

  String _hint(AppLocalizations l) =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? l.voiceHintIos
      : l.voiceHintAndroid;
}

/// "1×", "1.25×": the Reader's speed button says the same.
String speedLabel(double rate) =>
    '${rate.toString().replaceFirst(RegExp(r'\.0$'), '')}×';

/// "English (Nigeria), high quality": the voice's language, country and quality, as a person
/// would say them (the engine's own names are codes like "en-ng-x-tfn-local").
String voiceLabel(Voice v, String languageName) {
  const regions = {
    'NG': 'Nigeria',
    'GB': 'United Kingdom',
    'US': 'United States',
    'GH': 'Ghana',
    'KE': 'Kenya',
    'ZA': 'South Africa',
    'IN': 'India',
    'AU': 'Australia',
    'IE': 'Ireland',
    'CA': 'Canada',
  };
  final region = regions[v.region] ?? v.region;
  final quality = switch (v.quality) {
    'premium' || 'very high' || 'very_high' => 'premium',
    'enhanced' || 'high' => 'high quality',
    _ when '${v.name} ${v.identifier}'.toLowerCase().contains('compact') =>
      'compact',
    _ => '',
  };
  return [
    region.isEmpty ? languageName : '$languageName ($region)',
    if (quality.isNotEmpty) quality,
    if (v.network) 'online',
  ].join(', ');
}

/// Once, on Home: if a clearer English voice can be downloaded than the best one installed
/// (Nigerian English on Android; an enhanced or premium voice on an iPhone), Magana says how to
/// get it, after the screen's own introduction. Settings → Voice says it too, every time.
Future<void> maybeTellAboutBetterVoice(BuildContext context) async {
  if (await VoiceSettings.hintTold() || !context.mounted) return;
  final speaker = AppScope.of(context).speaker;
  final voices = await speaker.installedVoices();
  if (voices == null || !betterEnglishVoiceAvailable(voices)) return;
  if (!context.mounted) return;
  await VoiceSettings.markHintTold();
  // After "Magana. 7 choices…": wait for the screen's introduction to finish.
  for (var i = 0; i < 40 && speaker.speaking; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  if (!context.mounted) return;
  final l = AppLocalizations.of(context);
  final hint = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? l.voiceHintIos
      : l.voiceHintAndroid;
  await speaker.say('${l.voiceGetBetter}. $hint');
}
