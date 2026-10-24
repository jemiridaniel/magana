"""Walk the Ibà quick check with TalkBack: Everyday papers -> Talk to a nurse -> the
quick check, answering each question, then print the result screen.

Run with the backend on port 8765, the app installed with
--dart-define=MAGANA_API=http://10.0.2.2:8765, an 18+ profile and TalkBack on.
    python3 tools/talkback/quick_check.py "No" "No" "No" "No" "I can't tell" "No"
Answers not given default to "No".
"""
import sys
import time

import talkback as t

answers = sys.argv[1:]
t.tb("Everyday papers")
time.sleep(3)
t.tb("Talk to a nurse. With the Ibà quick check")
time.sleep(4)
t.scroll_to("Answer a few quick questions first (Ibà)")  # below the fold
t.tb("Answer a few quick questions first (Ibà)", settle=0)
time.sleep(5)
for i in range(1, 21):
    now = [l for l, _ in t.labels()]
    progress = next((l for l in now if "question" in l and " of " in l), None)
    if progress is None:
        break
    answer = answers[i - 1] if i <= len(answers) else "No"
    print(i, answer, "|", progress.replace("\n", " · "))
    t.tb(answer, settle=0)
    time.sleep(4)
print("RESULT:", [l for l, _ in t.labels()][:5])
