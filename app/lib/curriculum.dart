/// Class levels and subjects, after the Nigerian national curriculum's subject
/// names. Mirrors backend/app/curriculum.py; test/curriculum_test.dart compares
/// this with assets/curriculum.json, which the backend's tests compare with the
/// backend.
library;

enum Band {
  primary13('primary_1_3'),
  primary46('primary_4_6'),
  jss('jss'),
  sss('sss');

  const Band(this.id);
  final String id;

  /// Primary mode: two or three options, short sentences, a slower voice and
  /// encouraging feedback.
  bool get primary => this == primary13 || this == primary46;
}

/// The curriculum's names for each band.
const bandNames = {
  Band.primary13: 'Primary 1–3',
  Band.primary46: 'Primary 4–6',
  Band.jss: 'JSS 1–3',
  Band.sss: 'SSS 1–3',
};

class ClassLevel {
  const ClassLevel(this.id, this.name, this.band);
  final String id; // p1 … p6, jss1 … jss3, sss1 … sss3
  final String name; // "Primary 5", "JSS 2": the curriculum's names
  final Band band;
}

const classLevels = [
  ClassLevel('p1', 'Primary 1', Band.primary13),
  ClassLevel('p2', 'Primary 2', Band.primary13),
  ClassLevel('p3', 'Primary 3', Band.primary13),
  ClassLevel('p4', 'Primary 4', Band.primary46),
  ClassLevel('p5', 'Primary 5', Band.primary46),
  ClassLevel('p6', 'Primary 6', Band.primary46),
  ClassLevel('jss1', 'JSS 1', Band.jss),
  ClassLevel('jss2', 'JSS 2', Band.jss),
  ClassLevel('jss3', 'JSS 3', Band.jss),
  ClassLevel('sss1', 'SSS 1', Band.sss),
  ClassLevel('sss2', 'SSS 2', Band.sss),
  ClassLevel('sss3', 'SSS 3', Band.sss),
];

ClassLevel? levelById(String? id) =>
    classLevels.where((l) => l.id == id).firstOrNull;

const subjectNames = {
  'english': 'English',
  'mathematics': 'Mathematics',
  'basic_science': 'Basic Science',
  'social_studies': 'Social Studies',
  'hausa': 'Hausa',
  'yoruba': 'Yorùbá',
  'igbo': 'Igbo',
  'biology': 'Biology',
  'chemistry': 'Chemistry',
  'physics': 'Physics',
};

const _languages = ['hausa', 'yoruba', 'igbo'];
const bandSubjects = {
  Band.primary13: [
    'english',
    'mathematics',
    'basic_science',
    'social_studies',
    ..._languages,
  ],
  Band.primary46: [
    'english',
    'mathematics',
    'basic_science',
    'social_studies',
    ..._languages,
  ],
  Band.jss: [
    'english',
    'mathematics',
    'basic_science',
    'social_studies',
    ..._languages,
  ],
  Band.sss: [
    'english',
    'mathematics',
    'biology',
    'chemistry',
    'physics',
    ..._languages,
  ],
};

/// The team-made sample packs bundled with the app, per band
/// (`assets/quiz/<band>-<subject>.json`). SSS has Biology for its science.
const samplePacks = {
  Band.primary13: ['english', 'mathematics', 'basic_science'],
  Band.primary46: ['english', 'mathematics', 'basic_science'],
  Band.jss: ['english', 'mathematics', 'basic_science'],
  Band.sss: ['english', 'mathematics', 'biology'],
};

String samplePackAsset(Band band, String subject) =>
    'assets/quiz/${band.id}-$subject.json';
