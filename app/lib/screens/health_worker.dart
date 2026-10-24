import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';

/// Opens "Talk to a health worker". (Built in the next step; until then it says so.)
void openHealthWorker(BuildContext context) {
  final l = AppLocalizations.of(context);
  final msg = l.comingSoon(l.talkToNurse);
  AppScope.of(context).speaker.say(msg);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontSize: 18))),
    );
}
