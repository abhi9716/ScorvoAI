import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:scorvoai/services/api.dart';
import 'package:scorvoai/services/firestore_service.dart';
import 'package:scorvoai/models/user_profile.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:scorvoai/theme/app_theme.dart';

const _suggestions = [
  'Difference between Fundamental Rights and Duties?',
  'Compound interest formula with example',
  'How to solve blood relation questions fast?',
  'Significance of Article 370',
  'GDP vs GNP explained simply',
  'Shortcut to find square root of a number',
  'Difference between Lok Sabha and Rajya Sabha',
  'Time and work shortcuts for SSC exams',
];

class _Msg {
  final String id;
  final bool isUser;
  String text;
  final DateTime time;
  bool isStreaming;
  _Msg({
    required this.id,
    required this.isUser,
    required this.text,
    required this.time,
    this.isStreaming = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final _messages = <_Msg>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isStreaming = false;
  bool _isThinking = false;
  bool _showScrollDown = false;
  late AnimationController _dotCtrl;
  UserProfile? _userProfile;
  List<String> _weakTopics = [];
  List<Map<String, dynamic>> _recentNotes = [];
  List<Map<String, dynamic>> _recentLessons = [];
  List<Map<String, dynamic>> _currentAffairs = [];
  Map<String, dynamic>? _insights;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _scrollController.addListener(_onScroll);
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final results = await Future.wait([
        FirestoreService.getProfile(uid),
        FirestoreService.getInsights(uid),
        FirestoreService.getRecentAiNotes(uid, limit: 15),
        FirestoreService.getRecentLessons(uid, limit: 5),
        FirestoreService.getTodayCurrentAffairs(),
      ]);
      if (!mounted) return;
      final profile = results[0] as UserProfile?;
      final insights = results[1] as Map<String, dynamic>?;
      final notes = results[2] as List<Map<String, dynamic>>;
      final lessons = results[3] as List<Map<String, dynamic>>;
      final affairs = (results[4] as List<Map<String, dynamic>>?) ?? [];
      setState(() {
        _userProfile = profile;
        _insights = insights;
        _weakTopics = (insights?['weak_topics'] as List? ?? [])
            .map((t) => t['topic'] as String? ?? '')
            .where((t) => t.isNotEmpty)
            .toList();
        _recentNotes = notes;
        _recentLessons = lessons;
        _currentAffairs = affairs;
      });
    } catch (_) {}
  }

  String _buildContextualPrompt(String userQuestion) {
    final p = _userProfile;
    if (p == null) return userQuestion;

    final ql = userQuestion.toLowerCase();
    final keywords = ql.split(RegExp(r'\W+')).where((w) => w.length > 3).toSet();

    // Helper: relevance score by keyword overlap
    int score(String text, {int titleBoost = 0}) {
      final t = text.toLowerCase();
      int s = titleBoost;
      for (final kw in keywords) {
        if (t.contains(kw)) s += 1;
      }
      return s;
    }

    final parts = <String>[];

    // 1) Student profile
    parts.add('Student preparing for: ${p.examLabel}.');
    if (p.goals.isNotEmpty) parts.add('Study goals: ${p.goals.join(', ')}.');

    // 2) Quiz stats
    final total = _insights?['total_quizzes'] as int? ?? 0;
    final avg = _insights?['avg_score'] as double? ?? 0.0;
    final streak = _insights?['streak'] as int? ?? 0;
    final passRate = _insights?['pass_rate'] as double? ?? 0.0;
    if (total > 0) {
      parts.add('Performance: $total quizzes, avg ${avg.toStringAsFixed(0)}%, pass rate ${passRate.toStringAsFixed(0)}%, $streak-day streak.');
    }

    // 3) Topic strengths/weaknesses
    if (_weakTopics.isNotEmpty) parts.add('Weak topics: ${_weakTopics.take(5).join(', ')}.');
    final strong = (_insights?['strong_topics'] as List? ?? [])
        .map((t) => t['topic'] as String? ?? '')
        .where((t) => t.isNotEmpty)
        .take(3)
        .toList();
    if (strong.isNotEmpty) parts.add('Strong topics: ${strong.join(', ')}.');

    // 4) Subject/difficulty/chapter breakdowns
    final subjBreakdown = Map<String, dynamic>.from(_insights?['subject_breakdown'] as Map? ?? {});
    if (subjBreakdown.isNotEmpty) {
      final byScore = subjBreakdown.entries.toList()
        ..sort((a, b) => ((a.value as Map)['avg'] as num).compareTo((b.value as Map)['avg'] as num));
      final lowest = byScore.take(3).map((e) {
        final avg = ((e.value as Map)['avg'] as num).toDouble();
        return '${e.key} (${avg.toStringAsFixed(0)}%)';
      }).join(', ');
      parts.add('Subject avgs (weakest first): $lowest.');
    }
    final diffBreakdown = Map<String, dynamic>.from(_insights?['difficulty_breakdown'] as Map? ?? {});
    if (diffBreakdown.isNotEmpty) {
      final summary = diffBreakdown.entries.map((e) {
        final avg = ((e.value as Map)['avg'] as num).toDouble();
        return '${e.key} ${avg.toStringAsFixed(0)}%';
      }).join(', ');
      parts.add('By difficulty: $summary.');
    }

    final ctx = StringBuffer();
    ctx.writeln('[STUDENT CONTEXT — use this to personalise your answer]');
    ctx.writeln(parts.join(' '));

    // 5) Notes — full content for relevant ones
    final isAskingAboutNotes = ql.contains('note') || ql.contains('saved') || ql.contains('wrote') ||
        ql.contains('my note') || ql.contains('what did i');
    final scoredNotes = _recentNotes.map((n) {
      final s = score(n['title'] as String? ?? '', titleBoost: 3) + score(n['content'] as String? ?? '');
      return (note: n, score: s + (isAskingAboutNotes ? 1 : 0));
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (_recentNotes.isNotEmpty) {
      ctx.writeln('\n[USER NOTES — they have saved these]');
      var included = 0;
      for (final entry in scoredNotes) {
        if (included >= 8) break;
        final n = entry.note;
        final title = n['title'] as String? ?? 'Untitled';
        final content = n['content'] as String? ?? '';
        final src = n['source'] as String? ?? '';
        final srcLabel = src == 'ai_tutor' ? 'AI Tutor' : src == 'ocr_scan' ? 'Scanned' : src == 'lesson' ? 'Lesson' : 'Manual';
        final highlyRelevant = entry.score >= 3 || (isAskingAboutNotes && included < 3);
        if (highlyRelevant) {
          ctx.writeln('NOTE "$title" [$srcLabel]: $content');
        } else if (included < 5) {
          final excerpt = content.length > 150 ? '${content.substring(0, 150)}...' : content;
          ctx.writeln('NOTE "$title" [$srcLabel]: $excerpt');
        }
        included++;
      }
      ctx.writeln('[END NOTES]');
    }

    // 6) Recent lessons viewed
    if (_recentLessons.isNotEmpty) {
      ctx.writeln('\n[RECENT LESSONS THE USER STUDIED]');
      for (final l in _recentLessons.take(5)) {
        ctx.writeln('- ${l['subject']} / ${l['chapter']} (${l['difficulty']}, viewed ${l['view_count'] ?? 1}x)');
      }
      ctx.writeln('[END LESSONS]');
    }

    // 7) Current affairs (always brief; full if explicitly asked)
    final asksCurrentAffairs = ql.contains('current affair') || ql.contains('news') ||
        ql.contains('today') || ql.contains('recent') || ql.contains('happen');
    if (_currentAffairs.isNotEmpty && (asksCurrentAffairs || keywords.intersection({'news', 'today'}).isNotEmpty)) {
      ctx.writeln('\n[TODAY\'S TOP CURRENT AFFAIRS]');
      for (final c in _currentAffairs.take(5)) {
        ctx.writeln('• ${c['headline']} — ${c['summary']} [${c['category']}]');
      }
      ctx.writeln('[END CURRENT AFFAIRS]');
    } else if (_currentAffairs.isNotEmpty) {
      // brief mention only
      final headlines = _currentAffairs.take(3).map((c) => c['headline'] as String? ?? '').join('; ');
      ctx.writeln('\n[TODAY\'S NEWS HEADLINES]: $headlines');
    }

    ctx.writeln('[END CONTEXT]');
    ctx.writeln('\n$userQuestion');
    return ctx.toString();
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    _inputController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    try {
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100;
      if (_showScrollDown == atBottom) {
        setState(() => _showScrollDown = !atBottom);
      }
    } catch (_) {}
  }

  void _scrollToBottom({bool animated = true, bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      try {
        final pos = _scrollController.position;
        final nearBottom = pos.pixels >= pos.maxScrollExtent - 200;
        if (force || nearBottom) {
          if (animated) {
            _scrollController.animateTo(
              pos.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(pos.maxScrollExtent);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _isStreaming) return;
    _inputController.clear();
    FocusScope.of(context).unfocus();

    final ts = DateTime.now();
    final userMsg = _Msg(
      id: 'u_${ts.millisecondsSinceEpoch}',
      isUser: true,
      text: text,
      time: ts,
    );
    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
      _isStreaming = true;
    });
    _scrollToBottom(force: true);

    final aiMsg = _Msg(
      id: 'ai_${ts.millisecondsSinceEpoch}',
      isUser: false,
      text: '',
      time: ts,
      isStreaming: true,
    );

    try {
      final buf = StringBuffer();
      final contextualText = _buildContextualPrompt(text);
      await for (final chunk in ApiService.sendChatStream(contextualText)) {
        if (!mounted) break;
        if (_isThinking) {
          setState(() {
            _isThinking = false;
            _messages.add(aiMsg);
          });
        }
        buf.write(chunk);
        setState(() => aiMsg.text = buf.toString());
        _scrollToBottom(animated: false);
      }
    } catch (e) {
      if (!mounted) return;
      if (_isThinking) {
        setState(() {
          _isThinking = false;
          _messages.add(aiMsg);
        });
      }
      setState(() => aiMsg.text = 'Sorry, something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          aiMsg.isStreaming = false;
          _isStreaming = false;
          _isThinking = false;
        });
        _scrollToBottom(force: true);
      }
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('All messages will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _isStreaming = false;
                _isThinking = false;
              });
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAsNote(_Msg msg) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userQ = _messages.where((m) => m.isUser && m.time.isBefore(msg.time)).lastOrNull;
    final defaultTitle = userQ?.text.length != null && userQ!.text.length > 60
        ? '${userQ.text.substring(0, 60)}...'
        : userQ?.text ?? 'AI Note';

    final ctrl = TextEditingController(text: defaultTitle);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save as Note', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Note title', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.indigoBright, foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await FirestoreService.saveAiNote(
        uid: uid,
        title: ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : defaultTitle,
        content: msg.text,
        source: 'ai_tutor',
        subject: _userProfile?.exam ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved!'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f4ff),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _messages.isEmpty && !_isThinking
                    ? _buildEmptyState()
                    : _buildMessageList(),
                if (_showScrollDown)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _scrollToBottom(force: true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.indigoBright,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: AppColors.indigoBright.withValues(alpha: 0.4), blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.indigoBright, Color(0xff0d47a1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('AI Tutor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(_userProfile?.examLabel ?? 'SSC · UPSC · Banking', style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.2)),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Clear chat',
            onPressed: _clearChat,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.indigoBright, Color(0xff0d47a1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(color: AppColors.indigoBright.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ask me anything!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your AI-powered tutor for government exam preparation',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.indigoBright, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('Try asking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(_suggestions.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => _send(_suggestions[i]),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffe0e7ff)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.indigoBright),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _suggestions[i],
                          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.3),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xffcccccc)),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      itemCount: _messages.length + (_isThinking ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _aiAvatar({double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigoBright, Color(0xff0d47a1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: size * 0.6),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _aiAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_dotCtrl.value + i / 3) % 1.0;
                    final bounce = (t < 0.5 ? t * 2 : (1 - t) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.translate(
                        offset: Offset(0, -5 * bounce),
                        child: Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: Color.lerp(const Color(0xffbbbbbb), AppColors.indigoBright, bounce)!,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_Msg msg) {
    return msg.isUser ? _buildUserBubble(msg) : _buildAiBubble(msg);
  }

  Widget _buildUserBubble(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 52),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () => _copyMessage(msg.text),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.indigoBright, Color(0xff1254b3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.indigoBright.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble(_Msg msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, right: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: _aiAvatar()),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copyMessage(msg.text),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.text.isEmpty && msg.isStreaming)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.indigoBright)),
                      )
                    else
                      GptMarkdown(
                        msg.isStreaming ? '${msg.text}▋' : msg.text,
                        style: const TextStyle(fontSize: 14.5, color: AppColors.textPrimary, height: 1.55),
                        useDollarSignsForLatex: false,
                        onLinkTap: (url, _) => launchUrlString(url),
                        tableBuilder: (context, rows, textStyle, config) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xffe0e7ff)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Table(
                              border: TableBorder.all(color: const Color(0xffe0e7ff), width: 0.5),
                              defaultColumnWidth: const FlexColumnWidth(),
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: rows.map((row) => TableRow(
                                decoration: row.isHeader
                                    ? const BoxDecoration(color: Color(0xfff0f4ff))
                                    : null,
                                children: row.fields.map((field) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: GptMarkdown(
                                    field.data,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: row.isHeader ? FontWeight.w600 : FontWeight.w400,
                                      color: AppColors.textPrimary,
                                    ),
                                    useDollarSignsForLatex: false,
                                  ),
                                )).toList(),
                              )).toList(),
                            ),
                          );
                        },
                      ),
                    if (!msg.isStreaming && msg.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _actionBtn(Icons.copy_rounded, 'Copy', () => _copyMessage(msg.text)),
                            const SizedBox(width: 4),
                            _actionBtn(Icons.bookmark_add_outlined, 'Save', () => _saveAsNote(msg)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xffbbbbbb)),
            const SizedBox(width: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xffbbbbbb))),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xfff0f4ff),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xffe0e7ff)),
                  ),
                  child: TextField(
                    controller: _inputController,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Ask anything about your exam...',
                      hintStyle: TextStyle(color: Color(0xffaaaaaa), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _isStreaming ? null : (v) => _send(v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isStreaming
                        ? [Colors.grey.shade300, Colors.grey.shade300]
                        : [AppColors.indigoBright, const Color(0xff0d47a1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isStreaming
                      ? []
                      : [BoxShadow(color: AppColors.indigoBright.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isStreaming ? null : () => _send(_inputController.text),
                    child: Center(
                      child: _isStreaming
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
}
