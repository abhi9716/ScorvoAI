import 'package:flutter/material.dart';

/// Full exam hierarchy: Exam → Stage → Paper → Subject → Chapter.
/// Sourced from official syllabi (UPSC, SSC, IBPS, SBI, RRB) – 2026.

class Chapter {
  final String name;
  const Chapter(this.name);
}

class Subject {
  final String name;
  final List<Chapter> chapters;
  const Subject(this.name, this.chapters);
}

class Paper {
  final String code;        // e.g. "GS-I", "Tier-1"
  final String name;        // e.g. "General Studies Paper I"
  final List<Subject> subjects;
  const Paper({required this.code, required this.name, required this.subjects});
}

class ExamStage {
  final String code;        // e.g. "prelims", "mains"
  final String name;        // e.g. "Preliminary"
  final List<Paper> papers;
  const ExamStage({required this.code, required this.name, required this.papers});
}

class Exam {
  final String id;
  final String shortName;   // e.g. "UPSC CSE"
  final String fullName;
  final String description;
  final IconData icon;
  final Color color;
  final List<ExamStage> stages;
  const Exam({
    required this.id,
    required this.shortName,
    required this.fullName,
    required this.description,
    required this.icon,
    required this.color,
    required this.stages,
  });

  // Flatten all subjects across stages/papers for quick selection
  List<Subject> get allSubjects {
    final seen = <String>{};
    final out = <Subject>[];
    for (final s in stages) {
      for (final p in s.papers) {
        for (final sub in p.subjects) {
          if (seen.add(sub.name)) out.add(sub);
        }
      }
    }
    return out;
  }
}

// ── Chapter shorthand ──────────────────────────────────────────────────────
List<Chapter> _ch(List<String> names) => names.map((n) => Chapter(n)).toList();

// ── Reusable subject definitions ───────────────────────────────────────────
final _quantSubject = Subject('Quantitative Aptitude', _ch([
  'Number Systems', 'Simplification', 'Percentage', 'Ratio & Proportion',
  'Average', 'Profit & Loss', 'Discount', 'Simple & Compound Interest',
  'Time & Work', 'Time, Speed & Distance', 'Mixture & Allegation',
  'Algebra', 'Linear Equations', 'Quadratic Equations',
  'Geometry', 'Mensuration 2D', 'Mensuration 3D', 'Trigonometry',
  'Heights & Distances', 'Data Interpretation', 'Permutation & Combination',
  'Probability', 'Statistics',
]));

final _reasoningSubject = Subject('Reasoning & General Intelligence', _ch([
  'Analogy', 'Classification', 'Series', 'Coding-Decoding',
  'Blood Relations', 'Direction Sense', 'Ranking & Order', 'Seating Arrangement',
  'Puzzles', 'Syllogism', 'Inequality', 'Statement & Conclusion',
  'Statement & Assumption', 'Cause & Effect', 'Course of Action',
  'Decision Making', 'Cubes & Dice', 'Mirror Image', 'Paper Folding',
  'Embedded Figures', 'Non-Verbal Reasoning',
]));

final _englishSubject = Subject('English Language', _ch([
  'Reading Comprehension', 'Cloze Test', 'Para Jumbles', 'Sentence Improvement',
  'Error Spotting', 'Fill in the Blanks', 'One Word Substitution',
  'Idioms & Phrases', 'Synonyms', 'Antonyms', 'Active-Passive Voice',
  'Direct-Indirect Speech', 'Spellings', 'Vocabulary', 'Grammar Rules',
]));

final _generalAwareness = Subject('General Awareness', _ch([
  'Current Affairs (National)', 'Current Affairs (International)',
  'Sports', 'Awards & Honours', 'Books & Authors', 'Important Days',
  'Static GK', 'Government Schemes', 'Indian Polity', 'Indian Geography',
  'Indian History', 'Economy', 'Science', 'Environment',
]));

final _generalScience = Subject('General Science', _ch([
  'Physics: Motion', 'Physics: Force & Energy', 'Physics: Heat & Optics',
  'Physics: Electricity', 'Chemistry: Atomic Structure', 'Chemistry: Periodic Table',
  'Chemistry: Acids & Bases', 'Chemistry: Metals & Non-metals',
  'Biology: Cell', 'Biology: Human Physiology', 'Biology: Plants',
  'Biology: Genetics', 'Biology: Diseases', 'Environmental Science',
]));

final _computerAwareness = Subject('Computer Awareness', _ch([
  'Computer Fundamentals', 'Operating Systems', 'MS Office Suite',
  'Internet & Networking', 'Database Basics', 'Cyber Security',
  'Computer Shortcuts', 'Hardware vs Software', 'Programming Basics',
]));

final _bankingAwareness = Subject('Banking & Financial Awareness', _ch([
  'History of Banking', 'RBI & Monetary Policy', 'Banking Regulations',
  'Money Market & Capital Market', 'Types of Banks',
  'Banking Products & Services', 'Digital Banking', 'Insurance',
  'NPA & Recovery', 'Financial Inclusion', 'Government Schemes (Banking)',
  'Mutual Funds', 'International Financial Institutions',
]));

final _dataInterpretation = Subject('Data Interpretation & Analysis', _ch([
  'Tabular DI', 'Bar Graph DI', 'Line Graph DI', 'Pie Chart DI',
  'Mixed DI', 'Caselet DI', 'Data Sufficiency', 'Quadratic Comparison',
]));

// ── UPSC ───────────────────────────────────────────────────────────────────
final _upscHistory = Subject('History', _ch([
  'Ancient India', 'Medieval India', 'Modern India',
  'Indian National Movement', 'Post-Independence India', 'World History',
  'Art & Culture', 'Indian Heritage',
]));

final _upscGeography = Subject('Geography', _ch([
  'Physical Geography', 'Indian Geography', 'World Geography',
  'Economic Geography', 'Human Geography', 'Climatology', 'Oceanography',
  'Resources & Industries', 'Agriculture',
]));

final _upscPolity = Subject('Indian Polity & Governance', _ch([
  'Constitution: Preamble & Features', 'Fundamental Rights',
  'Directive Principles', 'Fundamental Duties', 'Union Executive',
  'Parliament', 'Judiciary', 'State Government', 'Local Government',
  'Constitutional Bodies', 'Statutory Bodies', 'Centre-State Relations',
  'Amendments', 'Public Policy', 'Rights Issues',
]));

final _upscEconomy = Subject('Indian Economy', _ch([
  'National Income', 'Inflation', 'Banking & Finance',
  'Budget & Fiscal Policy', 'Monetary Policy', 'Planning',
  'Poverty & Unemployment', 'Agriculture Economy', 'Industry',
  'External Sector', 'Economic Survey', 'Government Schemes',
]));

final _upscEnvironment = Subject('Environment & Ecology', _ch([
  'Ecosystems', 'Biodiversity', 'Climate Change',
  'Environmental Pollution', 'Conservation', 'Protected Areas',
  'Environmental Laws', 'International Conventions',
]));

final _upscScienceTech = Subject('Science & Technology', _ch([
  'Space Technology', 'Defence Technology', 'Nuclear Technology',
  'Biotechnology', 'Information Technology', 'Nanotechnology',
  'Robotics & AI', 'Recent Scientific Developments',
]));

final _upscEthics = Subject('Ethics, Integrity & Aptitude', _ch([
  'Ethics in Public Administration', 'Attitude', 'Aptitude',
  'Emotional Intelligence', 'Moral Thinkers', 'Probity in Governance',
  'Case Studies', 'Public/Civil Service Values',
]));

final _upscCsat = Subject('CSAT', _ch([
  'Comprehension', 'Logical Reasoning', 'Analytical Ability',
  'Decision Making', 'Problem Solving', 'Basic Numeracy',
  'Data Interpretation',
]));

// ── EXAMS ──────────────────────────────────────────────────────────────────
final List<Exam> kAllExams = [
  // UPSC Civil Services
  Exam(
    id: 'upsc_cse',
    shortName: 'UPSC CSE',
    fullName: 'Union Public Service Commission – Civil Services Exam',
    description: 'IAS, IPS, IFS, IRS and other Group A & B services',
    icon: Icons.account_balance_rounded,
    color: const Color(0xff8b5cf6),
    stages: [
      ExamStage(code: 'prelims', name: 'Prelims', papers: [
        Paper(code: 'GS-I', name: 'General Studies Paper I', subjects: [
          _upscHistory, _upscGeography, _upscPolity, _upscEconomy,
          _upscEnvironment, _upscScienceTech, _generalAwareness,
        ]),
        Paper(code: 'CSAT', name: 'CSAT (Qualifying)', subjects: [_upscCsat]),
      ]),
      ExamStage(code: 'mains', name: 'Mains', papers: [
        Paper(code: 'Essay', name: 'Essay', subjects: [
          Subject('Essay Writing', _ch([
            'Philosophical Topics', 'Current Issues', 'Social Issues',
            'Economic Topics', 'Political Topics', 'Quote-based Essays',
          ])),
        ]),
        Paper(code: 'GS-I', name: 'GS-I: Heritage, History, Geography, Society',
            subjects: [_upscHistory, _upscGeography]),
        Paper(code: 'GS-II', name: 'GS-II: Governance, Constitution, IR',
            subjects: [_upscPolity, Subject('International Relations', _ch([
              'India & Neighbours', 'Bilateral Relations',
              'India-USA', 'India-China', 'India-Russia', 'India-EU',
              'UN & Multilateral Bodies', 'Foreign Policy',
            ]))]),
        Paper(code: 'GS-III', name: 'GS-III: Economy, Environment, Sci-Tech, Security',
            subjects: [_upscEconomy, _upscEnvironment, _upscScienceTech,
              Subject('Internal Security', _ch([
                'Cyber Security', 'Money Laundering', 'Terrorism',
                'Border Management', 'Linkages with Organized Crime',
              ]))]),
        Paper(code: 'GS-IV', name: 'GS-IV: Ethics, Integrity & Aptitude',
            subjects: [_upscEthics]),
        Paper(code: 'Optional-I', name: 'Optional Subject Paper I', subjects: []),
        Paper(code: 'Optional-II', name: 'Optional Subject Paper II', subjects: []),
      ]),
      ExamStage(code: 'interview', name: 'Personality Test', papers: []),
    ],
  ),

  // SSC CGL
  Exam(
    id: 'ssc_cgl',
    shortName: 'SSC CGL',
    fullName: 'Staff Selection Commission – Combined Graduate Level',
    description: 'Group B & C posts in central government departments',
    icon: Icons.business_center_rounded,
    color: const Color(0xff6366f1),
    stages: [
      ExamStage(code: 'tier1', name: 'Tier 1', papers: [
        Paper(code: 'Tier-1', name: 'CBT (Qualifying)', subjects: [
          _quantSubject, _reasoningSubject, _englishSubject, _generalAwareness,
        ]),
      ]),
      ExamStage(code: 'tier2', name: 'Tier 2', papers: [
        Paper(code: 'Paper-I', name: 'Paper I (Merit)', subjects: [
          Subject('Mathematical Abilities', _quantSubject.chapters),
          _reasoningSubject, _englishSubject, _generalAwareness, _computerAwareness,
        ]),
        Paper(code: 'Paper-II', name: 'Paper II (JSO only)', subjects: [
          Subject('Statistics', _ch([
            'Collection & Classification of Data', 'Measures of Central Tendency',
            'Measures of Dispersion', 'Moments', 'Correlation & Regression',
            'Probability', 'Sampling Theory', 'Statistical Inference',
            'Analysis of Variance', 'Time Series', 'Index Numbers',
          ])),
        ]),
        Paper(code: 'Paper-III', name: 'Paper III (AAO only)', subjects: [
          Subject('Finance & Economics', _ch([
            'Fundamental Principles of Accounting', 'Financial Accounting',
            'Basic Concepts of Economics', 'Indian Economy', 'Money & Banking',
          ])),
        ]),
      ]),
    ],
  ),

  // SSC CHSL
  Exam(
    id: 'ssc_chsl',
    shortName: 'SSC CHSL',
    fullName: 'SSC – Combined Higher Secondary Level',
    description: 'LDC, DEO, Postal Assistant posts (12th pass)',
    icon: Icons.school_rounded,
    color: const Color(0xff06b6d4),
    stages: [
      ExamStage(code: 'tier1', name: 'Tier 1', papers: [
        Paper(code: 'Tier-1', name: 'CBT', subjects: [
          _quantSubject, _reasoningSubject, _englishSubject, _generalAwareness,
        ]),
      ]),
      ExamStage(code: 'tier2', name: 'Tier 2', papers: [
        Paper(code: 'Tier-2', name: 'Skill Test / Typing', subjects: []),
      ]),
    ],
  ),

  // SSC MTS
  Exam(
    id: 'ssc_mts',
    shortName: 'SSC MTS',
    fullName: 'SSC – Multi-Tasking Staff',
    description: 'Non-Gazetted, Non-Ministerial Group C posts',
    icon: Icons.work_history_rounded,
    color: const Color(0xff10b981),
    stages: [
      ExamStage(code: 'session1', name: 'Session I', papers: [
        Paper(code: 'Session-I', name: 'Numerical & Reasoning', subjects: [
          _quantSubject, _reasoningSubject,
        ]),
      ]),
      ExamStage(code: 'session2', name: 'Session II', papers: [
        Paper(code: 'Session-II', name: 'GA & English', subjects: [
          _generalAwareness, _englishSubject,
        ]),
      ]),
    ],
  ),

  // SSC CPO
  Exam(
    id: 'ssc_cpo',
    shortName: 'SSC CPO',
    fullName: 'SSC – Central Police Organisations',
    description: 'Sub-Inspector in Delhi Police, CAPF',
    icon: Icons.shield_rounded,
    color: const Color(0xffef4444),
    stages: [
      ExamStage(code: 'paper1', name: 'Paper I', papers: [
        Paper(code: 'Paper-I', name: 'CBT Paper I', subjects: [
          _reasoningSubject, _generalAwareness, _quantSubject, _englishSubject,
        ]),
      ]),
      ExamStage(code: 'paper2', name: 'Paper II', papers: [
        Paper(code: 'Paper-II', name: 'CBT Paper II (English Comprehension)', subjects: [
          _englishSubject,
        ]),
      ]),
    ],
  ),

  // IBPS PO
  Exam(
    id: 'ibps_po',
    shortName: 'IBPS PO',
    fullName: 'IBPS – Probationary Officer',
    description: 'PO in 11 public sector banks',
    icon: Icons.account_balance_wallet_rounded,
    color: const Color(0xfff59e0b),
    stages: [
      ExamStage(code: 'prelims', name: 'Prelims', papers: [
        Paper(code: 'Prelims', name: 'CBT Prelims', subjects: [
          _englishSubject, _quantSubject, _reasoningSubject,
        ]),
      ]),
      ExamStage(code: 'mains', name: 'Mains', papers: [
        Paper(code: 'Mains', name: 'CBT Mains', subjects: [
          Subject('Reasoning & Computer Aptitude',
              [..._reasoningSubject.chapters, ..._computerAwareness.chapters]),
          _dataInterpretation, _englishSubject, _bankingAwareness,
        ]),
        Paper(code: 'Descriptive', name: 'Descriptive English', subjects: [
          Subject('Descriptive Writing', _ch(['Essay', 'Letter Writing', 'Précis'])),
        ]),
      ]),
      ExamStage(code: 'interview', name: 'Interview', papers: []),
    ],
  ),

  // IBPS Clerk
  Exam(
    id: 'ibps_clerk',
    shortName: 'IBPS Clerk',
    fullName: 'IBPS – Clerical Cadre',
    description: 'Clerical posts in public sector banks',
    icon: Icons.point_of_sale_rounded,
    color: const Color(0xff8b5cf6),
    stages: [
      ExamStage(code: 'prelims', name: 'Prelims', papers: [
        Paper(code: 'Prelims', name: 'CBT Prelims', subjects: [
          _englishSubject, _quantSubject, _reasoningSubject,
        ]),
      ]),
      ExamStage(code: 'mains', name: 'Mains', papers: [
        Paper(code: 'Mains', name: 'CBT Mains', subjects: [
          _generalAwareness,
          Subject('General/Banking Awareness', _bankingAwareness.chapters),
          _englishSubject, _reasoningSubject, _computerAwareness, _quantSubject,
        ]),
      ]),
    ],
  ),

  // SBI PO
  Exam(
    id: 'sbi_po',
    shortName: 'SBI PO',
    fullName: 'State Bank of India – Probationary Officer',
    description: 'Officer-grade roles at SBI',
    icon: Icons.savings_rounded,
    color: const Color(0xff06b6d4),
    stages: [
      ExamStage(code: 'prelims', name: 'Prelims', papers: [
        Paper(code: 'Prelims', name: 'CBT Prelims', subjects: [
          _englishSubject, _quantSubject, _reasoningSubject,
        ]),
      ]),
      ExamStage(code: 'mains', name: 'Mains', papers: [
        Paper(code: 'Mains', name: 'CBT Mains', subjects: [
          Subject('Reasoning & Computer Aptitude',
              [..._reasoningSubject.chapters, ..._computerAwareness.chapters]),
          _dataInterpretation,
          Subject('General/Economy/Banking Awareness',
              [..._bankingAwareness.chapters, ..._generalAwareness.chapters]),
          _englishSubject,
        ]),
        Paper(code: 'Descriptive', name: 'Descriptive (Essay & Letter)', subjects: [
          Subject('Descriptive Writing', _ch(['Essay', 'Letter Writing'])),
        ]),
      ]),
      ExamStage(code: 'interview', name: 'Group Exercise + Interview', papers: []),
    ],
  ),

  // RRB NTPC
  Exam(
    id: 'rrb_ntpc',
    shortName: 'RRB NTPC',
    fullName: 'Railway – Non-Technical Popular Categories',
    description: 'Clerk, Goods Guard, Station Master and similar',
    icon: Icons.train_rounded,
    color: const Color(0xff10b981),
    stages: [
      ExamStage(code: 'cbt1', name: 'CBT 1', papers: [
        Paper(code: 'CBT-1', name: 'CBT Stage 1', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalAwareness,
        ]),
      ]),
      ExamStage(code: 'cbt2', name: 'CBT 2', papers: [
        Paper(code: 'CBT-2', name: 'CBT Stage 2 (Merit)', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalAwareness, _generalScience,
        ]),
      ]),
    ],
  ),

  // RRB Group D
  Exam(
    id: 'rrb_group_d',
    shortName: 'RRB Group D',
    fullName: 'Railway – Group D',
    description: 'Track maintainer, helper, porter, gangman',
    icon: Icons.handyman_rounded,
    color: const Color(0xfff59e0b),
    stages: [
      ExamStage(code: 'cbt', name: 'CBT', papers: [
        Paper(code: 'CBT', name: 'CBT Single Stage', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalScience, _generalAwareness,
        ]),
      ]),
    ],
  ),

  // RRB ALP
  Exam(
    id: 'rrb_alp',
    shortName: 'RRB ALP',
    fullName: 'Railway – Assistant Loco Pilot',
    description: 'Assistant Loco Pilot & Technician',
    icon: Icons.directions_railway_rounded,
    color: const Color(0xff6366f1),
    stages: [
      ExamStage(code: 'cbt1', name: 'CBT 1', papers: [
        Paper(code: 'CBT-1', name: 'CBT Stage 1', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalScience, _generalAwareness,
        ]),
      ]),
      ExamStage(code: 'cbt2', name: 'CBT 2', papers: [
        Paper(code: 'CBT-2-A', name: 'Part A', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalScience, _generalAwareness,
        ]),
        Paper(code: 'CBT-2-B', name: 'Part B (Trade)', subjects: []),
      ]),
      ExamStage(code: 'cbat', name: 'CBAT', papers: []),
    ],
  ),

  // RRB JE
  Exam(
    id: 'rrb_je',
    shortName: 'RRB JE',
    fullName: 'Railway – Junior Engineer',
    description: 'Junior Engineer technical posts',
    icon: Icons.engineering_rounded,
    color: const Color(0xff8b5cf6),
    stages: [
      ExamStage(code: 'cbt1', name: 'CBT 1', papers: [
        Paper(code: 'CBT-1', name: 'CBT Stage 1', subjects: [
          Subject('Mathematics', _quantSubject.chapters),
          _reasoningSubject, _generalScience, _generalAwareness,
        ]),
      ]),
      ExamStage(code: 'cbt2', name: 'CBT 2', papers: [
        Paper(code: 'CBT-2', name: 'CBT Stage 2 (Technical)', subjects: [
          _generalAwareness, _quantSubject,
          Subject('Technical Abilities (Engineering)', _ch([
            'Civil Engineering', 'Mechanical Engineering',
            'Electrical Engineering', 'Electronics Engineering',
            'Computer Science', 'IT Engineering',
          ])),
        ]),
      ]),
    ],
  ),

  // State PCS (generic)
  Exam(
    id: 'state_pcs',
    shortName: 'State PCS',
    fullName: 'State Public Service Commission',
    description: 'State-level civil service exams (UPPSC, BPSC, MPSC etc.)',
    icon: Icons.map_rounded,
    color: const Color(0xffef4444),
    stages: [
      ExamStage(code: 'prelims', name: 'Prelims', papers: [
        Paper(code: 'GS', name: 'General Studies', subjects: [
          _upscHistory, _upscGeography, _upscPolity, _upscEconomy,
          _generalAwareness, Subject('State-specific GK', _ch([
            'State History', 'State Geography', 'State Polity',
            'State Economy', 'State Current Affairs',
          ])),
        ]),
        Paper(code: 'CSAT', name: 'CSAT', subjects: [_upscCsat]),
      ]),
      ExamStage(code: 'mains', name: 'Mains', papers: [
        Paper(code: 'GS-I', name: 'General Studies I', subjects: [_upscHistory, _upscGeography]),
        Paper(code: 'GS-II', name: 'General Studies II', subjects: [_upscPolity]),
        Paper(code: 'GS-III', name: 'General Studies III', subjects: [_upscEconomy, _upscScienceTech]),
        Paper(code: 'GS-IV', name: 'General Studies IV', subjects: [_upscEthics]),
        Paper(code: 'Optional', name: 'Optional Subject', subjects: []),
      ]),
      ExamStage(code: 'interview', name: 'Interview', papers: []),
    ],
  ),
];

// ── Helpers ────────────────────────────────────────────────────────────────
Exam? findExam(String id) {
  for (final e in kAllExams) {
    if (e.id == id) return e;
  }
  return null;
}

List<Subject> subjectsFor(String examId, {String? stageCode, String? paperCode}) {
  final exam = findExam(examId);
  if (exam == null) return [];
  final stages = stageCode == null ? exam.stages : exam.stages.where((s) => s.code == stageCode);
  final out = <Subject>[];
  final seen = <String>{};
  for (final s in stages) {
    final papers = paperCode == null ? s.papers : s.papers.where((p) => p.code == paperCode);
    for (final p in papers) {
      for (final sub in p.subjects) {
        if (seen.add(sub.name)) out.add(sub);
      }
    }
  }
  return out;
}
