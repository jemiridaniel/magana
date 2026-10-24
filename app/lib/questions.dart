import 'package:shared_preferences/shared_preferences.dart';

/// Questions the learner saved for their next clinic visit (from a medical
/// report). Kept on this phone only; Magana never answers them itself.
class SavedQuestions {
  static const _key = 'saved_questions';

  static Future<List<String>> load() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? [];

  static Future<void> add(String question) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [...await load(), question]);
  }

  static Future<void> remove(String question) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await load()
      ..remove(question);
    await prefs.setStringList(_key, all);
  }
}
