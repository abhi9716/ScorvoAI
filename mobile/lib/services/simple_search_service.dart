import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SimpleSearchService {
  static final SimpleSearchService _instance = SimpleSearchService._internal();
  factory SimpleSearchService() => _instance;
  SimpleSearchService._internal();

  final Map<String, Map<String, double>> _docVectors = {};
  final Map<String, String> _docContent = {};
  final Map<String, Map<String, dynamic>> _docMeta = {};

  Future<String> get _dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/simple_search.json';
  }

  Future<void> addDocument(String id, String title, String content, Map<String, dynamic> metadata) async {
    final fullText = 'Title: $title\n\n$content';
    _docContent[id] = fullText;
    _docMeta[id] = metadata;
    _updateVector(id, fullText);
    await _save();
  }

  Future<void> removeDocument(String id) async {
    _docVectors.remove(id);
    _docContent.remove(id);
    _docMeta.remove(id);
    await _save();
  }

  void _updateVector(String id, String text) {
    final words = _tokenize(text);
    final tf = <String, double>{};
    for (var w in words) {
      tf[w] = (tf[w] ?? 0) + 1;
    }
    final vector = <String, double>{};
    tf.forEach((w, count) {
      vector[w] = count / words.length;
    });
    _docVectors[id] = vector;
  }

  List<String> _tokenize(String text) {
    return text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();
  }

  Future<List<Map<String, dynamic>>> search(String query, {int topK = 3}) async {
    final qWords = _tokenize(query);
    if (qWords.isEmpty) return [];

    final scores = <String, double>{};
    for (var entry in _docVectors.entries) {
      var score = 0.0;
      for (var w in qWords) {
        if (entry.value.containsKey(w)) {
          score += entry.value[w]!;
        }
      }
      if (score > 0) scores[entry.key] = score;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted.take(topK).map((e) => {
      'id': e.key,
      'text': _docContent[e.key] ?? '',
      'score': e.value,
      'metadata': _docMeta[e.key] ?? {},
    }).toList();
  }

  Future<String> getContextForQuery(String query, {int topK = 3}) async {
    final results = await search(query, topK: topK);
    if (results.isEmpty) return '';
    
    final contextParts = results.map((r) {
      final meta = r['metadata'] as Map<String, dynamic>;
      final type = meta['type'] ?? 'note';
      final title = meta['title'] ?? 'Untitled';
      return '[From my $type: $title]\n${r['text']}';
    }).toList();
    
    return contextParts.join('\n\n---\n\n');
  }

  Future<void> _save() async {
    try {
      final file = File(await _dbPath);
      final data = {
        'vectors': _docVectors,
        'content': _docContent,
        'meta': _docMeta,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Save error: $e');
    }
  }

  Future<void> load() async {
    try {
      final file = File(await _dbPath);
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _docVectors.clear();
        _docContent.clear();
        _docMeta.clear();
        
        (data['vectors'] as Map).forEach((k, v) {
          _docVectors[k.toString()] = Map<String, double>.from(v);
        });
        (data['content'] as Map).forEach((k, v) => 
          _docContent[k.toString()] = v.toString());
        (data['meta'] as Map).forEach((k, v) => 
          _docMeta[k.toString()] = Map<String, dynamic>.from(v));
      }
    } catch (e) {
      print('Load error: $e');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    return {
      'docCount': _docContent.length,
      'chunkCount': _docVectors.length,
    };
  }
}