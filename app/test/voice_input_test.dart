import 'package:app/voice_input.dart';
import 'package:flutter_test/flutter_test.dart';

class Scripted implements VoiceInput {
  Scripted({this.works = true, this.fails = false, this.reply = const []});
  final bool works;
  final bool fails;
  final List<String> reply;
  final languages = <String>[];

  @override
  Future<bool> init() async => works;

  @override
  Future<List<String>> listen({String language = 'en'}) async {
    languages.add(language);
    if (fails) throw AsrUnavailable('503');
    return reply;
  }

  @override
  Future<void> stop() async {}
}

void main() {
  test('server ASR answers first, in the requested language', () async {
    final server = Scripted(reply: ['Ina son karanta']);
    final device = Scripted(reply: ['phone']);
    final v = HybridVoiceInput(server, device);
    expect(await v.init(), isTrue);
    expect(await v.listen(language: 'ha'), ['Ina son karanta']);
    expect(server.languages, ['ha']);
    expect(device.languages, isEmpty);
  });

  test('server without ASR or down: the phone answers, from then on', () async {
    final server = Scripted(fails: true);
    final device = Scripted(reply: ['option B']);
    final v = HybridVoiceInput(server, device);
    expect(await v.listen(language: 'en'), ['option B']);
    expect(await v.listen(language: 'en'), ['option B']);
    expect(server.languages, hasLength(1)); // not retried every time
    expect(device.languages, ['en', 'en']);
  });

  test('no microphone for either: nothing heard', () async {
    final v = HybridVoiceInput(Scripted(fails: true), Scripted(works: false));
    expect(await v.listen(), isEmpty);
  });
}
