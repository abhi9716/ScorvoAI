import 'package:flutter/material.dart';
import 'package:scorvoai/services/api.dart';
import 'package:scorvoai/screens/quiz_play_screen.dart';

enum QuizDifficulty { easy, medium, hard, mixed }

class QuizTypeScreen extends StatefulWidget {
  const QuizTypeScreen({super.key});

  @override
  State<QuizTypeScreen> createState() => _QuizTypeScreenState();
}

class _QuizTypeScreenState extends State<QuizTypeScreen> with SingleTickerProviderStateMixin {
  final Set<String> _selectedSubjects = {};
  final Set<String> _selectedChapters = {};
  Map<String, dynamic>? _subjects;
  bool _loading = true;
  int _questionCount = 5;
  QuizDifficulty _difficulty = QuizDifficulty.mixed;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadSubjects();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      _subjects = await ApiService.getSubjects();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
        _selectedChapters.removeWhere((c) => _isChapterOf(subject, c));
      } else {
        _selectedSubjects.add(subject);
        final chapters = _subjects?['subjects'][subject] as List?;
        if (chapters != null) {
          for (final c in chapters.cast<String>()) {
            _selectedChapters.add(c);
          }
        }
      }
    });
  }

  bool _isChapterOf(String subject, String chapter) {
    final chapters = _subjects?['subjects'][subject] as List?;
    if (chapters == null) return false;
    return chapters.contains(chapter);
  }

  void _startQuiz() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => QuizPlayScreen(
          mode: QuizMode.custom,
          difficulty: _difficulty == QuizDifficulty.mixed ? null : _difficulty.name,
          subjects: _selectedSubjects.isEmpty ? null : _selectedSubjects.toList(),
          chapters: _selectedChapters.isEmpty ? null : _selectedChapters.toList(),
          count: _questionCount,
        ),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Custom Quiz'), backgroundColor: const Color(0xff1a73e8), foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: const Text('Quiz Setup', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 20),

              _sectionTitle('Difficulty'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: QuizDifficulty.values.map((d) {
                  final selected = _difficulty == d;
                  Color chipColor;
                  String emoji;
                  switch (d) {
                    case QuizDifficulty.easy: chipColor = const Color(0xff34a853); emoji = '🟢'; break;
                    case QuizDifficulty.medium: chipColor = const Color(0xfffbbc05); emoji = '🟡'; break;
                    case QuizDifficulty.hard: chipColor = const Color(0xffea4335); emoji = '🔴'; break;
                    case QuizDifficulty.mixed: chipColor = const Color(0xff9c27b0); emoji = '🎲'; break;
                  }
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (ctx, val, child) => Transform.scale(scale: val, child: child),
                    child: FilterChip(
                      label: Text('$emoji ${d.name[0].toUpperCase() + d.name.substring(1)}'),
                      selected: selected,
                      onSelected: (_) => setState(() => _difficulty = d),
                      selectedColor: chipColor,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xff333333),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Subjects (tap to select multiple)'),
              const SizedBox(height: 10),
              if (_subjects == null)
                Center(
                  child: Column(
                    children: [
                      const Text('Failed to load subjects', style: TextStyle(color: Color(0xff999999))),
                      TextButton(onPressed: () { setState(() => _loading = true); _loadSubjects(); }, child: const Text('Retry')),
                    ],
                  ),
                )
              else
                Wrap(
                spacing: 10,
                runSpacing: 10,
                children: (_subjects!['subjects'] as Map<String, dynamic>).entries.map((e) {
                  final selected = _selectedSubjects.contains(e.key);
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 250),
                    builder: (ctx, val, child) => Transform.scale(scale: val, child: child),
                    child: FilterChip(
                      label: Text(e.key),
                      selected: selected,
                      onSelected: (_) => _toggleSubject(e.key),
                      selectedColor: const Color(0xff1a73e8),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : const Color(0xff333333),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              _sectionTitle('Chapters (tap to toggle)'),
              const SizedBox(height: 10),
              if (_selectedSubjects.isEmpty)
                const Text('Select subjects first to see chapters', style: TextStyle(color: Color(0xff999999), fontSize: 14)),
              if (_selectedSubjects.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Wrap(
                    key: ValueKey(_selectedSubjects.length),
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedSubjects.expand((subject) {
                      final chapters = (_subjects!['subjects'][subject] as List).cast<String>();
                      return chapters.map((ch) {
                        final selected = _selectedChapters.contains(ch);
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 200),
                          builder: (ctx, val, child) => Transform.scale(scale: val, child: child),
                          child: FilterChip(
                            label: Text(ch),
                            selected: selected,
                            onSelected: (_) => setState(() {
                              if (selected) {
                                _selectedChapters.remove(ch);
                              } else {
                                _selectedChapters.add(ch);
                              }
                            }),
                            selectedColor: const Color(0xff34a853),
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : const Color(0xff555555),
                              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      });
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 24),
              _sectionTitle('Number of Questions'),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _questionCount,
                    items: [5, 10, 15, 20, 25].map((n) => DropdownMenuItem(value: n, child: Text('$n questions', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))).toList(),
                    onChanged: (n) { if (n != null) setState(() => _questionCount = n); },
                  ),
                ),
              ),

              const SizedBox(height: 28),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                builder: (ctx, val, child) => Transform.translate(offset: Offset(0, 20 * (1 - val)), child: Opacity(opacity: val, child: child)),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xfffbbc05),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                      shadowColor: const Color(0xfffbbc05).withValues(alpha: 0.4),
                    ),
                    child: Text(
                      '🚀  Start Quiz (${_questionCount} Qs)',
                      style: const TextStyle(color: Color(0xff333333), fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xff333333)));
  }
}
