// Named constructor parameters can't be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart' show ClassLink;
import 'curriculum.dart';
import 'policy.dart';

/// Who is using Magana: their age tier, (for 13–17) whether their guardian agreed,
/// where they are in life (in school, finished, university or other), adults'
/// goals, and the phone's link to a class. Saved on the phone. A Classroom
/// session is never saved: a teacher starts it each time, and it ends when the
/// app closes.
///
/// Consent for 13–17 comes from the class teacher, who records it in the teacher
/// portal; the app learns it from the class link (/learner/me). Until then the
/// learner is "waiting": they may read schoolwork pages and nothing else.
class ProfileController extends ChangeNotifier {
  ProfileController({
    Tier? tier,
    DateTime? consentAt,
    bool teacherSession = false,
    String? classLevel,
    String? who,
    ClassLink? link,
  }) : _tier = tier,
       _consentAt = consentAt,
       _teacherSession = teacherSession,
       _classLevel = classLevel,
       _who = who,
       _link = link;

  Tier? _tier;
  String? _classLevel;
  DateTime? _consentAt;
  bool _teacherSession;

  Tier? get tier => _tier;
  bool get onboarded => _tier != null;
  bool get guardianConsent => _consentAt != null;
  bool get teacherSession => _teacherSession;

  /// The learner's class (a curriculum level id such as p5 or jss2), or
  /// [notInSchool]; null until chosen. Chosen once in onboarding; a teacher
  /// can change it in Settings. Classroom sessions keep it for the session only.
  String? get classLevel => _classLevel;
  ClassLevel? get level => levelById(_classLevel);
  static const notInSchool = 'none';

  /// The tier can be used now: Guided needs consent, Classroom a teacher session.
  bool get active => switch (_tier) {
    null => false,
    Tier.standard => true,
    Tier.guided => guardianConsent,
    Tier.classroom => _teacherSession,
  };

  /// 13–17 whose guardian hasn't agreed yet: schoolwork reading only.
  bool get waitingForConsent => _tier == Tier.guided && !guardianConsent;

  bool can(Feature f) => waitingForConsent
      ? f == Feature.readSchoolwork
      : active && allows(_tier!, f);

  /// in_school | finished | other (A1, "Who is using Magana?"); null before.
  String? get who => _who;
  String? _who;

  /// Adults who finished school: what they want to do (A5); change freely.
  List<String> get goals => List.unmodifiable(_goals);
  List<String> _goals = [];

  /// The phone's class link, or null.
  ClassLink? get link => _link;
  ClassLink? _link;

  /// Set when the backend says the teacher removed this phone from its class; the
  /// app says so once.
  bool removedFromClass = false;

  /// Sent with every backend request; the backend enforces the same rules.
  Map<String, String> get headers => {
    if (_tier != null) 'X-Magana-Tier': _tier!.name,
    if (guardianConsent) 'X-Magana-Guardian-Consent': 'yes',
    if (_teacherSession) 'X-Magana-Teacher-Session': 'yes',
    if (_link != null) 'X-Magana-Learner': _link!.token,
  };

  static const _tierKey = 'age_tier';
  static const _consentKey = 'guardian_consent_at';
  static const _classKey = 'class_level';
  static const _whoKey = 'who';
  static const _goalsKey = 'goals';
  static const _linkKey = 'class_link';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tier = Tier.values
          .where((t) => t.name == prefs.getString(_tierKey))
          .firstOrNull;
      _consentAt = DateTime.tryParse(prefs.getString(_consentKey) ?? '');
      _classLevel = prefs.getString(_classKey);
      _who = prefs.getString(_whoKey);
      _goals = prefs.getStringList(_goalsKey) ?? [];
      final saved = prefs.getString(_linkKey);
      _link = saved == null
          ? null
          : ClassLink.fromSaved(jsonDecode(saved) as Map<String, dynamic>);
    } catch (_) {
      // Storage unavailable: onboarding runs again.
    }
    notifyListeners();
  }

  Future<void> setTier(Tier tier, {bool guardianConsent = false}) async {
    _tier = tier;
    _consentAt = tier == Tier.guided && guardianConsent ? DateTime.now() : null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tierKey, tier.name);
      if (_consentAt != null) {
        await prefs.setString(_consentKey, _consentAt!.toIso8601String());
      } else {
        await prefs.remove(_consentKey);
      }
    } catch (_) {}
  }

  Future<void> setWho(String who) async {
    _who = who;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_whoKey, who);
    } catch (_) {}
  }

  Future<void> setGoals(List<String> goals) async {
    _goals = [...goals];
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setStringList(
        _goalsKey,
        _goals,
      );
    } catch (_) {}
  }

  /// The class this phone joined (or null to forget it). Its level picks the
  /// practice packs; for 13–17 its status carries the teacher-recorded consent.
  Future<void> setLink(ClassLink? link) async {
    _link = link;
    if (link != null) {
      if (levelById(link.level) != null) {
        _classLevel = link.level;
      }
      if (_tier == Tier.guided) {
        _consentAt = link.status == 'active'
            ? (_consentAt ?? DateTime.now())
            : null;
      }
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (link == null) {
        await prefs.remove(_linkKey);
      } else {
        await prefs.setString(_linkKey, jsonEncode(link.toJson()));
        if (levelById(link.level) != null) {
          await prefs.setString(_classKey, link.level);
        }
      }
      if (_consentAt != null) {
        await prefs.setString(_consentKey, _consentAt!.toIso8601String());
      } else {
        await prefs.remove(_consentKey);
      }
    } catch (_) {}
  }

  /// What /learner/me says now. Removed or unknown: forget the class (and, for
  /// 13–17, the consent it carried) and say so once.
  Future<void> applyLinkStatus(
    String status,
    Map<String, dynamic>? classInfo,
  ) async {
    final link = _link;
    if (link == null) return;
    if (status == 'removed' || status == 'not_linked') {
      removedFromClass = true;
      await setLink(null);
      if (_tier == Tier.guided) {
        _consentAt = null;
        notifyListeners();
        try {
          await (await SharedPreferences.getInstance()).remove(_consentKey);
        } catch (_) {}
      }
      return;
    }
    await setLink(
      classInfo == null
          ? ClassLink(
              token: link.token,
              status: status,
              className: link.className,
              level: link.level,
              teacher: link.teacher,
              school: link.school,
            )
          : ClassLink.fromJson({
              'status': status,
              'class': classInfo,
            }, token: link.token),
    );
  }

  Future<void> setClassLevel(String level) async {
    _classLevel = level;
    notifyListeners();
    if (_tier == Tier.classroom) return; // never saved (CLAUDE.md rule 4)
    try {
      await (await SharedPreferences.getInstance()).setString(_classKey, level);
    } catch (_) {}
  }

  /// The class session's code from the teacher portal: it opens that session's
  /// quizzes. Like the session, never saved.
  String? get sessionCode => _sessionCode;
  String? _sessionCode;

  /// A teacher starts a class session on this phone (any age group). With a
  /// [code], their quizzes for that session appear in Practice quiz.
  void startTeacherSession({String? code}) {
    _teacherSession = true;
    if (code != null) _sessionCode = code;
    notifyListeners();
  }

  /// Ends the session's quizzes. Classroom (under 13) keeps the session itself
  /// open, since nothing works without it; others leave teacher mode too.
  void endTeacherSession() {
    _sessionCode = null;
    if (_tier != Tier.classroom) _teacherSession = false;
    notifyListeners();
  }
}
