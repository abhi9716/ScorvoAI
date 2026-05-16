import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:scorvoai/models/user_profile.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ── User Profile ──────────────────────────────────────────────────────────

  static Future<UserProfile?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  static Future<void> saveProfile(UserProfile p) =>
      _db.collection('users').doc(p.uid).set(p.toMap(), SetOptions(merge: true));

  // ── Quiz Results ──────────────────────────────────────────────────────────

  static Future<void> saveQuizResult({
    required String uid,
    required int score,
    required int total,
    required String topic,
    required List<Map<String, dynamic>> questions,
    String difficulty = 'mixed',
  }) {
    return _db.collection('users').doc(uid).collection('quiz_results').add({
      'score': score,
      'total': total,
      'topic': topic,
      'difficulty': difficulty,
      'pct': total > 0 ? (score / total * 100).roundToDouble() : 0.0,
      'timestamp': FieldValue.serverTimestamp(),
      'questions': questions,
    });
  }

  /// Returns rich insight data computed from Firestore quiz history.
  static Future<Map<String, dynamic>> getInsights(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    if (snap.docs.isEmpty) {
      return {
        'total_quizzes': 0,
        'avg_score': 0.0,
        'best_score': 0.0,
        'weak_topics': <Map<String, dynamic>>[],
        'strong_topics': <Map<String, dynamic>>[],
        'recent_scores': <double>[],
        'topic_breakdown': <String, dynamic>{},
        'streak': 0,
        'total_questions': 0,
        'pass_rate': 0.0,
        'score_distribution': <String, int>{'0-25': 0, '26-50': 0, '51-75': 0, '76-100': 0},
        'daily_activity': <String, int>{},
        'subject_breakdown': <String, dynamic>{},
        'difficulty_breakdown': <String, dynamic>{},
        'chapter_breakdown': <String, dynamic>{},
      };
    }

    final topicData = <String, List<double>>{};
    final allScores = <double>[];
    final dailyDates = <String>{};
    final dailyCount = <String, int>{};
    final scoreDistribution = <String, int>{'0-25': 0, '26-50': 0, '51-75': 0, '76-100': 0};
    int totalQuestions = 0;
    int passCount = 0;

    // Per-question breakdowns
    final subjectData = <String, Map<String, int>>{};
    final difficultyData = <String, Map<String, int>>{};
    final chapterData = <String, Map<String, dynamic>>{};

    for (final doc in snap.docs) {
      final d = doc.data();
      final pct = (d['pct'] as num).toDouble();
      final topic = d['topic'] as String? ?? 'mixed';
      final qTotal = (d['total'] as num?)?.toInt() ?? 0;
      allScores.add(pct);
      topicData.putIfAbsent(topic, () => []).add(pct);
      totalQuestions += qTotal;
      if (pct >= 60) passCount++;
      if (pct <= 25) scoreDistribution['0-25'] = scoreDistribution['0-25']! + 1;
      else if (pct <= 50) scoreDistribution['26-50'] = scoreDistribution['26-50']! + 1;
      else if (pct <= 75) scoreDistribution['51-75'] = scoreDistribution['51-75']! + 1;
      else scoreDistribution['76-100'] = scoreDistribution['76-100']! + 1;

      final ts = d['timestamp'] as Timestamp?;
      if (ts != null) {
        final day = ts.toDate();
        dailyDates.add('${day.year}-${day.month}-${day.day}');
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        dailyCount[dayKey] = (dailyCount[dayKey] ?? 0) + 1;
      }

      // Per-question breakdown
      final questions = (d['questions'] as List?) ?? [];
      for (final qRaw in questions) {
        if (qRaw is! Map) continue;
        final q = Map<String, dynamic>.from(qRaw);
        final subject = (q['subject'] as String?)?.trim().isNotEmpty == true
            ? (q['subject'] as String).trim()
            : 'Mixed';
        final chapter = (q['chapter'] as String?)?.trim().isNotEmpty == true
            ? (q['chapter'] as String).trim()
            : 'General';
        final diff = (q['difficulty'] as String?)?.toLowerCase().trim() ?? 'mixed';
        final isCorrect = q['is_correct'] as bool? ?? false;

        subjectData.putIfAbsent(subject, () => {'total': 0, 'correct': 0});
        subjectData[subject]!['total'] = subjectData[subject]!['total']! + 1;
        if (isCorrect) subjectData[subject]!['correct'] = subjectData[subject]!['correct']! + 1;

        difficultyData.putIfAbsent(diff, () => {'total': 0, 'correct': 0});
        difficultyData[diff]!['total'] = difficultyData[diff]!['total']! + 1;
        if (isCorrect) difficultyData[diff]!['correct'] = difficultyData[diff]!['correct']! + 1;

        chapterData.putIfAbsent(chapter, () => <String, dynamic>{'total': 0, 'correct': 0, 'subject': subject});
        chapterData[chapter]!['total'] = (chapterData[chapter]!['total'] as int) + 1;
        if (isCorrect) chapterData[chapter]!['correct'] = (chapterData[chapter]!['correct'] as int) + 1;
      }
    }

    // Streak
    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      if (dailyDates.contains('${d.year}-${d.month}-${d.day}')) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }

    final topicAvg = topicData.map((k, v) {
      final avg = v.reduce((a, b) => a + b) / v.length;
      return MapEntry(k, {'avg': double.parse(avg.toStringAsFixed(1)), 'attempts': v.length});
    });

    final weak = topicAvg.entries
        .where((e) => (e.value['avg'] as double) < 60)
        .map((e) => {'topic': e.key, 'avg': e.value['avg'], 'attempts': e.value['attempts']})
        .toList()
      ..sort((a, b) => (a['avg'] as double).compareTo(b['avg'] as double));

    final strong = topicAvg.entries
        .where((e) => (e.value['avg'] as double) >= 60)
        .map((e) => {'topic': e.key, 'avg': e.value['avg'], 'attempts': e.value['attempts']})
        .toList()
      ..sort((a, b) => (b['avg'] as double).compareTo(a['avg'] as double));

    final avg = allScores.reduce((a, b) => a + b) / allScores.length;
    final best = allScores.reduce((a, b) => a > b ? a : b);
    final recent = allScores.take(20).toList().reversed.toList();
    final passRate = double.parse((passCount / allScores.length * 100).toStringAsFixed(1));

    // Compute per-question averages
    final subjectBreakdown = subjectData.map((k, v) {
      final t = v['total']!;
      final c = v['correct']!;
      return MapEntry(k, {'total': t, 'correct': c, 'avg': t > 0 ? double.parse((c / t * 100).toStringAsFixed(1)) : 0.0});
    });

    final difficultyBreakdown = difficultyData.map((k, v) {
      final t = v['total']!;
      final c = v['correct']!;
      return MapEntry(k, {'total': t, 'correct': c, 'avg': t > 0 ? double.parse((c / t * 100).toStringAsFixed(1)) : 0.0});
    });

    final chapterBreakdown = chapterData.map((k, v) {
      final t = v['total'] as int;
      final c = v['correct'] as int;
      return MapEntry(k, {
        'total': t,
        'correct': c,
        'avg': t > 0 ? double.parse((c / t * 100).toStringAsFixed(1)) : 0.0,
        'subject': v['subject'],
      });
    });

    return {
      'total_quizzes': snap.docs.length,
      'avg_score': double.parse(avg.toStringAsFixed(1)),
      'best_score': double.parse(best.toStringAsFixed(1)),
      'weak_topics': weak,
      'strong_topics': strong,
      'recent_scores': recent,
      'topic_breakdown': topicAvg,
      'streak': streak,
      'total_questions': totalQuestions,
      'pass_rate': passRate,
      'score_distribution': scoreDistribution,
      'daily_activity': dailyCount,
      'subject_breakdown': subjectBreakdown,
      'difficulty_breakdown': difficultyBreakdown,
      'chapter_breakdown': chapterBreakdown,
    };
  }

  // ── Saved Notes ───────────────────────────────────────────────────────────

  static Future<String> saveAiNote({
    required String uid,
    required String title,
    required String content,
    required String source,
    String subject = '',
  }) async {
    final ref = await _db.collection('users').doc(uid).collection('ai_notes').add({
      'title': title,
      'content': content,
      'source': source,
      'subject': subject,
      'created_at': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Stream<List<Map<String, dynamic>>> aiNotesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('ai_notes')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((e) {
          // Return empty list on error (e.g. missing index)
          return <Map<String, dynamic>>[];
        });
  }

  static Future<void> deleteAiNote(String uid, String noteId) =>
      _db.collection('users').doc(uid).collection('ai_notes').doc(noteId).delete();

  static Future<void> updateAiNote({
    required String uid,
    required String noteId,
    required String title,
    required String content,
  }) =>
      _db.collection('users').doc(uid).collection('ai_notes').doc(noteId).update({
        'title': title,
        'content': content,
        'updated_at': FieldValue.serverTimestamp(),
      });

  static Future<List<Map<String, dynamic>>> getRecentAiNotes(String uid, {int limit = 5}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('ai_notes')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ── Lessons (shared cache + per-user history) ─────────────────────────

  static String _lessonKey(String subject, String chapter, String difficulty) {
    final clean = (String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return '${clean(subject)}__${clean(chapter)}__${clean(difficulty)}';
  }

  /// Returns cached lesson content if available, else null.
  static Future<Map<String, dynamic>?> getCachedLesson({
    required String subject,
    required String chapter,
    required String difficulty,
  }) async {
    final key = _lessonKey(subject, chapter, difficulty);
    final doc = await _db.collection('lessons').doc(key).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  /// Saves a generated lesson to the shared cache.
  static Future<void> cacheLesson({
    required String subject,
    required String chapter,
    required String difficulty,
    required String content,
    String exam = '',
  }) async {
    final key = _lessonKey(subject, chapter, difficulty);
    await _db.collection('lessons').doc(key).set({
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty,
      'exam': exam,
      'content': content,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Records that the user viewed a lesson (for personalisation + history).
  static Future<void> recordLessonView({
    required String uid,
    required String subject,
    required String chapter,
    required String difficulty,
  }) async {
    final key = _lessonKey(subject, chapter, difficulty);
    await _db.collection('users').doc(uid).collection('viewed_lessons').doc(key).set({
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty,
      'last_viewed': FieldValue.serverTimestamp(),
      'view_count': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getRecentLessons(String uid, {int limit = 5}) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('viewed_lessons')
        .orderBy('last_viewed', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  // ── Daily Learning (personalised per-user) ────────────────────────────

  /// Returns today's daily lesson record (cached for the day).
  static Future<Map<String, dynamic>?> getTodayDailyLesson(String uid) async {
    final today = _todayKey();
    final doc = await _db.collection('users').doc(uid).collection('daily_lessons').doc(today).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  static Future<void> saveTodayDailyLesson({
    required String uid,
    required String subject,
    required String chapter,
    required String difficulty,
    required String content,
  }) async {
    final today = _todayKey();
    await _db.collection('users').doc(uid).collection('daily_lessons').doc(today).set({
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty,
      'content': content,
      'date': today,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Current Affairs (shared cache per-day) ────────────────────────────

  static Future<List<Map<String, dynamic>>?> getTodayCurrentAffairs() async {
    final today = _todayKey();
    final doc = await _db.collection('current_affairs').doc(today).get();
    if (!doc.exists) return null;
    final items = doc.data()?['items'] as List?;
    if (items == null) return null;
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> saveTodayCurrentAffairs(List<Map<String, dynamic>> items) async {
    final today = _todayKey();
    await _db.collection('current_affairs').doc(today).set({
      'date': today,
      'items': items,
      'generated_at': FieldValue.serverTimestamp(),
    });
  }
}
