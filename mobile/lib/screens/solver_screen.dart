import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:scorvoai/services/api.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SolverScreen extends StatefulWidget {
  const SolverScreen({super.key});

  @override
  State<SolverScreen> createState() => _SolverScreenState();
}

class _SolverScreenState extends State<SolverScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _solution;
  bool _loading = false;
  bool _scanning = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _solve() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _solution = null;
    });
    try {
      _solution = await ApiService.sendSolve(q);
    } catch (e) {
      _solution = 'Error: $e';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _scanImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source, imageQuality: 90);
      if (image == null) return;
      setState(() => _scanning = true);
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final recognized = await recognizer.processImage(inputImage);
        final text = recognized.text.trim();
        if (text.isNotEmpty) {
          _controller.text = text;
          _controller.selection = TextSelection.collapsed(offset: text.length);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No text found in the image'), behavior: SnackBarBehavior.floating),
            );
          }
        }
      } finally {
        recognizer.close();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _copy() {
    if (_solution == null) return;
    Clipboard.setData(ClipboardData(text: _solution!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Solution copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff0f4ff),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff34a853), Color(0xff1b7a3e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Question Solver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Step-by-step solutions',
                    style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.2)),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_solution != null)
            IconButton(icon: const Icon(Icons.copy_rounded), tooltip: 'Copy solution', onPressed: _copy),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: Color(0xff34a853), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Enter your question',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xff1a1a2e))),
                      ),
                      // OCR scan buttons
                      if (_scanning)
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff34a853)),
                        )
                      else ...[
                        Tooltip(
                          message: 'Scan with camera',
                          child: InkWell(
                            onTap: () => _scanImage(ImageSource.camera),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xff34a853).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Color(0xff34a853), size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Pick from gallery',
                          child: InkWell(
                            onTap: () => _scanImage(ImageSource.gallery),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xff1a73e8).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.photo_library_rounded, color: Color(0xff1a73e8), size: 20),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_scanning)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Scanning image for text...',
                          style: TextStyle(fontSize: 12, color: Color(0xff34a853))),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a question or use the camera to scan it...',
                      hintStyle: const TextStyle(color: Color(0xffaaaaaa), fontSize: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffe0e7ff)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xffe0e7ff)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xff34a853), width: 2),
                      ),
                      filled: true,
                      fillColor: const Color(0xfff8fff9),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading || _scanning ? null : _solve,
                      icon: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _loading ? 'Solving...' : 'Solve Step-by-Step',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff34a853),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        shadowColor: const Color(0xff34a853).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_loading)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xff34a853).withValues(alpha: 0.2), blurRadius: 20)],
                        ),
                        child: const CircularProgressIndicator(color: Color(0xff34a853), strokeWidth: 3),
                      ),
                      const SizedBox(height: 16),
                      const Text('Solving your question...',
                          style: TextStyle(fontSize: 15, color: Color(0xff666666), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      const Text('This may take a few seconds',
                          style: TextStyle(fontSize: 13, color: Color(0xffaaaaaa))),
                    ],
                  ),
                ),
              ),

            if (_solution != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff34a853).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xff34a853), size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Solution',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e))),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xff34a853)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffe0f0e8)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: GptMarkdown(
                  _solution!,
                  style: const TextStyle(fontSize: 14.5, color: Color(0xff1a1a2e), height: 1.6),
                  useDollarSignsForLatex: false,
                  onLinkTap: (url, _) => launchUrlString(url),
                  tableBuilder: (context, rows, textStyle, config) {
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xffe0f0e8)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Table(
                        border: TableBorder.all(color: const Color(0xffe0f0e8), width: 0.5),
                        defaultColumnWidth: const FlexColumnWidth(),
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: rows
                            .map((row) => TableRow(
                                  decoration: row.isHeader
                                      ? const BoxDecoration(color: Color(0xfff0fff4))
                                      : null,
                                  children: row.fields
                                      .map((field) => Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: GptMarkdown(
                                              field.data,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: row.isHeader ? FontWeight.w600 : FontWeight.w400,
                                                color: const Color(0xff333333),
                                              ),
                                              useDollarSignsForLatex: false,
                                            ),
                                          ))
                                      .toList(),
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _controller.clear();
                    setState(() => _solution = null);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Solve Another Question',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff34a853),
                    side: const BorderSide(color: Color(0xff34a853)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
