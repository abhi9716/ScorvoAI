import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/data/exam_taxonomy.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/screens/quiz_play_screen.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/theme/app_theme.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  UserProfile? _profile;
  Map<String, dynamic>? _insights;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        FirestoreService.getProfile(uid),
        FirestoreService.getInsights(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _insights = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Quiz Arena')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _heroBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  _adaptiveCard(),
                  const SizedBox(height: AppSpacing.md),
                  _quickQuizRow(),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Custom Quiz', style: AppText.h2),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Pick exact exam stage, paper, subject and chapter to target your prep.',
                      style: AppText.bodyDim),
                  const SizedBox(height: AppSpacing.md),
                  _customQuizCard(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  Widget _heroBanner() {
    final total = _insights?['total_quizzes'] as int? ?? 0;
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final streak = _insights?['streak'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecor.hero(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('TODAY\'S CHALLENGE',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Practice makes\nperfect',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroStat('$streak', 'streak'),
              const SizedBox(width: 16),
              _heroStat('$total', 'attempted'),
              const SizedBox(width: 16),
              _heroStat('${avg.toStringAsFixed(0)}%', 'avg'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String v, String l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _adaptiveCard() {
    final weak = List<Map<String, dynamic>>.from(_insights?['weak_topics'] as List? ?? []);
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final hasData = weak.isNotEmpty || (_insights?['total_quizzes'] as int? ?? 0) > 0;
    final difficulty = avg >= 75
        ? 'hard'
        : avg >= 50
            ? 'medium'
            : 'easy';
    final color = hasData ? AppColors.success : AppColors.indigoBright;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.auto_fix_high_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Smart Practice', style: AppText.h2),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: AppDecor.chip(color),
                child: Text('AI-PICKED',
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasData
                ? 'We\'ll focus on your weak chapters at ${difficulty.toUpperCase()} difficulty.'
                : 'A balanced 5-question warm-up to get started.',
            style: AppText.bodyDim,
          ),
          if (weak.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: weak.take(4).map((t) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: AppDecor.chip(AppColors.danger),
                  child: Text(t['topic'] as String? ?? '',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startAdaptive(weak, difficulty),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start Adaptive Quiz'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickQuizRow() {
    final counts = [5, 10, 15, 20];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.indigo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.flash_on_rounded, color: AppColors.indigoBright, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Quick Mix', style: AppText.h3),
              const Spacer(),
              const Text('Random questions', style: AppText.captionDim),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: counts.map((c) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == counts.last ? 0 : 6),
                  child: OutlinedButton(
                    onPressed: () => _startMixed(c),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppColors.surfaceLine),
                      backgroundColor: AppColors.surfaceHigh,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$c',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
                        const Text('questions',
                            style: TextStyle(fontSize: 9.5, color: AppColors.textTertiary, height: 1.1)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _customQuizCard() {
    final exam = _profile != null ? findExam(_profile!.exam) : null;
    return InkWell(
      onTap: () => _showCustomPicker(),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecor.card(),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.tune_rounded, color: AppColors.violet, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Build Your Own Quiz', style: AppText.h3),
                  const SizedBox(height: 4),
                  Text(
                    exam == null
                        ? 'Pick stage, paper, subject & chapter'
                        : '${exam.shortName} • ${exam.stages.length} stage${exam.stages.length == 1 ? '' : 's'}',
                    style: AppText.captionDim,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────
  void _startMixed(int count) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QuizPlayScreen(mode: QuizMode.mixed, count: count),
    )).then((_) => _load());
  }

  void _startAdaptive(List<Map<String, dynamic>> weak, String difficulty) {
    final topics = weak.map((t) => t['topic'] as String? ?? '').where((t) => t.isNotEmpty).take(3).toList();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QuizPlayScreen(
        mode: topics.isEmpty ? QuizMode.mixed : QuizMode.custom,
        subjects: topics.isEmpty ? null : topics,
        count: 5,
        difficulty: difficulty,
      ),
    )).then((_) => _load());
  }

  void _showCustomPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CustomQuizSheet(profile: _profile, onStart: (subjects, chapters, difficulty, count) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => QuizPlayScreen(
            mode: QuizMode.custom,
            subjects: subjects,
            chapters: chapters,
            difficulty: difficulty,
            count: count,
          ),
        )).then((_) => _load());
      }),
    );
  }
}

// ── Custom Quiz Bottom Sheet ───────────────────────────────────────────────
class _CustomQuizSheet extends StatefulWidget {
  final UserProfile? profile;
  final void Function(List<String> subjects, List<String> chapters, String difficulty, int count) onStart;
  const _CustomQuizSheet({required this.profile, required this.onStart});

  @override
  State<_CustomQuizSheet> createState() => _CustomQuizSheetState();
}

class _CustomQuizSheetState extends State<_CustomQuizSheet> {
  Exam? _exam;
  ExamStage? _stage;
  Paper? _paper;
  final Set<String> _subjects = {};
  final Set<String> _chapters = {};
  String _difficulty = 'mixed';
  int _count = 10;

  @override
  void initState() {
    super.initState();
    _exam = widget.profile != null ? findExam(widget.profile!.exam) : kAllExams.first;
    _stage = _exam?.stages.isNotEmpty == true ? _exam!.stages.first : null;
    _paper = _stage?.papers.isNotEmpty == true ? _stage!.papers.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final availableSubjects = _paper?.subjects ?? <Subject>[];
    final selectedSubject = availableSubjects.where((s) => _subjects.contains(s.name)).toList();
    final availableChapters = selectedSubject.expand((s) => s.chapters.map((c) => c.name)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(color: AppColors.surfaceLine, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Build Quiz', style: AppText.h2),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _pickerCard('Exam', _exam?.shortName ?? '—', Icons.school_rounded, AppColors.indigoBright,
                    () => _showPicker<Exam>(kAllExams, (e) => e.shortName, (v) => setState(() {
                          _exam = v;
                          _stage = v.stages.isNotEmpty ? v.stages.first : null;
                          _paper = _stage?.papers.isNotEmpty == true ? _stage!.papers.first : null;
                          _subjects.clear();
                          _chapters.clear();
                        }))),
                if (_exam != null && _exam!.stages.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _pickerCard('Stage', _stage?.name ?? '—', Icons.layers_rounded, AppColors.violet,
                      () => _showPicker<ExamStage>(_exam!.stages, (s) => s.name, (v) => setState(() {
                            _stage = v;
                            _paper = v.papers.isNotEmpty ? v.papers.first : null;
                            _subjects.clear();
                            _chapters.clear();
                          }))),
                ],
                if (_stage != null && _stage!.papers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _pickerCard('Paper', _paper?.name ?? '—', Icons.description_rounded, AppColors.info,
                      () => _showPicker<Paper>(_stage!.papers, (p) => p.name, (v) => setState(() {
                            _paper = v;
                            _subjects.clear();
                            _chapters.clear();
                          }))),
                ],
                const SizedBox(height: 16),
                _multiSelectSection(
                  'Subjects',
                  availableSubjects.map((s) => s.name).toList(),
                  _subjects,
                  AppColors.success,
                ),
                if (availableChapters.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _multiSelectSection(
                    'Chapters (optional)',
                    availableChapters,
                    _chapters,
                    AppColors.warning,
                  ),
                ],
                const SizedBox(height: 16),
                _difficultyRow(),
                const SizedBox(height: 16),
                _countRow(),
                const SizedBox(height: 24),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _subjects.isEmpty ? null : () => widget.onStart(
                        _subjects.toList(),
                        _chapters.toList(),
                        _difficulty,
                        _count,
                      ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Start Quiz • $_count questions'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppDecor.card(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(label, style: AppText.caption),
            const Spacer(),
            Flexible(child: Text(value, style: AppText.h3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end)),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _multiSelectSection(String label, List<String> options, Set<String> selected, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: AppText.h3),
            const Spacer(),
            if (selected.isNotEmpty)
              TextButton(
                onPressed: () => setState(selected.clear),
                child: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (v) => setState(() => v ? selected.add(opt) : selected.remove(opt)),
              backgroundColor: AppColors.surfaceHigh,
              selectedColor: color.withValues(alpha: 0.2),
              checkmarkColor: color,
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? color : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(color: isSelected ? color : AppColors.surfaceLine, width: 0.5),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _difficultyRow() {
    const opts = ['easy', 'medium', 'hard', 'mixed'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Difficulty', style: AppText.h3),
        const SizedBox(height: 6),
        Row(
          children: opts.map((d) {
            final color = switch (d) {
              'easy' => AppColors.easy,
              'medium' => AppColors.medium,
              'hard' => AppColors.hard,
              _ => AppColors.mixed,
            };
            final isSel = _difficulty == d;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: d == 'mixed' ? 0 : 4),
                child: OutlinedButton(
                  onPressed: () => setState(() => _difficulty = d),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isSel ? color.withValues(alpha: 0.15) : AppColors.surfaceHigh,
                    side: BorderSide(color: isSel ? color : AppColors.surfaceLine, width: isSel ? 1.5 : 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(d[0].toUpperCase() + d.substring(1),
                      style: TextStyle(fontSize: 12, color: isSel ? color : AppColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _countRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Number of questions', style: AppText.h3),
            const Spacer(),
            Text('$_count', style: const TextStyle(color: AppColors.indigoBright, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.indigo,
            inactiveTrackColor: AppColors.surfaceHigh,
            thumbColor: AppColors.indigoBright,
            overlayColor: AppColors.indigo.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            min: 5,
            max: 30,
            divisions: 25,
            value: _count.toDouble(),
            label: '$_count',
            onChanged: (v) => setState(() => _count = v.round()),
          ),
        ),
      ],
    );
  }

  void _showPicker<T>(List<T> items, String Function(T) label, void Function(T) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => ListTile(
            title: Text(label(items[i]), style: AppText.h3),
            onTap: () {
              Navigator.pop(context);
              onSelect(items[i]);
            },
          ),
        ),
      ),
    );
  }
}
