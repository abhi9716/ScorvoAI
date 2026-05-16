import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'simple_search_service.dart';

class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  final _search = SimpleSearchService();
  RagService._internal();

  Future<void> initialize() async {
    await _search.load();
  }

  Future<String> addNote(String title, String content) async {
    final id = 'note_${title.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    await _search.addDocument(id, title, content, {'type': 'note', 'title': title});
    return id;
  }

  Future<void> addSyllabus(String content, String subject) async {
    final id = 'syllabus_${subject.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    await _search.addDocument(id, subject, content, {'type': 'syllabus', 'subject': subject});
  }

  Future<void> removeNote(String sourceId) async {
    await _search.removeDocument(sourceId);
  }

  Future<String> getContextForQuery(String query, {int topK = 3}) async {
    return await _search.getContextForQuery(query, topK: topK);
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _search.getStats();
  }

  Future<List<Map<String, dynamic>>> searchNotes(String query, {int topK = 3}) async {
    return await _search.search(query, topK: topK);
  }
}