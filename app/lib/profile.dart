// Named constructor parameters can't be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'policy.dart';

/// Who is using Magana: their age tier, and (for 13–17) when a guardian agreed.
/// Saved on the phone. A Classroom session is never saved: a teacher starts it
/// each time, and it ends when the app closes.
class ProfileController extends ChangeNotifier {
  ProfileController({
    Tier? tier,
    DateTime? consentAt,
    bool teacherSession = false,
  }) : _tier = tier,
       _consentAt = consentAt,
       _teacherSession = teacherSession;

  Tier? _tier;
  DateTime? _consentAt;
  bool _teacherSession;

  Tier? get tier => _tier;
  bool get onboarded => _tier != null;
  bool get guardianConsent => _consentAt != null;
  bool get teacherSession => _teacherSession;

  /// The tier can be used now: Guided needs consent, Classroom a teacher session.
  bool get active => switch (_tier) {
    null => false,
    Tier.standard => true,
    Tier.guided => guardianConsent,
    Tier.classroom => _teacherSession,
  };

  bool can(Feature f) => active && allows(_tier!, f);

  /// Sent with every backend request; the backend enforces the same rules.
  Map<String, String> get headers => {
    if (_tier != null) 'X-Magana-Tier': _tier!.name,
    if (guardianConsent) 'X-Magana-Guardian-Consent': 'yes',
    if (_teacherSession) 'X-Magana-Teacher-Session': 'yes',
  };

  static const _tierKey = 'age_tier';
  static const _consentKey = 'guardian_consent_at';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _tier = Tier.values
          .where((t) => t.name == prefs.getString(_tierKey))
          .firstOrNull;
      _consentAt = DateTime.tryParse(prefs.getString(_consentKey) ?? '');
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

  void startTeacherSession() {
    _teacherSession = true;
    notifyListeners();
  }
}
