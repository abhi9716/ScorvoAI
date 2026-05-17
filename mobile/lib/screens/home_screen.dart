import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:scorvoai/data/exam_taxonomy.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/screens/chat_screen.dart';
import 'package:scorvoai/screens/learn_screen.dart';
import 'package:scorvoai/screens/profile_screen.dart';
import 'package:scorvoai/screens/quiz_play_screen.dart';
import 'package:scorvoai/screens/solver_screen.dart';
import 'package:scorvoai/services/api.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/theme/app_theme.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  Map<String, dynamic>? _insights;
  Map<String, dynamic>? _dailyLesson;
  List<Map<String, dynamic>> _currentAffairs = [];
  bool _loading = true;
  bool _generatingLesson = false;
  bool _loadingAffairs = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait([
        FirestoreService.getProfile(uid),
        FirestoreService.getInsights(uid),
        FirestoreService.getTodayDailyLesson(uid),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfile?;
        _insights = results[1] as Map<String, dynamic>?;
        _dailyLesson = results[2] as Map<String, dynamic>?;
        _loading = false;
      });
      // Background-generate daily lesson if missing
      if (_dailyLesson == null && _profile != null) _generateDailyLesson();
      // Always fetch fresh current affairs (backend has its own 1h cache).
      _fetchCurrentAffairs();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generateDailyLesson() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _profile == null || _generatingLesson) return;
    setState(() => _generatingLesson = true);

    // Pick a subject/chapter: weak topic first, else default
    final weak = List<Map<String, dynamic>>.from(_insights?['weak_topics'] as List? ?? []);
    String subject = 'General Studies';
    String chapter = 'Daily Quick Tip';
    if (weak.isNotEmpty) {
      subject = weak.first['topic'] as String? ?? subject;
    } else {
      final exam = findExam(_profile!.exam);
      if (exam != null && exam.allSubjects.isNotEmpty) {
        subject = exam.allSubjects.first.name;
        if (exam.allSubjects.first.chapters.isNotEmpty) {
          chapter = exam.allSubjects.first.chapters.first.name;
        }
      }
    }

    try {
      // Try cached shared lesson first
      var cached = await FirestoreService.getCachedLesson(
        subject: subject,
        chapter: chapter,
        difficulty: 'medium',
      );
      String content;
      if (cached != null && (cached['content'] as String?)?.isNotEmpty == true) {
        content = cached['content'] as String;
      } else {
        final res = await ApiService.generateLesson(
          subject: subject,
          chapter: chapter,
          difficulty: 'medium',
          exam: _profile!.examLabel,
        );
        content = res['content'] as String? ?? '';
        if (content.isNotEmpty) {
          FirestoreService.cacheLesson(
            subject: subject, chapter: chapter, difficulty: 'medium',
            content: content, exam: _profile!.examLabel,
          ).ignore();
        }
      }
      if (content.isEmpty) return;
      await FirestoreService.saveTodayDailyLesson(
        uid: uid, subject: subject, chapter: chapter, difficulty: 'medium', content: content,
      );
      if (!mounted) return;
      setState(() => _dailyLesson = {
            'subject': subject, 'chapter': chapter, 'difficulty': 'medium', 'content': content,
          });
    } catch (_) {} finally {
      if (mounted) setState(() => _generatingLesson = false);
    }
  }

  Future<void> _fetchCurrentAffairs() async {
    if (_loadingAffairs) return;
    setState(() => _loadingAffairs = true);
    try {
      final items = await ApiService.getCurrentAffairs(count: 5);
      if (items.isNotEmpty) {
        FirestoreService.saveTodayCurrentAffairs(items).ignore();
      }
      if (!mounted) return;
      setState(() => _currentAffairs = items);
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingAffairs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('ScorvoAI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_rounded, color: AppColors.indigoBright),
            tooltip: 'Ask AI Tutor',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => _loadAll()),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _avatar(radius: 18),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _greetingCard(),
                  const SizedBox(height: AppSpacing.lg),
                  _statsStrip(),
                  const SizedBox(height: AppSpacing.lg),
                  _dailyLessonSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _currentAffairsSection(),
                  const SizedBox(height: AppSpacing.lg),
                  _quickActionsSection(),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
      ),
    );
  }

  Widget _greetingCard() {
    final name = _profile?.firstName ?? 'there';
    final examLabel = _profile?.examLabel ?? 'Government Exams';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecor.hero(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting,',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(examLabel,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              _avatar(radius: 24, ring: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsStrip() {
    final total = _insights?['total_quizzes'] as int? ?? 0;
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final streak = _insights?['streak'] as int? ?? 0;

    return Row(
      children: [
        Expanded(child: _stat('🔥', '$streak', 'Streak', AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _stat('📝', '$total', 'Quizzes', AppColors.indigoBright)),
        const SizedBox(width: 10),
        Expanded(child: _stat('📊', '${avg.toStringAsFixed(0)}%', 'Average', AppColors.success)),
      ],
    );
  }

  Widget _stat(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppDecor.card(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18, height: 1.1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: AppText.captionDim),
        ],
      ),
    );
  }

  Widget _dailyLessonSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.indigoBright.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.menu_book_rounded, color: AppColors.indigoBright, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Lesson of the Day', style: AppText.h2),
              const Spacer(),
              if (_generatingLesson)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          if (_dailyLesson != null) _dailyLessonContent() else _dailyLessonSkeleton(),
        ],
      ),
    );
  }

  Widget _dailyLessonContent() {
    final subject = _dailyLesson!['subject'] as String? ?? '';
    final chapter = _dailyLesson!['chapter'] as String? ?? '';
    final content = _dailyLesson!['content'] as String? ?? '';
    // First ~600 chars as preview
    final preview = content.length > 600 ? '${content.substring(0, 600)}...' : content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: AppDecor.chip(AppColors.indigoBright),
              child: Text(subject,
                  style: TextStyle(fontSize: 10, color: AppColors.indigoBright, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: AppDecor.chip(AppColors.violet),
              child: Text(chapter,
                  style: TextStyle(fontSize: 10, color: AppColors.violet, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GptMarkdown(preview, style: AppText.body, useDollarSignsForLatex: false),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LessonScreen(
                    subject: subject,
                    chapter: chapter,
                    difficulty: _dailyLesson!['difficulty'] as String? ?? 'medium',
                    exam: _profile?.examLabel ?? '',
                  ),
                ),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Read full lesson'),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 18, color: AppColors.textTertiary),
              tooltip: 'New lesson',
              onPressed: _generatingLesson ? null : _generateDailyLesson,
            ),
          ],
        ),
      ],
    );
  }

  Widget _dailyLessonSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_generatingLesson)
          Text('Crafting today\'s lesson based on your weak areas...', style: AppText.bodyDim)
        else
          Text('Tap Generate to get your daily 3-minute lesson.', style: AppText.bodyDim),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _generatingLesson ? null : _generateDailyLesson,
          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
          label: Text(_generatingLesson ? 'Generating...' : 'Generate Today\'s Lesson'),
        ),
      ],
    );
  }

  Widget _currentAffairsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.newspaper_rounded, color: AppColors.info, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Top News Today', style: AppText.h2),
              const Spacer(),
              if (_loadingAffairs)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 18, color: AppColors.textTertiary),
                  tooltip: 'Refresh',
                  onPressed: _fetchCurrentAffairs,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_currentAffairs.isEmpty && !_loadingAffairs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed: _fetchCurrentAffairs,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Fetch today\'s news'),
              ),
            )
          else
            ..._currentAffairs.map(_affairItem),
        ],
      ),
    );
  }

  Widget _affairItem(Map<String, dynamic> item) {
    final headline = item['headline'] as String? ?? '';
    final summary = item['summary'] as String? ?? '';
    final category = item['category'] as String? ?? 'General';
    final exam = item['exam_angle'] as String? ?? '';
    final sourceUrl = item['source_url'] as String? ?? '';
    final hasSource = sourceUrl.isNotEmpty && sourceUrl.startsWith('http');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasSource ? () => launchUrlString(sourceUrl) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border(left: BorderSide(color: _categoryColor(category), width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: AppDecor.chip(_categoryColor(category)),
                    child: Text(category.toUpperCase(),
                        style: TextStyle(
                            fontSize: 9, color: _categoryColor(category),
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(headline, style: AppText.h3),
              const SizedBox(height: 4),
              Text(summary, style: AppText.bodyDim, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (exam.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.school_rounded, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(exam, style: AppText.captionDim, maxLines: 2)),
                ]),
              ],
              if (hasSource) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.indigoBright),
                    const SizedBox(width: 4),
                    Text('Read full article',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.indigoBright,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        Uri.tryParse(sourceUrl)?.host ?? '',
                        style: AppText.captionDim,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String c) => switch (c.toLowerCase()) {
        'polity' => AppColors.indigoBright,
        'economy' => AppColors.success,
        'sci-tech' || 'science' => AppColors.info,
        'international' => AppColors.violet,
        'environment' => const Color(0xff14b8a6),
        'defence' => AppColors.danger,
        'sports' => AppColors.warning,
        'awards' => const Color(0xfff97316),
        _ => AppColors.textSecondary,
      };

  Widget _quickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Tools', style: AppText.h2),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: _actionCard(
              icon: Icons.smart_toy_rounded,
              title: 'AI Tutor',
              sub: 'Ask anything',
              color: AppColors.indigoBright,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
            )),
            const SizedBox(width: 10),
            Expanded(child: _actionCard(
              icon: Icons.calculate_rounded,
              title: 'Solver',
              sub: 'Step-by-step',
              color: AppColors.success,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SolverScreen())),
            )),
          ],
        ),
        const SizedBox(height: 10),
        _actionCard(
          icon: Icons.play_circle_rounded,
          title: 'Quick 5-Question Quiz',
          sub: 'Random mix from your weak areas',
          color: AppColors.warning,
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const QuizPlayScreen(mode: QuizMode.mixed, count: 5),
          )),
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String sub,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: AppDecor.card(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub, style: AppText.captionDim, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (fullWidth) Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _avatar({double radius = 22, bool ring = false}) {
    final p = _profile;
    if (p == null || _loading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceHigh,
        child: Icon(Icons.person_rounded, color: AppColors.indigoBright, size: 18),
      );
    }
    Widget inner;
    if (p.photoUrl.isNotEmpty) {
      inner = CircleAvatar(radius: radius, backgroundImage: NetworkImage(p.photoUrl), onBackgroundImageError: (_, __) {});
    } else {
      final initials = p.name.isNotEmpty
          ? p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
          : '?';
      inner = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.indigoDark,
        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      );
    }
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
      ),
      child: inner,
    );
  }
}
