import 'dart:convert';
import 'dart:async';
import 'dart:io' show SocketException, HandshakeException;
import 'package:http/http.dart' as http;
import 'package:scorvoai/config.dart';

// OCR-related endpoints are supported on the backend, but OCR is performed on-device
// via flutter_scalable_ocr. This file now exposes helper methods to upload images
// and classify extracted text on the server.

enum ApiQuizMode { mixed, custom }

class ApiService {
  static const _timeout = Duration(seconds: 30);

  /// Wraps low-level network errors into a human-readable, actionable message.
  static Exception _humanize(Object e, String url) {
    if (e is SocketException) {
      final reason = e.osError?.message ?? e.message;
      // Most likely causes when a connection refuses or times out
      return Exception(
        'Cannot reach backend at $url\n'
        'Reason: $reason\n'
        '• Is the backend running?\n'
        '• Is the IP in lib/config.dart correct? (your laptop\'s current LAN IP)\n'
        '• Started with --host 0.0.0.0 (not 127.0.0.1)?\n'
        '• Phone on the same Wi-Fi as the laptop?'
      );
    }
    if (e is TimeoutException) {
      return Exception('Backend did not respond within 30s at $url\n(Server slow, Ollama loading, or wrong IP)');
    }
    if (e is HandshakeException) {
      return Exception('TLS handshake failed at $url\n(${e.message})');
    }
    return Exception('Network error: $e');
  }

  static Future<Map<String, dynamic>> _request(String path, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$apiBaseUrl$path');
    try {
      final response = body != null
          ? await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(_timeout)
          : await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server returned HTTP ${response.statusCode} for $path: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } on SocketException catch (e) {
      throw _humanize(e, url.toString());
    } on TimeoutException catch (e) {
      throw _humanize(e, url.toString());
    } on HandshakeException catch (e) {
      throw _humanize(e, url.toString());
    } on Exception {
      rethrow; // Already a friendly Exception
    } catch (e) {
      throw _humanize(e, url.toString());
    }
  }

  static Future<String> sendChat(String question) async {
    final res = await _request('/chat', body: {'question': question});
    return res['response'];
  }

  static Stream<String> sendChatStream(String question) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$apiBaseUrl/chat/stream'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'question': question});
      final response = await client.send(request);
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (chunk.isNotEmpty) yield chunk;
      }
    } finally {
      client.close();
    }
  }

  static Future<String> sendSolve(String question) async {
    final res = await _request('/solve', body: {'question': question});
    return res['solution'];
  }

  // Classify extracted text on the backend
  static Future<Map<String, dynamic>> classifyText(String text) async {
    return _request('/notes/classify-text', body: {'extracted_text': text});
  }

  // Format raw OCR text into clean markdown notes via LLM
  static Future<Map<String, dynamic>> formatNote(String text) async {
    return _request('/notes/format-text', body: {'raw_text': text});
  }

  // Upload an image (base64) to the server and obtain an accessible path
  static Future<Map<String, dynamic>> uploadImage(String base64) async {
    return _request('/notes/upload-image', body: {'image_base64': base64});
  }

  static Future<List<dynamic>> getQuiz({
    ApiQuizMode mode = ApiQuizMode.custom,
    List<String>? subjects,
    List<String>? chapters,
    int count = 5,
    String? difficulty,
  }) async {
    final params = <String, String>{
      't': DateTime.now().millisecondsSinceEpoch.toString(),
      'count': count.toString(),
      'ai': 'true',
    };
    if (subjects != null && subjects.isNotEmpty) params['subjects'] = subjects.join(',');
    if (chapters != null && chapters.isNotEmpty) params['chapters'] = chapters.join(',');
    if (difficulty != null) params['difficulty'] = difficulty;

    final uri = Uri.parse('$apiBaseUrl/quiz').replace(queryParameters: params);
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['questions'];
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Stream<Map<String, dynamic>> getQuizStream({
    ApiQuizMode mode = ApiQuizMode.custom,
    List<String>? subjects,
    List<String>? chapters,
    int count = 5,
    String? difficulty,
  }) async* {
    final params = <String, String>{
      't': DateTime.now().millisecondsSinceEpoch.toString(),
      'count': count.toString(),
    };
    if (subjects != null && subjects.isNotEmpty) params['subjects'] = subjects.join(',');
    if (chapters != null && chapters.isNotEmpty) params['chapters'] = chapters.join(',');
    if (difficulty != null) params['difficulty'] = difficulty;

    final uri = Uri.parse('$apiBaseUrl/quiz/stream').replace(queryParameters: params);
    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex);
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '{}') continue;
            try {
              final question = jsonDecode(data) as Map<String, dynamic>;
              yield question;
            } catch (_) {}
          } else if (line.startsWith('event: done')) {
            return;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> submitQuiz(List<Map<String, dynamic>> answers, {String topic = 'mixed'}) async {
    return _request('/quiz/submit', body: {'answers': answers, 'topic': topic});
  }

  static Future<Map<String, dynamic>> getSubjects() async {
    return _request('/quiz/subjects');
  }

  static Future<Map<String, dynamic>> getStats() async {
    return _request('/analyze/stats');
  }

  static Future<Map<String, dynamic>> getAnalysis() async {
    return _request('/analyze');
  }

  static Future<List<dynamic>> getDaily() async {
    final params = {'t': DateTime.now().millisecondsSinceEpoch.toString()};
    final uri = Uri.parse('$apiBaseUrl/daily').replace(queryParameters: params);
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) return jsonDecode(response.body)['questions'];
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> submitDaily(List<Map<String, dynamic>> answers) async {
    return _request('/daily/submit', body: {'answers': answers});
  }

  static Future<List<dynamic>> getNotes() async {
    final res = await _request('/notes');
    return res['notes'] as List;
  }

  static Future<Map<String, dynamic>> getNote(int id) async {
    return _request('/notes/$id');
  }

  static Future<Map<String, dynamic>> createNote({
    required String title,
    required String content,
    String? subject,
    String? chapter,
    String? tags,
    String? imagePath,
  }) async {
    return _request('/notes', body: {
      'title': title,
      'content': content,
      'subject': subject ?? '',
      'chapter': chapter ?? '',
      'tags': tags ?? '',
      'image_path': imagePath ?? '',
    });
  }

  static Future<Map<String, dynamic>> updateNote(int id, {
    String? title,
    String? content,
    String? subject,
    String? chapter,
    String? tags,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (subject != null) body['subject'] = subject;
    if (chapter != null) body['chapter'] = chapter;
    if (tags != null) body['tags'] = tags;
    return _request('/notes/$id', body: body);
  }

  static Future<void> deleteNote(int id) async {
    final url = Uri.parse('$apiBaseUrl/notes/$id');
    try {
      final response = await http.delete(url);
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> ocrAndClassify(String imageBase64) async {
    return _request('/notes/ocr', body: {'image_base64': imageBase64});
  }

  // ── Lessons (AI-generated micro-lessons) ───────────────────────────────
  static Future<Map<String, dynamic>> generateLesson({
    required String subject,
    required String chapter,
    String difficulty = 'medium',
    String exam = '',
  }) async {
    return _request('/lessons', body: {
      'subject': subject,
      'chapter': chapter,
      'difficulty': difficulty,
      'exam': exam,
    });
  }

  static Stream<String> generateLessonStream({
    required String subject,
    required String chapter,
    String difficulty = 'medium',
    String exam = '',
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse('$apiBaseUrl/lessons/stream'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'subject': subject,
        'chapter': chapter,
        'difficulty': difficulty,
        'exam': exam,
      });
      final response = await client.send(request);
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (chunk.isNotEmpty) yield chunk;
      }
    } finally {
      client.close();
    }
  }

  // ── Current Affairs ────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCurrentAffairs({int count = 5, bool refresh = false}) async {
    final params = {'count': count.toString(), if (refresh) 'refresh': 'true'};
    final uri = Uri.parse('$apiBaseUrl/current-affairs').replace(queryParameters: params);
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['items'] ?? []);
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
