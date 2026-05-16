import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/services/auth_service.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:scorvoai/screens/onboarding_screen.dart';
import 'package:scorvoai/screens/chat_screen.dart';

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
      backgroundColor: const Color(0xfff5f7fa),
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
      expandedHeight: 220,
      pinned: true,
      backgroundColor: const Color(0xff1a73e8),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff1a73e8), Color(0xff0d47a1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
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
                  ),
                  child: Text(p.examLabel, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
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
      color: const Color(0xff1565c0),
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
        _statBox('$total', 'Quizzes', '📝', const Color(0xff1a73e8)),
        const SizedBox(width: 10),
        _statBox('${avg.toStringAsFixed(0)}%', 'Avg', '📊', const Color(0xff34a853)),
        const SizedBox(width: 10),
        _statBox('${best.toStringAsFixed(0)}%', 'Best', '⭐', const Color(0xfffbbc05)),
      ],
    );
  }

  Widget _statBox(String value, String label, String emoji, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xff999999))),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard() {
    return _infoCard(
      icon: Icons.school_rounded,
      iconColor: const Color(0xff1a73e8),
      title: 'Target Exam',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xff1a73e8).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xff1a73e8).withValues(alpha: 0.3)),
        ),
        child: Text(_profile!.examLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff1a73e8))),
      ),
    );
  }

  Widget _buildGoalsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xff34a853).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flag_rounded, color: Color(0xff34a853), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Study Goals', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e))),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _profile!.goals.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xff34a853).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff34a853).withValues(alpha: 0.3)),
              ),
              child: Text(g, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff34a853))),
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
    final color = avg >= 70 ? const Color(0xff34a853) : avg >= 50 ? const Color(0xfffbbc05) : const Color(0xffea4335);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
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
              const Text('Performance Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _perfStat('Avg Score', '${avg.toStringAsFixed(1)}%', color)),
              Container(width: 1, height: 40, color: const Color(0xffe0e0e0)),
              Expanded(child: _perfStat('Pass Rate', '${passRate.toStringAsFixed(0)}%', const Color(0xff34a853))),
              Container(width: 1, height: 40, color: const Color(0xffe0e0e0)),
              Expanded(child: _perfStat('Qs Done', '$totalQ', const Color(0xff9c27b0))),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xff999999))),
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
          color: const Color(0xff1a73e8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
      ),
      children: const [
        Text('AI-powered adaptive learning platform for government exam preparation.\n\nPowered by Ollama + Firebase.'),
      ],
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _menuItem(
            Icons.smart_toy_rounded, 'AI Tutor', const Color(0xff1a73e8),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
          const Divider(height: 1, indent: 56),
          _menuItem(
            Icons.info_outline_rounded, 'About ScorvoAI', const Color(0xff666666),
            _showAboutDialog,
          ),
        ],
      ),
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
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Color(0xff1a1a2e), fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right_rounded, color: Color(0xffcccccc), size: 20),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff1a1a2e))),
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
