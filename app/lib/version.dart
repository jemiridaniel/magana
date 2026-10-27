import 'package:package_info_plus/package_info_plus.dart';

/// "0.1.0 (11)": the installed build, shown small on Capture so a tester can see which build
/// they are testing (iPhone test, 27 Oct 2026: "was +10 ever installed?").
Future<String> appVersionLabel() => _label ??= PackageInfo.fromPlatform()
    .then((i) => '${i.version} (${i.buildNumber})')
    .catchError((Object _) => '');
Future<String>? _label;

/// "Version 0.1.0 (build 11)" in the app's words, or null where it can't be read (tests).
Future<({String version, String build})?> appVersion() =>
    PackageInfo.fromPlatform()
        .then<({String version, String build})?>(
          (i) => (version: i.version, build: i.buildNumber),
        )
        .catchError((Object _) => null);
