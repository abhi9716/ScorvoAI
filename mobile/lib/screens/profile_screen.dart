import 'package:flutter/material.dart';
import 'package:scorvoai/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/services/auth_service.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/screens/onboarding_screen.dart';
import 'package:scorvoai/screens/chat_screen.dart';
import 'package:scorvoai/theme/theme_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
    if (uid == null) return;
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Your progress is safely synced to the cloud.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Could not load profile'))
              : CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildStatsRow(),
                            const SizedBox(height: 16),
                            _buildExamCard(),
                            if (_profile!.goals.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _buildGoalsCard(),
                            ],
                            const SizedBox(height: 12),
                            _buildPerformanceCard(),
                            const SizedBox(height: 12),
                            _buildMenuSection(),
                            const SizedBox(height: 24),
                            _buildSignOutButton(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSliverAppBar() {
    final p = _profile!;
    final initials = p.name.isNotEmpty
        ? p.name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.indigoBright,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.indigoBright, AppColors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: ClipOval(
                    child: p.photoUrl.isNotEmpty
                        ? Image.network(p.photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialsAvatar(initials, size: 84))
                        : _initialsAvatar(initials, size: 84),
                  ),
                ),
                const SizedBox(height: 12),
                Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(p.email, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceLine, width: 0.5),
                  ),
                  child: Text(p.examLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
      title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _initialsAvatar(String initials, {double size = 40}) {
    return Container(
      width: size, height: size,
      color: AppColors.indigo,
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _buildStatsRow() {
    final total = _insights?['total_quizzes'] as int? ?? 0;
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final best = _insights?['best_score'] as double? ?? 0.0;
    final streak = _insights?['streak'] as int? ?? 0;
    final totalQ = _insights?['total_questions'] as int? ?? 0;

    return Row(
      children: [
        _statBox('$streak', 'Streak', '🔥', const Color(0xffff6d00)),
        const SizedBox(width: 10),
        _statBox('$total', 'Quizzes', '📝', AppColors.indigoBright),
        const SizedBox(width: 10),
        _statBox('${avg.toStringAsFixed(0)}%', 'Avg', '📊', AppColors.success),
        const SizedBox(width: 10),
        _statBox('${best.toStringAsFixed(0)}%', 'Best', '⭐', AppColors.warning),
      ],
    );
  }

  Widget _statBox(String value, String label, String emoji, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceLine, width: 0.5),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard() {
    return _infoCard(
      icon: Icons.school_rounded,
      iconColor: AppColors.indigoBright,
      title: 'Target Exam',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.indigoBright.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.indigoBright.withValues(alpha: 0.3)),
        ),
        child: Text(_profile!.examLabel,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.indigoBright)),
      ),
    );
  }

  Widget _buildGoalsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLine, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.flag_rounded, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Study Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profile!.goals.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final passRate = _insights?['pass_rate'] as double? ?? 0.0;
    final totalQ = _insights?['total_questions'] as int? ?? 0;
    final color = avg >= 70 ? AppColors.success : avg >= 50 ? AppColors.warning : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLine, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.insights_rounded, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Performance Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _perfStat('Avg Score', '${avg.toStringAsFixed(1)}%', color)),
              Container(width: 1, height: 40, color: AppColors.surfaceLine),
              Expanded(child: _perfStat('Pass Rate', '${passRate.toStringAsFixed(0)}%', AppColors.success)),
              Container(width: 1, height: 40, color: AppColors.surfaceLine),
              Expanded(child: _perfStat('Qs Done', '$totalQ', AppColors.violet)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: avg / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_perfMsg(avg.round()), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _perfStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ],
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'ScorvoAI',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColors.indigoBright,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
      ),
      children: const [
        Text('ScorvoAI is an AI-powered exam preparation app for Indian government competitive exams (UPSC, SSC, IBPS, SBI, RRB, State PCS). It uses a specialized Gemma model for AI-powered features.\n\nPowered by Ollama Cloud and Firebase.\n\nGemma is a trademark of Google LLC.'),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLine, width: 0.5),
      ),
      child: Column(
        children: [
          _themeToggleTile(),
          const Divider(height: 1, indent: 56),
          _menuItem(
            Icons.smart_toy_rounded, 'AI Tutor', AppColors.indigoBright,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
          const Divider(height: 1, indent: 56),
          _menuItem(
            Icons.info_outline_rounded, 'About ScorvoAI', AppColors.textSecondary,
            _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _themeToggleTile() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (ctx, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.indigoBright : AppColors.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? AppColors.indigoBright : AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance',
                        style: TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                    Text(isDark ? 'Dark mode' : 'Light mode',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: isDark,
                onChanged: (_) => ThemeController.toggle(),
                activeColor: AppColors.indigoBright,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        label: const Text('Sign out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 16)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _infoCard({required IconData icon, required Color iconColor, required String title, required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLine, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  String _perfMsg(int avg) {
    if (avg >= 80) return 'Outstanding! Keep up the great work.';
    if (avg >= 60) return 'Good performance. Focus on weak topics.';
    if (avg >= 40) return 'Keep practicing — you\'re improving!';
    return 'Use the AI Tutor to strengthen weak areas.';
  }
}
