import 'package:app/platform.dart';
import 'package:app/platform/speech_support.dart';
import 'package:app/policy.dart';
import 'package:app/voice_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// A recogniser step with a scripted outcome.
class Scripted extends VoiceInput {
  Scripted(
    this.name, {
    this.works = true,
    this.fails = false,
    this.reply = const [],
    this.why,
  });
  final String? why;

  @override
  String? get unavailableReason => why;
  @override
  final String name;
  final bool works;
  final bool fails;
  final List<String> reply;
  final languages = <String>[];

  @override
  Future<bool> init() async => works;

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    languages.add(language);
    if (fails) throw VoiceStepFailed('$name failed');
    return reply;
  }

  @override
  Future<void> stop() async {}
}

/// What each step in a tier's chain is: on-device, server, or the network recogniser.
List<String> kinds(Tier tier) => [
  for (final s in voiceSteps(tier))
    switch (s) {
      SpeechVoiceInput(onDevice: true) => 'on-device',
      SpeechVoiceInput(onDevice: false) => 'network',
      ServerVoiceInput() => 'server',
      _ => 'other',
    },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which recognisers each tier may use', () {
    test(
      '18+: on-device, then Magana server, then the phone network recogniser',
      () {
        expect(kinds(Tier.standard), ['on-device', 'server', 'network']);
      },
    );

    for (final tier in [Tier.guided, Tier.classroom]) {
      test(
        '${tier.name} (under 18): never a recogniser that sends audio away',
        () {
          expect(kinds(tier), ['on-device', 'server']);
          expect(kinds(tier), isNot(contains('network')));
        },
      );
    }
  });

  test('on-device is only used when the phone really has it', () async {
    // speech_to_text quietly uses the network recogniser when there is no
    // on-device one, so Magana checks first and refuses.
    final original = onDeviceSpeechAvailable;
    onDeviceSpeechAvailable = () async => false;
    addTearDown(() => onDeviceSpeechAvailable = original);
    expect(await SpeechVoiceInput(onDevice: true).init(), isFalse);
  });

  group('the chain', () {
    test('on-device first, when the phone has it', () async {
      final onDevice = Scripted('on-device', reply: ['B']);
      final server = Scripted('server', reply: ['server']);
      final v = ChainVoiceInput([onDevice, server]);
      expect(await v.listen(language: 'en'), ['B']);
      expect(server.languages, isEmpty);
    });

    test(
      'no on-device recogniser: our server ASR, in the right language',
      () async {
        final server = Scripted('server', reply: ['Ina son karanta']);
        final v = ChainVoiceInput([
          Scripted('on-device', works: false),
          server,
        ]);
        expect(await v.init(), isTrue);
        expect(await v.listen(language: 'ha'), ['Ina son karanta']);
        expect(server.languages, ['ha']);
      },
    );

    test(
      'under 18, both fail: no recogniser, so the screen offers tapping',
      () async {
        final v = ChainVoiceInput([
          Scripted('on-device', works: false),
          Scripted('server', fails: true),
        ]);
        await expectLater(v.listen(), throwsA(isA<VoiceStepFailed>()));
      },
    );

    test('18+, both fail: the phone network recogniser', () async {
      final network = Scripted('network', reply: ['option B']);
      final server = Scripted('server', fails: true);
      final v = ChainVoiceInput([
        Scripted('on-device', works: false),
        server,
        network,
      ]);
      expect(await v.listen(), ['option B']);
      expect(await v.listen(), ['option B']);
      expect(server.languages, hasLength(1)); // a failed step isn't retried
    });

    test(
      'heard nothing is not a failure: the next recogniser is not tried',
      () async {
        final network = Scripted('network', reply: ['should not be used']);
        final v = ChainVoiceInput([Scripted('on-device'), network]);
        expect(await v.listen(), isEmpty);
        expect(network.languages, isEmpty);
      },
    );
  });

  group('development logs: every step and its outcome', () {
    final logs = <String>[];
    late void Function(String) original;
    setUp(() {
      original = devLog;
      logs.clear();
      devLog = logs.add;
    });
    tearDown(() => devLog = original);

    test('skipped steps say why, a failure names the next step', () async {
      final v = ChainVoiceInput([
        Scripted(
          'on-device recogniser',
          works: false,
          why: 'browsers have no on-device recogniser',
        ),
        Scripted('Magana server ASR', fails: true),
      ], skipped: voiceStepsSkipped(Tier.guided));
      await expectLater(v.listen(), throwsA(isA<VoiceStepFailed>()));
      expect(logs, [
        'voice: online recogniser skipped: Guided account (13 to 17)',
        'voice: on-device recogniser skipped: browsers have no on-device recogniser',
        'voice: Magana server ASR available',
        'voice: Magana server ASR failed: Magana server ASR failed; trying the next step',
        'voice: no recogniser left; tap answers instead',
      ]);
    });

    test('what was heard, and by which step', () async {
      final v = ChainVoiceInput([
        Scripted('Magana server ASR', fails: true),
        Scripted('online recogniser', reply: ['B']),
      ]);
      expect(await v.listen(), ['B']);
      expect(logs.last, "voice: online recogniser listened (en): heard [B]");
      logs.clear();
      await v.listen();
      // The failed step is not tried again, and the log says so.
      expect(
        logs.first,
        startsWith('voice: Magana server ASR skipped: failed earlier'),
      );
    });

    test('18+ skips nothing; under-18 accounts skip the online recogniser', () {
      expect(voiceStepsSkipped(Tier.standard), isEmpty);
      expect(voiceStepsSkipped(Tier.classroom).keys, ['online recogniser']);
    });
  });
}
