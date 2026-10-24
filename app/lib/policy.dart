/// Age tiers and what each may use. Mirrors backend/app/policy.py (CLAUDE.md rule 4);
/// the app hides what a tier can't use, and the backend refuses it anyway.
enum Tier {
  standard, // 18+: everything
  guided, // 13–17: school subjects only, after a guardian's consent
  classroom, // under 13: only in a teacher-run session
}

enum Feature {
  readSchoolwork,
  explain,
  quiz,
  skills,
  everydayHealth,
  everydayMoney,
  everydayLetters, // letters, forms and notices (18+)
  healthCallback,
  openChat,
  // App-only features (no backend endpoint yet).
  library,
  reminders,
  score,
  champions,
}

const _allowed = <Tier, Set<Feature>>{
  Tier.standard: {...Feature.values},
  Tier.guided: {
    Feature.readSchoolwork,
    Feature.explain,
    Feature.quiz,
    Feature.skills,
    Feature.library,
    Feature.score,
  },
  Tier.classroom: {Feature.readSchoolwork, Feature.quiz},
};

bool allows(Tier tier, Feature feature) => _allowed[tier]!.contains(feature);
