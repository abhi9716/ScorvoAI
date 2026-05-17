import 'package:flutter/material.dart';
import 'package:scorvoai/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/screens/quiz_play_screen.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});
  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      _data = await FirestoreService.getInsights(uid);
    } catch (e) {
      debugPrint('Insights error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _data?['total_quizzes'] as int? ?? 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Insights', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.indigoBright),
            onPressed: _load,
          ),
        ],
        bottom: _loading || total == 0
            ? null
            : TabBar(
                controller: _tab,
                labelColor: AppColors.indigoBright,
                unselectedLabelColor: AppColors.textTertiary,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 12),
                indicatorColor: AppColors.indigoBright,
                indicatorWeight: 2.5,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Subjects'),
                  Tab(text: 'Difficulty'),
                  Tab(text: 'Chapters'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : total == 0
              ? _emptyState()
              : TabBarView(
                  controller: _tab,
                  children: [
                    _overviewTab(),
                    _subjectsTab(),
                    _difficultyTab(),
                    _chaptersTab(),
                  ],
                ),
    );
  }

  // ── Overview Tab ──────────────────────────────────────────────────────────

  Widget _overviewTab() {
    final avg = _data?['avg_score'] as double? ?? 0.0;
    final best = _data?['best_score'] as double? ?? 0.0;
    final streak = _data?['streak'] as int? ?? 0;
    final total = _data?['total_quizzes'] as int? ?? 0;
    final passRate = _data?['pass_rate'] as double? ?? 0.0;
    final totalQ = _data?['total_questions'] as int? ?? 0;
    final recentScores = List<double>.from(_data?['recent_scores'] as List? ?? []);
    final dist = Map<String, int>.from(_data?['score_distribution'] as Map? ?? {});
    final weak = List<Map<String, dynamic>>.from(_data?['weak_topics'] as List? ?? []);
    final strong = List<Map<String, dynamic>>.from(_data?['strong_topics'] as List? ?? []);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(avg, streak, total, best, passRate, totalQ),
          const SizedBox(height: 16),
          if (recentScores.length >= 2) ...[
            _sectionHeader('Performance Trend', Icons.show_chart_rounded, AppColors.indigoBright),
            const SizedBox(height: 6),
            Text('Green dots = pass (≥60%), Red dots = fail — dashed line = 60% threshold',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: 10),
            _trendChart(recentScores),
            const SizedBox(height: 16),
          ],
          _sectionHeader('Score Distribution', Icons.bar_chart_rounded, const Color(0xff9c27b0)),
          const SizedBox(height: 10),
          _distributionCard(dist, total),
          const SizedBox(height: 16),
          if (weak.isNotEmpty) ...[
            _sectionHeader('Focus Areas', Icons.gps_fixed_rounded, const Color(0xffea4335)),
            const SizedBox(height: 10),
            _topicsList(weak.take(5).toList(), const Color(0xffea4335), isWeak: true),
            const SizedBox(height: 10),
            _practiceButton(weak),
            const SizedBox(height: 16),
          ],
          if (strong.isNotEmpty) ...[
            _sectionHeader('Strengths', Icons.star_rounded, const Color(0xff34a853)),
            const SizedBox(height: 10),
            _topicsList(strong.take(5).toList(), const Color(0xff34a853), isWeak: false),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _heroCard(double avg, int streak, int total, double best, double passRate, int totalQ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.indigoBright, Color(0xff4285f4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.indigoBright.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90, height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90, height: 90,
                      child: CircularProgressIndicator(
                        value: avg / 100,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        color: Colors.white,
                        strokeWidth: 8,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${avg.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        const Text('Avg', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(child: _heroStat('$streak', 'Streak 🔥')),
                      Expanded(child: _heroStat('$total', 'Quizzes')),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _heroStat('${best.toStringAsFixed(0)}%', 'Best')),
                      Expanded(child: _heroStat('${passRate.toStringAsFixed(0)}%', 'Pass Rate')),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('$totalQ total questions answered',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String val, String label) => Column(
        children: [
          Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      );

  Widget _trendChart(List<double> scores) {
    final spots = scores.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    return Container(
      height: 160,
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
      decoration: _cardDecor(),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) => FlLine(color: AppColors.surfaceLine, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, _) =>
                    Text('${v.toInt()}%', style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.indigoBright,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                  radius: 4,
                  color: spot.y >= 60 ? const Color(0xff34a853) : const Color(0xffea4335),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                  show: true, color: AppColors.indigoBright.withValues(alpha: 0.08)),
            ),
            // Dashed 60% pass line
            LineChartBarData(
              spots: [FlSpot(0, 60), FlSpot((scores.length - 1).toDouble(), 60)],
              isCurved: false,
              color: const Color(0xffea4335).withValues(alpha: 0.5),
              barWidth: 1,
              dashArray: [5, 5],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _distributionCard(Map<String, int> dist, int total) {
    final bands = [
      ('0–25%', dist['0-25'] ?? 0, const Color(0xffea4335), 'Needs Work'),
      ('26–50%', dist['26-50'] ?? 0, const Color(0xfffbbc05), 'Below Avg'),
      ('51–75%', dist['51-75'] ?? 0, AppColors.indigoBright, 'Good'),
      ('76–100%', dist['76-100'] ?? 0, const Color(0xff34a853), 'Excellent'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        children: bands.map((b) {
          final pct = total > 0 ? b.$2 / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 52, child: Text(b.$1, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: AppColors.surfaceLine,
                      valueColor: AlwaysStoppedAnimation(b.$3),
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 20,
                    child: Text('${b.$2}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: b.$3))),
                const SizedBox(width: 4),
                SizedBox(
                    width: 64,
                    child: Text(b.$4, style: TextStyle(fontSize: 10, color: AppColors.textTertiary))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _topicsList(List<Map<String, dynamic>> topics, Color color, {required bool isWeak}) {
    return Container(
      decoration: _cardDecor(),
      child: Column(
        children: topics.asMap().entries.map((e) {
          final t = e.value;
          final avg = (t['avg'] as num).toDouble();
          final attempts = t['attempts'] as int? ?? 0;
          final c = isWeak
              ? Color.lerp(const Color(0xffea4335), const Color(0xfffbbc05), avg / 60) ?? color
              : Color.lerp(AppColors.indigoBright, const Color(0xff34a853), (avg - 60).clamp(0, 40) / 40) ?? color;
          return Column(
            children: [
              if (e.key > 0) const Divider(height: 1, color: Color(0xfff5f5f5)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text('${avg.toStringAsFixed(0)}%',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['topic'] as String? ?? '',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text('$attempts attempt${attempts == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: avg / 100,
                          backgroundColor: AppColors.surfaceLine,
                          valueColor: AlwaysStoppedAnimation(c),
                          minHeight: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _practiceButton(List<Map<String, dynamic>> weak) {
    final topics = weak
        .map((t) => t['topic'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                QuizPlayScreen(mode: QuizMode.custom, subjects: topics, count: 5, difficulty: 'medium'),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xffea4335),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.fitness_center_rounded, size: 18),
        label: const Text('Practice Weak Topics', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ── Subjects Tab ──────────────────────────────────────────────────────────

  Widget _subjectsTab() {
    final subjectBreakdown = Map<String, dynamic>.from(_data?['subject_breakdown'] as Map? ?? {});
    final topicBreakdown = Map<String, dynamic>.from(_data?['topic_breakdown'] as Map? ?? {});

    // Prefer per-question subject data, fallback to quiz-level topic data
    final source = subjectBreakdown.isNotEmpty ? subjectBreakdown : topicBreakdown;
    final usingPerQuestion = subjectBreakdown.isNotEmpty;

    if (source.isEmpty) {
      return _emptyTabState('No subject data yet', 'Take more quizzes to see subject-wise performance');
    }

    final entries = source.entries.toList()
      ..sort((a, b) {
        final aAvg = ((a.value as Map)['avg'] as num).toDouble();
        final bAvg = ((b.value as Map)['avg'] as num).toDouble();
        return aAvg.compareTo(bAvg);
      });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!usingPerQuestion)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffffcc02).withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xffe65100)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Showing quiz-level topics. Take more quizzes for per-question subject breakdown.',
                        style: TextStyle(fontSize: 12, color: Color(0xffe65100))),
                  ),
                ],
              ),
            ),
          _sectionHeader('Subject Performance', Icons.subject_rounded, AppColors.indigoBright),
          const SizedBox(height: 4),
          Text('Sorted weakest → strongest',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(height: 12),
          ...entries.map((e) {
            final avg = ((e.value as Map)['avg'] as num).toDouble();
            final total = (e.value as Map)['total'] as int? ??
                (e.value as Map)['attempts'] as int? ?? 0;
            final correct = (e.value as Map)['correct'] as int?;
            final color = _scoreColor(avg);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border(left: BorderSide(color: color, width: 4)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text('${avg.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avg / 100,
                        backgroundColor: AppColors.surfaceLine,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('$total ${usingPerQuestion ? 'questions' : 'attempts'}',
                            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        if (correct != null) ...[
                          const Spacer(),
                          Text('$correct correct',
                              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Difficulty Tab ────────────────────────────────────────────────────────

  Widget _difficultyTab() {
    final diff = Map<String, dynamic>.from(_data?['difficulty_breakdown'] as Map? ?? {});

    if (diff.isEmpty) {
      return _emptyTabState(
          'No difficulty data yet', 'Complete quizzes to see difficulty-wise breakdown.\nData is collected per-question from your next quiz.');
    }

    const order = ['easy', 'medium', 'hard', 'mixed'];
    const configs = {
      'easy': (Icons.sentiment_satisfied_rounded, Color(0xff34a853), 'Easy'),
      'medium': (Icons.sentiment_neutral_rounded, Color(0xfffbbc05), 'Medium'),
      'hard': (Icons.sentiment_dissatisfied_rounded, Color(0xffea4335), 'Hard'),
      'mixed': (Icons.shuffle_rounded, Color(0xff9c27b0), 'Mixed'),
    };

    final sorted = order.where((k) => diff.containsKey(k)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Difficulty Breakdown', Icons.signal_cellular_alt_rounded, AppColors.indigoBright),
          const SizedBox(height: 12),
          ...sorted.map((key) {
            final v = diff[key] as Map;
            final avg = (v['avg'] as num).toDouble();
            final total = v['total'] as int? ?? 0;
            final correct = v['correct'] as int? ?? 0;
            final cfg = configs[key] ?? (Icons.help_rounded, const Color(0xff9c27b0), key);
            final color = cfg.$2;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(cfg.$1, color: color, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.$3,
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: avg / 100,
                              backgroundColor: AppColors.surfaceLine,
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 7,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('$correct / $total correct',
                              style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${avg.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                        Text('avg score',
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _difficultyTip(diff),
        ],
      ),
    );
  }

  Widget _difficultyTip(Map<String, dynamic> diff) {
    final easyAvg = ((diff['easy'] as Map?)?['avg'] as num?)?.toDouble() ?? 100.0;
    final hardAvg = ((diff['hard'] as Map?)?['avg'] as num?)?.toDouble() ?? 0.0;
    final String tip;
    final Color color;
    if (hardAvg >= 70) {
      tip = 'Excellent! You\'re crushing hard questions. Consider attempting full mock exams.';
      color = const Color(0xff34a853);
    } else if (easyAvg < 60) {
      tip = 'Focus on strengthening fundamentals — easy questions need more attention.';
      color = const Color(0xffea4335);
    } else {
      tip = 'Good base! Practice more hard questions to boost your overall score.';
      color = AppColors.indigoBright;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(tip, style: TextStyle(fontSize: 13, color: color, height: 1.4))),
        ],
      ),
    );
  }

  // ── Chapters Tab ──────────────────────────────────────────────────────────

  Widget _chaptersTab() {
    final chapterBreakdown = Map<String, dynamic>.from(_data?['chapter_breakdown'] as Map? ?? {});

    if (chapterBreakdown.isEmpty) {
      return _emptyTabState(
          'No chapter data yet',
          'Complete quizzes to see chapter-wise performance.\nData is collected per-question from your next quiz.');
    }

    final all = chapterBreakdown.entries.toList();
    final weak = all
        .where((e) => ((e.value as Map)['avg'] as num).toDouble() < 60)
        .toList()
      ..sort((a, b) =>
          ((a.value as Map)['avg'] as num).compareTo((b.value as Map)['avg'] as num));
    final strong = all
        .where((e) => ((e.value as Map)['avg'] as num).toDouble() >= 60)
        .toList()
      ..sort((a, b) =>
          ((b.value as Map)['avg'] as num).compareTo((a.value as Map)['avg'] as num));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (weak.isNotEmpty) ...[
            _sectionHeader('Weak Chapters', Icons.trending_down_rounded, const Color(0xffea4335)),
            const SizedBox(height: 10),
            ..._chapterCards(weak),
            const SizedBox(height: 16),
          ],
          if (strong.isNotEmpty) ...[
            _sectionHeader('Strong Chapters', Icons.trending_up_rounded, const Color(0xff34a853)),
            const SizedBox(height: 10),
            ..._chapterCards(strong.take(10).toList()),
          ],
        ],
      ),
    );
  }

  List<Widget> _chapterCards(List<MapEntry<String, dynamic>> entries) {
    return entries.map((e) {
      final v = e.value as Map;
      final avg = (v['avg'] as num).toDouble();
      final total = v['total'] as int? ?? 0;
      final correct = v['correct'] as int? ?? 0;
      final subject = v['subject'] as String? ?? '';
      final color = _scoreColor(avg);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text('${avg.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ),
              if (subject.isNotEmpty && subject != 'Mixed') ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.indigoBright.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(subject,
                      style: TextStyle(
                          fontSize: 10, color: AppColors.indigoBright, fontWeight: FontWeight.w500)),
                ),
              ],
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: avg / 100,
                  backgroundColor: AppColors.surfaceLine,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text('$correct / $total correct',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ),
      );
    }).toList();
  }

  // ── Shared Helpers ────────────────────────────────────────────────────────

  Color _scoreColor(double avg) {
    if (avg >= 75) return const Color(0xff34a853);
    if (avg >= 50) return AppColors.indigoBright;
    if (avg >= 35) return const Color(0xfffbbc05);
    return const Color(0xffea4335);
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }

  BoxDecoration _cardDecor() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      );

  Widget _emptyTabState(String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 56, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(sub,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
                color: AppColors.indigoBright.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.analytics_rounded, size: 48, color: AppColors.indigoBright),
          ),
          const SizedBox(height: 20),
          Text('No insights yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Complete a quiz to see your\nperformance insights here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const QuizPlayScreen(mode: QuizMode.mixed, count: 5)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.indigoBright,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.quiz_rounded),
            label: const Text('Take First Quiz', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
