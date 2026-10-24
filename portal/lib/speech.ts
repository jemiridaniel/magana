// "Listen as a learner": the browser's text-to-speech, as the learner app uses it on the web
// (app/lib/speech.dart): a Nigerian English voice first, then British, then American, at the
// app's normal web rate. Primary classes hear it slower, as in the app's Primary mode.
const PRIMARY_RATE = 0.8; // app/lib/screens/quiz.dart, primaryQuizRate

export const canSpeak = () => typeof window !== "undefined" && "speechSynthesis" in window;

function voice(): SpeechSynthesisVoice | undefined {
  const voices = window.speechSynthesis.getVoices();
  for (const lang of ["en-NG", "en-GB", "en-US"]) {
    const v = voices.find((x) => x.lang.replace("_", "-") === lang);
    if (v) return v;
  }
  return voices.find((x) => x.lang.startsWith("en"));
}

export function speak(text: string, { primary = false } = {}): void {
  if (!canSpeak()) return;
  window.speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  const v = voice();
  if (v) u.voice = v;
  u.lang = v?.lang ?? "en-NG";
  u.rate = primary ? PRIMARY_RATE : 1;
  window.speechSynthesis.speak(u);
}

export function stopSpeaking(): void {
  if (canSpeak()) window.speechSynthesis.cancel();
}
