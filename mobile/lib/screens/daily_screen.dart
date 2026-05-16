import 'package:flutter/material.dart';
import 'package:scorvoai/services/api.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  List<dynamic> _questions = [];
  final _answers = <int, int>{};
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _questions = await ApiService.getDaily();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final answers = _answers.entries.map((e) => {'question_index': e.key, 'selected_option': e.value}).toList();
    setState(() => _submitting = true);
    try {
      _result = await ApiService.submitDaily(answers);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_result != null) {
      final score = _result!['score'] as int;
      final total = _result!['total'] as int;
      final pct = ((score / total) * 100).round();
      return Scaffold(
        backgroundColor: const Color(0xfff5f7fa),
        appBar: AppBar(title: const Text('Daily Result'), backgroundColor: const Color(0xffea4335), foregroundColor: Colors.white),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Daily Challenge Done!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 24),
                  Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xffea4335), shape: BoxShape.circle), alignment: Alignment.center, child: Text('$score/$total', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(height: 16),
                  Text('$pct%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xff666666))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(title: const Text('Daily Challenge'), backgroundColor: const Color(0xffea4335), foregroundColor: Colors.white),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Challenge', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('New questions every day!', style: TextStyle(fontSize: 15, color: Color(0xff666666))),
              const SizedBox(height: 20),
              ..._questions.asMap().entries.map((e) {
                final idx = e.key;
                final q = e.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${idx + 1}. ${q['question']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(q['subject'], style: const TextStyle(fontSize: 12, color: Color(0xffea4335), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ...List.generate((q['options'] as List).length, (oi) {
                          final selected = _answers[idx] == oi;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: SizedBox(
                              width: double.infinity,
                              child: Material(
                                color: selected ? const Color(0xffea4335) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() => _answers[idx] = oi),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    child: Text('${String.fromCharCode(65 + oi)}. ${(q['options'] as List)[oi]}', style: TextStyle(fontSize: 15, color: selected ? Colors.white : const Color(0xff333333), fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffea4335), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
