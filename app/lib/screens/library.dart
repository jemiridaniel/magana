import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../l10n/app_localizations.dart';
import '../library.dart';
import '../widgets.dart';
import 'reader.dart';

/// My library: readings the learner saved, kept on the phone for 30 days.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<SavedReading>? _saved;

  @override
  void initState() {
    super.initState();
    _load(speak: true);
  }

  Future<void> _load({bool speak = false}) async {
    final saved = await Library.load();
    if (!mounted) return;
    setState(() => _saved = saved);
    if (speak) {
      final l = AppLocalizations.of(context);
      AppScope.of(context).speaker.say(
        saved.isEmpty
            ? '${l.myLibrary}. ${l.libraryEmpty}'
            : '${l.myLibrary}. ${l.librarySubtitle}.',
      );
    }
  }

  Future<void> _open(SavedReading r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReaderScreen(result: r.result, paper: r.paper, savedId: r.id),
      ),
    );
    _load(); // it may have been deleted
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = _saved;
    final dates = MaterialLocalizations.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    return PageScaffold(
      body: [
        ScreenHeader(title: l.myLibrary, subtitle: l.librarySubtitle),
        if (saved == null)
          const Center(child: CircularProgressIndicator())
        else if (saved.isEmpty)
          NoteBox(text: l.libraryEmpty)
        else
          for (final r in saved)
            ChoiceCard(
              title: r.title(l.unclearNumber),
              detail: [
                r.paper?.title(l) ?? l.yourPage,
                l.librarySavedOn(dates.formatMediumDate(r.savedAt)),
                l.libraryDeletesIn(
                  DateUtils.dateOnly(r.deleteAt).difference(today).inDays,
                ),
              ].join(' · '),
              leading: Icon(
                r.paper?.icon ?? Icons.description_outlined,
                size: 30,
              ),
              onTap: () => _open(r),
            ),
        NoteBox(text: l.libraryPrivacy, kind: NoteKind.privacy),
      ],
    );
  }
}
