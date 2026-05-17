import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scorvoai/data/exam_taxonomy.dart';
import 'package:scorvoai/services/api.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/theme/app_theme.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  UserProfile? _profile;
  Exam? _exam;
  ExamStage? _stage;
  Paper? _paper;
  Subject? _subject;
  String _difficulty = 'medium';
  String _query = '';
  List<Map<String, dynamic>> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        FirestoreService.getProfile(uid),
        FirestoreService.getRecentLessons(uid, limit: 5),
      ]);
      if (!mounted) return;
      final profile = results[0] as UserProfile?;
      final recent = results[1] as List<Map<String, dynamic>>;
      final exam = profile != null ? findExam(profile.exam) : kAllExams.first;
      setState(() {
        _profile = profile;
        _exam = exam ?? kAllExams.first;
        _stage = _exam!.stages.isNotEmpty ? _exam!.stages.first : null;
        _paper = (_stage?.papers.isNotEmpty ?? false) ? _stage!.papers.first : null;
        _subject = (_paper?.subjects.isNotEmpty ?? false) ? _paper!.subjects.first : null;
        _recent = recent;
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
      appBar: AppBar(
        title: const Text('Learn'),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: AppColors.indigoBright),
            tooltip: 'Recent lessons',
            onPressed: _recent.isEmpty ? null : _showRecentSheet,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroBanner(),
                  const SizedBox(height: AppSpacing.lg),
                  _examPickerCard(),
                  const SizedBox(height: AppSpacing.md),
                  _searchField(),
                  const SizedBox(height: AppSpacing.lg),
                  _sectionLabel('Pick a chapter'),
                  const SizedBox(height: AppSpacing.sm),
                  if (_subject != null) _chapterGrid(_subject!),
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _sectionLabel('Continue learning'),
                    const SizedBox(height: AppSpacing.sm),
                    ..._recent.map(_recentTile),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
    );
  }

  Widget _heroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecor.hero(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('AI Micro-Lessons',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Master any chapter\nin 3 minutes',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 6),
          const Text('Focused concepts, worked examples, tips & tricks — tailored to your exam.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _examPickerCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppDecor.card(),
      child: Column(
        children: [
          _dropdownRow(
            'Exam',
            _exam?.shortName ?? 'Select',
            Icons.school_rounded,
            _exam?.color ?? AppColors.indigo,
            () => _pickExam(),
          ),
          if (_exam != null && _exam!.stages.length > 1) ...[
            const Divider(),
            _dropdownRow(
              'Stage',
              _stage?.name ?? 'Select',
              Icons.layers_rounded,
              AppColors.violet,
              () => _pickStage(),
            ),
          ],
          if (_stage != null && _stage!.papers.length > 1) ...[
            const Divider(),
            _dropdownRow(
              'Paper',
              _paper?.name ?? 'Select',
              Icons.description_rounded,
              AppColors.info,
              () => _pickPaper(),
            ),
          ],
          if (_paper != null && _paper!.subjects.length > 1) ...[
            const Divider(),
            _dropdownRow(
              'Subject',
              _subject?.name ?? 'Select',
              Icons.menu_book_rounded,
              AppColors.success,
              () => _pickSubject(),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _diffColor(_difficulty).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.signal_cellular_alt_rounded, color: _diffColor(_difficulty), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Difficulty', style: AppText.caption)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['easy', 'medium', 'hard'].map((d) {
                    final selected = _difficulty == d;
                    final color = _diffColor(d);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: d == 'hard' ? 0 : 6),
                        child: InkWell(
                          onTap: () => setState(() => _difficulty = d),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected ? color.withValues(alpha: 0.18) : AppColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? color : AppColors.surfaceLine,
                                width: selected ? 1.2 : 0.5,
                              ),
                            ),
                            child: Text(
                              d[0].toUpperCase() + d.substring(1),
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? color : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
            Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search chapters...',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: AppText.h3);
  }

  Widget _chapterGrid(Subject subject) {
    final filtered = _query.isEmpty
        ? subject.chapters
        : subject.chapters.where((c) => c.name.toLowerCase().contains(_query)).toList();
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: AppDecor.card(),
        child: Center(child: Text('No chapters match', style: AppText.bodyDim)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filtered.map((c) => _chapterChip(subject.name, c.name)).toList(),
    );
  }

  Widget _chapterChip(String subjectName, String chapterName) {
    return InkWell(
      onTap: () => _openLesson(subjectName, chapterName),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppDecor.card(),
        constraints: const BoxConstraints(minWidth: 130),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: AppColors.indigoBright, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(chapterName,
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
            const SizedBox(width: 4),
            Icon(Icons.auto_awesome_rounded, color: AppColors.indigoBright, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _recentTile(Map<String, dynamic> lesson) {
    final subject = lesson['subject'] as String? ?? '';
    final chapter = lesson['chapter'] as String? ?? '';
    final diff = lesson['difficulty'] as String? ?? 'medium';
    final views = lesson['view_count'] as int? ?? 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openLesson(subject, chapter, difficulty: diff),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: AppDecor.card(),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: _diffColor(diff).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book_rounded, color: _diffColor(diff), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chapter, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$subject • $views ${views == 1 ? 'view' : 'views'}', style: AppText.captionDim),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Color _diffColor(String d) => switch (d.toLowerCase()) {
        'easy' => AppColors.easy,
        'medium' => AppColors.medium,
        'hard' => AppColors.hard,
        _ => AppColors.mixed,
      };

  // ── Pickers ─────────────────────────────────────────────────────────────
  Future<void> _pickExam() async {
    final result = await showModalBottomSheet<Exam>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ListPicker<Exam>(
        title: 'Select Exam',
        items: kAllExams,
        labelOf: (e) => e.shortName,
        subtitleOf: (e) => e.description,
        iconOf: (e) => Icon(e.icon, color: e.color, size: 22),
      ),
    );
    if (result != null) {
      setState(() {
        _exam = result;
        _stage = result.stages.isNotEmpty ? result.stages.first : null;
        _paper = (_stage?.papers.isNotEmpty ?? false) ? _stage!.papers.first : null;
        _subject = (_paper?.subjects.isNotEmpty ?? false) ? _paper!.subjects.first : null;
      });
    }
  }

  Future<void> _pickStage() async {
    if (_exam == null) return;
    final stages = _exam!.stages.where((s) => s.papers.isNotEmpty).toList();
    final result = await showModalBottomSheet<ExamStage>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ListPicker<ExamStage>(
        title: 'Select Stage',
        items: stages,
        labelOf: (s) => s.name,
        subtitleOf: (s) => '${s.papers.length} paper${s.papers.length == 1 ? '' : 's'}',
        iconOf: (s) => Icon(Icons.layers_rounded, color: AppColors.violet, size: 22),
      ),
    );
    if (result != null) {
      setState(() {
        _stage = result;
        _paper = result.papers.isNotEmpty ? result.papers.first : null;
        _subject = (_paper?.subjects.isNotEmpty ?? false) ? _paper!.subjects.first : null;
      });
    }
  }

  Future<void> _pickPaper() async {
    if (_stage == null) return;
    final papers = _stage!.papers.where((p) => p.subjects.isNotEmpty).toList();
    final result = await showModalBottomSheet<Paper>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ListPicker<Paper>(
        title: 'Select Paper',
        items: papers,
        labelOf: (p) => p.name,
        subtitleOf: (p) => '${p.subjects.length} subject${p.subjects.length == 1 ? '' : 's'}',
        iconOf: (p) => Icon(Icons.description_rounded, color: AppColors.info, size: 22),
      ),
    );
    if (result != null) {
      setState(() {
        _paper = result;
        _subject = result.subjects.isNotEmpty ? result.subjects.first : null;
      });
    }
  }

  Future<void> _pickSubject() async {
    if (_paper == null) return;
    final result = await showModalBottomSheet<Subject>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ListPicker<Subject>(
        title: 'Select Subject',
        items: _paper!.subjects,
        labelOf: (s) => s.name,
        subtitleOf: (s) => '${s.chapters.length} chapters',
        iconOf: (s) => Icon(Icons.menu_book_rounded, color: AppColors.success, size: 22),
      ),
    );
    if (result != null) setState(() => _subject = result);
  }

  void _showRecentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: [
          Text('Recent lessons', style: AppText.h2),
          const SizedBox(height: 12),
          ..._recent.map(_recentTile),
        ],
      ),
    );
  }

  void _openLesson(String subjectName, String chapterName, {String? difficulty}) {
    final diff = difficulty ?? _difficulty;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          subject: subjectName,
          chapter: chapterName,
          difficulty: diff,
          exam: _exam?.shortName ?? '',
        ),
      ),
    ).then((_) => _loadInitial());
  }
}

// ── Lesson Detail Screen ───────────────────────────────────────────────────
class LessonScreen extends StatefulWidget {
  final String subject;
  final String chapter;
  final String difficulty;
  final String exam;
  const LessonScreen({
    super.key,
    required this.subject,
    required this.chapter,
    this.difficulty = 'medium',
    this.exam = '',
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  String _content = '';
  bool _loading = true;
  bool _isCached = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _content = '';
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (!forceRefresh) {
        final cached = await FirestoreService.getCachedLesson(
          subject: widget.subject,
          chapter: widget.chapter,
          difficulty: widget.difficulty,
        );
        if (cached != null && (cached['content'] as String?)?.isNotEmpty == true) {
          setState(() {
            _content = cached['content'] as String;
            _isCached = true;
            _loading = false;
          });
          if (uid != null) {
            FirestoreService.recordLessonView(
              uid: uid,
              subject: widget.subject,
              chapter: widget.chapter,
              difficulty: widget.difficulty,
            ).ignore();
          }
          return;
        }
      }
      // Stream from backend
      setState(() => _isCached = false);
      final stream = ApiService.generateLessonStream(
        subject: widget.subject,
        chapter: widget.chapter,
        difficulty: widget.difficulty,
        exam: widget.exam,
      );
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          _content += chunk;
          _loading = false;
        });
      }
      // Cache + record
      if (_content.trim().isNotEmpty) {
        FirestoreService.cacheLesson(
          subject: widget.subject,
          chapter: widget.chapter,
          difficulty: widget.difficulty,
          content: _content,
          exam: widget.exam,
        ).ignore();
        if (uid != null) {
          FirestoreService.recordLessonView(
            uid: uid,
            subject: widget.subject,
            chapter: widget.chapter,
            difficulty: widget.difficulty,
          ).ignore();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveAsNote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _content.isEmpty) return;
    try {
      await FirestoreService.saveAiNote(
        uid: uid,
        title: '${widget.chapter} — Lesson',
        content: _content,
        source: 'lesson',
        subject: widget.subject,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Notes')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Color _diffColor() => switch (widget.difficulty.toLowerCase()) {
        'easy' => AppColors.easy,
        'medium' => AppColors.medium,
        'hard' => AppColors.hard,
        _ => AppColors.mixed,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.chapter, overflow: TextOverflow.ellipsis),
        actions: [
          if (_content.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.bookmark_add_outlined, color: AppColors.indigoBright),
              tooltip: 'Save as note',
              onPressed: _saveAsNote,
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.indigoBright),
              tooltip: 'Regenerate',
              onPressed: () => _load(forceRefresh: true),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _badge(widget.subject, AppColors.indigoBright),
                _badge(widget.difficulty.toUpperCase(), _diffColor()),
                if (_isCached) _badge('CACHED', AppColors.success),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading && _content.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text('Crafting your lesson...', style: AppText.bodyDim),
                      const SizedBox(height: 4),
                      Text('Subject: ${widget.subject}', style: AppText.captionDim),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecor.card(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Could not load lesson', style: AppText.h3),
                    const SizedBox(height: 6),
                    Text(_error ?? '', style: AppText.captionDim),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _load(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: AppDecor.card(),
                child: GptMarkdown(
                  _content,
                  style: AppText.body,
                  useDollarSignsForLatex: false,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: AppDecor.chip(color),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
    );
  }
}

// ── Reusable list picker ───────────────────────────────────────────────────
class _ListPicker<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final Widget Function(T)? iconOf;
  const _ListPicker({
    required this.title,
    required this.items,
    required this.labelOf,
    this.subtitleOf,
    this.iconOf,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.surfaceLine, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(title, style: AppText.h2),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => Navigator.pop(context, items[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        if (iconOf != null) ...[iconOf!(items[i]), const SizedBox(width: 12)],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(labelOf(items[i]), style: AppText.h3),
                              if (subtitleOf != null) ...[
                                const SizedBox(height: 2),
                                Text(subtitleOf!(items[i]), style: AppText.captionDim),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
