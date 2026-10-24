# TalkBack test helpers

Scripts we use to check Magana on the Android emulator with TalkBack on, the way a blind
user would use it: touch to focus, double tap to activate, swipe to move.

- `talkback.py`: find controls by accessibility label, touch and double tap them through the
  emulator console, swipe, take screenshots, turn TalkBack on and off.
- `quick_check.py`: walks the Ibà quick check from Home to the result.

Setup: emulator `Medium_Phone_API_36.1` started with `-cores 4 -memory 4096`, console on
port 5554 (token in `~/.emulator_console_auth_token`), backend on port 8765, app built with
`--dart-define=MAGANA_API=http://10.0.2.2:8765`. Override `ADB` or
`EMULATOR_CONSOLE_PORT` if yours differ.

Known pitfalls (measured, see docs/FINDINGS.md):
- `uiautomator dump` briefly disturbs accessibility: a touch right after it can reach the app
  as a plain click, and it cuts off the app's speech. `tb()` waits 2.5 s after finding a
  control; when checking continuous reading, wait and look once instead of polling.
- System screens (permission dialogs, the photo picker, Settings) label buttons with `text`
  only; find their bounds in `nodes()` and use `tb_at(x, y)`.
- This is an emulator. It is not a substitute for testing with blind and low-vision users on
  real low-cost phones.
