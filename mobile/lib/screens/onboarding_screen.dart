import 'package:flutter/material.dart';
import 'package:scorvoai/data/exam_taxonomy.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/screens/main_shell.dart';
import 'package:scorvoai/services/auth_service.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  String _selectedExamId = '';
  String _selectedStage = '';
  final List<String> _selectedGoals = [];
  bool _signingIn = false;

  static const _goals = [
    ('Speed & Accuracy', Icons.speed_rounded),
    ('Concept Clarity', Icons.lightbulb_rounded),
    ('Daily Practice', Icons.calendar_today_rounded),
    ('Mock Tests', Icons.quiz_rounded),
    ('Weak Topic Focus', Icons.trending_up_rounded),
    ('Previous Year Papers', Icons.history_rounded),
  ];

  Exam? get _exam => findExam(_selectedExamId);

  void _next() {
    if (_page < 3) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_page > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in cancelled')));
        return;
      }
      final profile = UserProfile(
        uid: user.uid,
        name: user.displayName ?? '',
        email: user.email ?? '',
        photoUrl: user.photoURL ?? '',
        exam: _selectedExamId,
        goals: _selectedGoals,
        createdAt: DateTime.now(),
        onboardingComplete: true,
      );
      await FirestoreService.saveProfile(profile);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _stepBar(),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _page = p),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _examPage(),
                  _stagePage(),
                  _goalsPage(),
                  _signInPage(),
                ],
              ),
            ),
            _navButtons(),
          ],
        ),
      ),
    );
  }

  Widget _stepBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: List.generate(4, (i) {
          final active = i <= _page;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                decoration: BoxDecoration(
                  color: active ? AppColors.indigoBright : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _examPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Which exam are you\npreparing for?', style: AppText.display),
          const SizedBox(height: 8),
          Text('Pick your target exam. You can change this later.', style: AppText.bodyDim),
          const SizedBox(height: 24),
          ...kAllExams.map((e) {
            final selected = _selectedExamId == e.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedExamId = e.id;
                  _selectedStage = e.stages.isNotEmpty ? e.stages.first.code : '';
                }),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? e.color.withValues(alpha: 0.12) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: selected ? e.color : AppColors.surfaceLine,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: e.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(e.icon, color: e.color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.shortName, style: AppText.h3),
                            const SizedBox(height: 2),
                            Text(e.description, style: AppText.captionDim),
                          ],
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle_rounded, color: e.color, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stagePage() {
    final exam = _exam;
    if (exam == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_rounded, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 10),
              Text('Pick an exam first', style: AppText.h3),
              const SizedBox(height: 8),
              TextButton(onPressed: _back, child: const Text('Go back')),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Which stage are\nyou focused on?', style: AppText.display),
          const SizedBox(height: 8),
          Text('${exam.shortName} — pick the stage you\'re prepping for first.', style: AppText.bodyDim),
          const SizedBox(height: 24),
          ...exam.stages.map((s) {
            final selected = _selectedStage == s.code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedStage = s.code),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.indigo.withValues(alpha: 0.12) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: selected ? AppColors.indigoBright : AppColors.surfaceLine,
                      width: selected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.indigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.layers_rounded, color: AppColors.indigoBright, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: AppText.h3),
                            const SizedBox(height: 2),
                            Text(
                              s.papers.isEmpty
                                  ? 'No paper-level prep'
                                  : '${s.papers.length} paper${s.papers.length == 1 ? '' : 's'}',
                              style: AppText.captionDim,
                            ),
                          ],
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle_rounded, color: AppColors.indigoBright, size: 22),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _goalsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('What are your\nstudy goals?', style: AppText.display),
          const SizedBox(height: 8),
          Text('Select all that apply — we\'ll tailor your experience.', style: AppText.bodyDim),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _goals.map((g) {
              final isSelected = _selectedGoals.contains(g.$1);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedGoals.remove(g.$1);
                  } else {
                    _selectedGoals.add(g.$1);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.indigo.withValues(alpha: 0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isSelected ? AppColors.indigoBright : AppColors.surfaceLine,
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(g.$2, color: isSelected ? AppColors.indigoBright : AppColors.textTertiary, size: 16),
                      const SizedBox(width: 8),
                      Text(g.$1,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? AppColors.indigoBright : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _signInPage() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('Almost there!', style: AppText.display),
          const SizedBox(height: 8),
          Text('Sign in to save your progress across devices.', style: AppText.bodyDim),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppDecor.hero(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 28),
                const SizedBox(height: 12),
                const Text('Cloud Sync',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('All your notes, quiz scores, and AI conversations stay safe in the cloud.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _feature(Icons.school_rounded, 'AI Tutor',
              'Ask anything about your exam — gets context from your notes'),
          _feature(Icons.bolt_rounded, 'Smart Quizzes',
              'AI-generated questions adapted to your weak areas'),
          _feature(Icons.insights_rounded, 'Deep Insights',
              'Subject, difficulty, and chapter-level analytics'),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.indigoBright, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3),
                Text(sub, style: AppText.captionDim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButtons() {
    final canContinue = _page == 0
        ? _selectedExamId.isNotEmpty
        : _page == 1
            ? _selectedStage.isNotEmpty
            : true;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            if (_page > 0)
              IconButton(
                onPressed: _back,
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
              ),
            if (_page > 0) const SizedBox(width: 12),
            Expanded(
              child: _page == 3
                  ? ElevatedButton.icon(
                      onPressed: _signingIn ? null : _signIn,
                      icon: _signingIn
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login_rounded),
                      label: Text(_signingIn ? 'Signing in...' : 'Continue with Google'),
                    )
                  : ElevatedButton(
                      onPressed: canContinue ? _next : null,
                      child: const Text('Continue'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
