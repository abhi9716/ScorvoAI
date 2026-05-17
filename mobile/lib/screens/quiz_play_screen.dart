import 'dart:async';
import 'package:scorvoai/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/services/api.dart';
import 'package:scorvoai/services/firestore_service.dart';

enum QuizMode { mixed, custom }

class QuizPlayScreen extends StatefulWidget {
  final QuizMode mode;
  final String? difficulty;
  final List<String>? subjects;
  final List<String>? chapters;
  final int count;
  const QuizPlayScreen({super.key, required this.mode, this.difficulty, this.subjects, this.chapters, required this.count});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _questions = [];
  final Map<int, int> _answers = {};
  bool _allArrived = false;
  bool _waitingForNext = false;
  bool _submitting = false;
  bool _reviewing = false;
  int _currentIndex = 0;
  Map<String, dynamic>? _result;
  late AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;

  int _timeRemaining = 0;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _scoreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scoreAnim = CurvedAnimation(parent: _scoreCtrl, curve: Curves.elasticOut);
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamSub?.cancel();
    _scoreCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_timer?.isActive == true) return;
    _timer?.cancel();
    if (_result != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _result != null) {
        timer.cancel();
        return;
      }
      setState(() {
        _timeRemaining--;
        if (_timeRemaining <= 0) {
          _timeRemaining = 0;
          timer.cancel();
          _submit();
        }
      });
    });
  }

  void _goNext() {
    if (_currentIndex + 1 < _questions.length) {
      setState(() {
        _currentIndex++;
        _waitingForNext = false;
      });
    } else if (!_allArrived) {
      setState(() => _waitingForNext = true);
    }
  }

  void _goPrevious() {
    if (_currentIndex <= 0) return;
    setState(() {
      _currentIndex--;
      _waitingForNext = false;
    });
  }

  void _selectAnswer(int optionIdx) {
    setState(() => _answers[_currentIndex] = optionIdx);
  }

  Future<void> _loadQuestions() async {
    _streamSub?.cancel();
    _timer?.cancel();
    setState(() {
      _questions = [];
      _result = null;
      _answers.clear();
      _scoreCtrl.reset();
      _currentIndex = 0;
      _allArrived = false;
      _waitingForNext = false;
      _reviewing = false;
      _timeRemaining = widget.count * 60;
    });

    _streamSub = ApiService.getQuizStream(
      mode: widget.mode == QuizMode.mixed ? ApiQuizMode.mixed : ApiQuizMode.custom,
      subjects: widget.subjects,
      chapters: widget.chapters,
      count: widget.count,
      difficulty: widget.difficulty,
    ).listen(
      (question) {
        if (!mounted) return;
        setState(() {
          _questions.add(question);
          if (_questions.length >= widget.count) {
            _allArrived = true;
          }
          if (_questions.length == 1) {
            _startTimer();
          }
          if (_waitingForNext && _questions.length > _currentIndex + 1) {
            _waitingForNext = false;
            _currentIndex++;
          }
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _allArrived = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _allArrived = true);
      },
    );
  }

  Future<void> _submit() async {
    final answers = _questions.asMap().entries.map((e) {
      final idx = e.key;
      final q = e.value;
      return {
        'question_index': q['ai_generated'] == true ? -1 : (q['id'] ?? -1),
        'selected_option': _answers[idx] ?? -1,
        'correct_option': q['correct'] as int,
      };
    }).toList();

    final topic = (widget.subjects != null && widget.subjects!.isNotEmpty)
        ? widget.subjects!.join(', ')
        : 'mixed';

    setState(() => _submitting = true);
    try {
      _result = await ApiService.submitQuiz(answers, topic: topic);
      _timer?.cancel();
      _scoreCtrl.forward();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Enrich each question with per-question result for breakdown analytics
        final questionsWithResults = _questions.asMap().entries.map((e) {
          final idx = e.key;
          final q = Map<String, dynamic>.from(e.value as Map);
          final userAnswer = _answers[idx] ?? -1;
          q['user_answer'] = userAnswer;
          q['is_correct'] = userAnswer == (q['correct'] as int? ?? -2);
          return q;
        }).toList();
        FirestoreService.saveQuizResult(
          uid: uid,
          score: _result!['score'] as int,
          total: _result!['total'] as int,
          topic: topic,
          difficulty: widget.difficulty ?? 'mixed',
          questions: questionsWithResults,
        ).ignore();
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Color _difficultyColor(String? diff) {
    if (diff == null) return const Color(0xff9c27b0);
    switch (diff.toLowerCase()) {
      case 'easy': return const Color(0xff34a853);
      case 'medium': return const Color(0xfffbbc05);
      case 'hard': return const Color(0xffea4335);
      default: return const Color(0xff9c27b0);
    }
  }

  Widget _pill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildProgressDots() {
    final total = widget.count;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final arrived = i < _questions.length;
        final isCurrent = i == _currentIndex;
        Color color;
        double size;
        if (isCurrent) {
          color = AppColors.indigoBright;
          size = 12;
        } else if (arrived && _answers.containsKey(i)) {
          color = const Color(0xff34a853);
          size = 10;
        } else if (arrived) {
          color = AppColors.textTertiary;
          size = 8;
        } else {
          color = Colors.transparent;
          size = 8;
        }
        return GestureDetector(
          onTap: arrived ? () {
            setState(() {
              _currentIndex = i;
              _waitingForNext = false;
            });
          } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: arrived ? color : Colors.transparent,
              border: arrived ? null : Border.all(color: AppColors.textTertiary, width: 2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildQuestionCard(int idx, dynamic q) {
    final selectedIdx = _answers[idx];
    final showResult = _result != null;
    final correctIdx = q['correct'] as int;
    final selectedAnswer = showResult ? selectedIdx : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${idx + 1}. ${q['question']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _pill(q['subject'] ?? 'Mixed', AppColors.indigoBright, AppColors.indigoBright.withValues(alpha: 0.15)),
                _pill(q['chapter'] ?? 'General', const Color(0xff9c27b0), const Color(0xfff3e5f5)),
                _pill(q['difficulty']?.toString().isNotEmpty == true ? (q['difficulty'] as String).toUpperCase() : 'MIXED', _difficultyColor(q['difficulty']), _difficultyColor(q['difficulty']).withValues(alpha: 0.1)),
                if (q['ai_generated'] == true) _pill('AI', const Color(0xff34a853), const Color(0xffe8f5e9)),
              ],
            ),
            const SizedBox(height: 14),
            ...List.generate((q['options'] as List).length, (optIdx) {
              Color bg;
              Color border;
              Color text;
              FontWeight weight = FontWeight.normal;
              Widget? icon;

              if (showResult) {
                if (optIdx == correctIdx) {
                  bg = AppColors.success.withValues(alpha: 0.15);
                  border = AppColors.success;
                  text = AppColors.textPrimary;
                  weight = FontWeight.w600;
                  icon = const Icon(Icons.check_circle, color: AppColors.success, size: 22);
                } else if (optIdx == selectedAnswer) {
                  bg = AppColors.danger.withValues(alpha: 0.15);
                  border = AppColors.danger;
                  text = AppColors.textPrimary;
                  icon = const Icon(Icons.cancel, color: AppColors.danger, size: 22);
                } else {
                  bg = AppColors.surfaceHigh;
                  border = AppColors.surfaceLine;
                  text = AppColors.textTertiary;
                }
              } else {
                final selected = selectedIdx == optIdx;
                bg = selected ? AppColors.indigoBright : AppColors.surfaceHigh;
                border = selected ? AppColors.indigoBright : AppColors.surfaceLine;
                text = selected ? Colors.white : AppColors.textPrimary;
                weight = selected ? FontWeight.w600 : FontWeight.normal;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: showResult ? null : () => _selectAnswer(optIdx),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border, width: 2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${String.fromCharCode(65 + optIdx)}. ${(q['options'] as List)[optIdx]}',
                            style: TextStyle(fontSize: 15, color: text, fontWeight: weight),
                          ),
                        ),
                        if (icon != null) icon,
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (showResult && (q['explanation'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: AppColors.success, size: 16),
                          const SizedBox(width: 6),
                          Text('Explanation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GptMarkdown(
                        q['explanation'] as String,
                        style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.45),
                        useDollarSignsForLatex: false,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    final isMixed = widget.mode == QuizMode.mixed;
    final accentColor = isMixed ? const Color(0xfffbbc05) : const Color(0xff34a853);
    final isLast = _questions.isNotEmpty && _currentIndex == _questions.length - 1;
    final canGoNext = _currentIndex + 1 < _questions.length;
    final canGoPrev = _currentIndex > 0;

    final containerDecoration = BoxDecoration(
      color: AppColors.bgElevated,
      border: Border(top: BorderSide(color: AppColors.surfaceLine)),
    );
    final prevButton = OutlinedButton.icon(
      onPressed: _goPrevious,
      icon: const Icon(Icons.arrow_back, size: 18),
      label: const Text('Previous'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        foregroundColor: AppColors.indigoBright,
        side: BorderSide(color: AppColors.indigoBright),
      ),
    );

    if (_reviewing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: containerDecoration,
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (canGoPrev) ...[
                Expanded(child: prevButton),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: canGoPrev ? 1 : 2,
                child: isLast
                    ? ElevatedButton(
                        onPressed: () => setState(() => _reviewing = false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.indigoBright,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 4,
                        ),
                        child: const Text('Back to Results', style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : ElevatedButton(
                        onPressed: canGoNext ? _goNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 4,
                          shadowColor: accentColor.withValues(alpha: 0.3),
                        ),
                        child: const Text('Next \u2192', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: containerDecoration,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (canGoPrev) ...[
              Expanded(child: prevButton),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: canGoPrev ? 1 : 2,
              child: isLast
                  ? ElevatedButton(
                      onPressed: _allArrived ? (_submitting ? null : _submit) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                        shadowColor: accentColor.withValues(alpha: 0.3),
                      ),
                      child: _submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(
                              _allArrived ? 'Submit Quiz' : 'Waiting for questions...',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                    )
                  : _waitingForNext
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text('Generating...', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          onPressed: canGoNext ? _goNext : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                            shadowColor: accentColor.withValues(alpha: 0.3),
                          ),
                          child: const Text('Next \u2192', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMixed = widget.mode == QuizMode.mixed;
    final accentColor = isMixed ? const Color(0xfffbbc05) : const Color(0xff34a853);
    final fgColor = isMixed ? AppColors.textPrimary : Colors.white;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _result != null && !_reviewing
                ? 'Result'
                : _reviewing
                    ? 'Review Answers'
                    : (isMixed ? 'Mixed Quiz' : 'Custom Quiz'),
            key: ValueKey('${_result != null}_$_reviewing'),
          ),
        ),
        backgroundColor: accentColor,
        foregroundColor: fgColor,
        actions: [
          if (_result == null && _questions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _timeRemaining <= 60 ? Colors.red : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 18, color: _timeRemaining <= 60 ? Colors.white : fgColor),
                  const SizedBox(width: 4),
                  Text(
                    '${(_timeRemaining / 60).floor()}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _timeRemaining <= 60 ? Colors.white : fgColor),
                  ),
                ],
              ),
            ),
          if (_result == null)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadQuestions, tooltip: 'Refresh \u2014 new AI questions'),
        ],
      ),
      body: SafeArea(
        child: _questions.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Generating question 1 of ${widget.count}...',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : _result != null && !_reviewing
                ? _buildResult()
                : Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildProgressDots(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Question ${_currentIndex + 1} of ${widget.count}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: _buildQuestionCard(_currentIndex, _questions[_currentIndex]),
                        ),
                      ),
                      if (!_allArrived)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text(
                                'Loading question ${_questions.length + 1} of ${widget.count}...',
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      _buildNavigation(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildResult() {
    final isMixed = widget.mode == QuizMode.mixed;
    final accentColor = isMixed ? const Color(0xfffbbc05) : const Color(0xff34a853);
    final score = _result!['score'] as int;
    final total = _result!['total'] as int;
    final pct = total > 0 ? ((score / total) * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(offset: Offset(0, 40 * (1 - value)), child: Opacity(opacity: value, child: child));
            },
            child: const Text('Quiz Complete!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accentColor, accentColor.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 5)],
              ),
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, child) {
                  return Text('${(_scoreAnim.value * score).round()}/$total', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white));
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: pct.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Text('${value.round()}%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Text(_performanceLabel(pct), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _performanceColor(pct))),
          ),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) => Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)),
            child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loadQuestions, style: ElevatedButton.styleFrom(backgroundColor: AppColors.indigoBright, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('New Quiz', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            builder: (context, value, child) => Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)),
            child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => setState(() { _reviewing = true; _currentIndex = 0; }),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Review Answers'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: AppColors.indigoBright, side: BorderSide(color: AppColors.indigoBright), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 700),
            builder: (context, value, child) => Transform.translate(offset: Offset(0, 20 * (1 - value)), child: Opacity(opacity: value, child: child)),
            child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Back to Menu', style: TextStyle(color: AppColors.indigoBright, fontSize: 16, fontWeight: FontWeight.w700)))),
          ),
        ],
      ),
    );
  }

  String _performanceLabel(int pct) {
    if (pct >= 80) return 'Excellent! \u{1F389}';
    if (pct >= 60) return 'Good, keep going! \u{1F4AA}';
    if (pct >= 40) return 'Keep practicing! \u{1F4DA}';
    return 'Don\'t give up! \u{1F3AF}';
  }

  Color _performanceColor(int pct) {
    if (pct >= 80) return const Color(0xff34a853);
    if (pct >= 60) return const Color(0xfffbbc05);
    if (pct >= 40) return const Color(0xffea4335);
    return const Color(0xffea4335);
  }
}
