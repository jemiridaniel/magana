// Parts of Magana that are built but switched off in this build.

/// Ibà, the AI health assistant (iba-natlas): not running in the test phase, as it needs a GPU
/// (Nurse Balogun's review, build 7). Off: "Talk to a health worker" offers the call-back
/// request, Magana's own danger-sign questions (backend triage.py) and the clinic / 112
/// advice, with "AI health assistant coming soon"; nothing says Ibà. On with
/// --dart-define=MAGANA_IBA=true once the service runs (docs/INFRA.md).
const ibaAssistant = bool.fromEnvironment('MAGANA_IBA');
