import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:scorvoai/services/firestore_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _search = '';
  String _filter = 'All';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> notes) {
    var list = notes;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((n) =>
        (n['title'] as String? ?? '').toLowerCase().contains(q) ||
        (n['content'] as String? ?? '').toLowerCase().contains(q)
      ).toList();
    }
    const sourceMap = {'AI Tutor': 'ai_tutor', 'Manual': 'manual', 'Scanned': 'ocr_scan'};
    if (_filter != 'All') {
      final src = sourceMap[_filter];
      if (src != null) list = list.where((n) => n['source'] == src).toList();
    }
    return list;
  }

  Future<void> _createManualNote() async {
    final uid = _uid;
    if (uid == null) return;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NoteEditorSheet(
        sheetTitle: 'New Note',
        titleCtrl: titleCtrl,
        contentCtrl: contentCtrl,
        onSave: () => FirestoreService.saveAiNote(
          uid: uid,
          title: titleCtrl.text.trim().isEmpty ? 'Untitled Note' : titleCtrl.text.trim(),
          content: contentCtrl.text.trim(),
          source: 'manual',
        ),
      ),
    );
  }

  Future<void> _scanOCR(ImageSource source) async {
    final uid = _uid;
    if (uid == null) return;
    XFile? image;
    try {
      image = await ImagePicker().pickImage(source: source, imageQuality: 85);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating));
      return;
    }
    if (image == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))),
    );

    try {
      String text = '';
      if (Platform.isAndroid || Platform.isIOS) {
        final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
        text = (await recognizer.processImage(InputImage.fromFilePath(image.path))).text;
        recognizer.close();
      }
      if (!mounted) return;
      Navigator.pop(context);

      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text found in image'), behavior: SnackBarBehavior.floating),
        );
        return;
      }

      final titleCtrl = TextEditingController(text: 'Scanned Note');
      final contentCtrl = TextEditingController(text: text);
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _NoteEditorSheet(
          sheetTitle: 'Review Scanned Note',
          titleCtrl: titleCtrl,
          contentCtrl: contentCtrl,
          onSave: () => FirestoreService.saveAiNote(
            uid: uid,
            title: titleCtrl.text.trim().isEmpty ? 'Scanned Note' : titleCtrl.text.trim(),
            content: contentCtrl.text.trim(),
            source: 'ocr_scan',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OCR error: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _openNote(Map<String, dynamic> note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NoteDetailSheet(
        note: note,
        onDelete: () async {
          final uid = _uid;
          if (uid == null) return;
          Navigator.pop(ctx);
          await FirestoreService.deleteAiNote(uid, note['id'] as String);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note deleted'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
            );
          }
        },
        onEdit: () async {
          Navigator.pop(ctx);
          final uid = _uid;
          if (uid == null) return;
          final titleCtrl = TextEditingController(text: note['title'] as String? ?? '');
          final contentCtrl = TextEditingController(text: note['content'] as String? ?? '');
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => _NoteEditorSheet(
              sheetTitle: 'Edit Note',
              titleCtrl: titleCtrl,
              contentCtrl: contentCtrl,
              onSave: () => FirestoreService.updateAiNote(
                uid: uid,
                noteId: note['id'] as String,
                title: titleCtrl.text.trim(),
                content: contentCtrl.text.trim(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: const Color(0xfff5f7fa),
      appBar: AppBar(
        title: const Text('My Notes', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xfff5f7fa),
        foregroundColor: const Color(0xff1a1a2e),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xffaaaaaa)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: ['All', 'AI Tutor', 'Manual', 'Scanned'].map((f) {
                  final selected = _filter == f;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xff1a73e8) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? const Color(0xff1a73e8) : const Color(0xffe0e7ff)),
                        boxShadow: selected ? [BoxShadow(color: const Color(0xff1a73e8).withValues(alpha: 0.25), blurRadius: 6)] : [],
                      ),
                      child: Text(f, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xff666666))),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Sign in to see your notes'))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: FirestoreService.aiNotesStream(uid),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final all = snap.data ?? [];
                        final filtered = _applyFilters(all);

                        if (all.isEmpty) return _emptyState();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: Color(0xffcccccc)),
                                const SizedBox(height: 12),
                                Text('No results for "$_search"', style: const TextStyle(fontSize: 15, color: Color(0xff999999))),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _noteCard(filtered[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) ...[
            FloatingActionButton.small(
              heroTag: 'cam',
              onPressed: () => _scanOCR(ImageSource.camera),
              backgroundColor: const Color(0xff9c27b0),
              tooltip: 'Scan with camera',
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton.small(
            heroTag: 'gal',
            onPressed: () => _scanOCR(ImageSource.gallery),
            backgroundColor: const Color(0xff34a853),
            tooltip: 'Scan from gallery',
            child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: _createManualNote,
            backgroundColor: const Color(0xff1a73e8),
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            label: const Text('New Note', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final title = note['title'] as String? ?? 'Untitled';
    final content = note['content'] as String? ?? '';
    final source = note['source'] as String? ?? 'manual';
    final subject = note['subject'] as String? ?? '';
    final ts = note['created_at'];
    final date = ts is Timestamp ? _fmtDate(ts.toDate()) : '';
    final cfg = _sourceCfg(source);

    return Dismissible(
      key: Key(note['id'] as String? ?? title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_rounded, color: Colors.red, size: 26),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete note?'),
          content: const Text('This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
      onDismissed: (_) async {
        final uid = _uid;
        if (uid != null) await FirestoreService.deleteAiNote(uid, note['id'] as String);
      },
      child: GestureDetector(
        onTap: () => _openNote(note),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: cfg.$2, width: 4)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(date, style: const TextStyle(fontSize: 11, color: Color(0xffaaaaaa))),
                ],
              ),
              const SizedBox(height: 4),
              Text(content, style: const TextStyle(fontSize: 13, color: Color(0xff666666), height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  _badge(cfg.$1, cfg.$2, cfg.$3),
                  if (subject.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _badge(subject, const Color(0xff1a73e8), Icons.book_rounded),
                  ],
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xffcccccc)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  (String, Color, IconData) _sourceCfg(String s) {
    switch (s) {
      case 'ai_tutor': return ('AI Tutor', const Color(0xff1a73e8), Icons.smart_toy_rounded);
      case 'quiz_explanation': return ('Quiz', const Color(0xfffbbc05), Icons.quiz_rounded);
      case 'ocr_scan': return ('Scanned', const Color(0xff9c27b0), Icons.document_scanner_rounded);
      default: return ('Manual', const Color(0xff34a853), Icons.edit_note_rounded);
    }
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(color: const Color(0xff1a73e8).withValues(alpha: 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.note_alt_rounded, size: 48, color: Color(0xff1a73e8)),
            ),
            const SizedBox(height: 20),
            const Text('No notes yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e))),
            const SizedBox(height: 8),
            const Text('Save AI Tutor answers, scan handwritten notes, or write your own', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xff666666), height: 1.5)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _emptyHint(Icons.smart_toy_rounded, 'AI Tutor', const Color(0xff1a73e8)),
                const SizedBox(width: 16),
                _emptyHint(Icons.document_scanner_rounded, 'Scan', const Color(0xff9c27b0)),
                const SizedBox(width: 16),
                _emptyHint(Icons.edit_note_rounded, 'Write', const Color(0xff34a853)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Note Detail Sheet ─────────────────────────────────────────────────────────

class _NoteDetailSheet extends StatelessWidget {
  final Map<String, dynamic> note;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _NoteDetailSheet({required this.note, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final title = note['title'] as String? ?? 'Untitled';
    final content = note['content'] as String? ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xff1a1a2e)))),
                  IconButton(icon: const Icon(Icons.edit_rounded, color: Color(0xff1a73e8), size: 22), onPressed: onEdit, tooltip: 'Edit'),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Color(0xff666666), size: 20),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22), onPressed: onDelete, tooltip: 'Delete'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: SelectableText(
                  content,
                  style: const TextStyle(fontSize: 15, color: Color(0xff333333), height: 1.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Note Editor Sheet ─────────────────────────────────────────────────────────

class _NoteEditorSheet extends StatefulWidget {
  final String sheetTitle;
  final TextEditingController titleCtrl;
  final TextEditingController contentCtrl;
  final Future<void> Function() onSave;

  const _NoteEditorSheet({
    required this.sheetTitle,
    required this.titleCtrl,
    required this.contentCtrl,
    required this.onSave,
  });

  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Text(widget.sheetTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e))),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Color(0xff999999)))),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _saving ? null : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onSave();
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setState(() => _saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1a73e8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: TextField(
                controller: widget.titleCtrl,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xff1a1a2e)),
                decoration: const InputDecoration(
                  hintText: 'Title...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color(0xffcccccc), fontWeight: FontWeight.w400),
                ),
              ),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 120,
                maxHeight: MediaQuery.of(context).size.height * 0.42,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: TextField(
                  controller: widget.contentCtrl,
                  maxLines: null,
                  autofocus: widget.contentCtrl.text.isEmpty,
                  style: const TextStyle(fontSize: 15, color: Color(0xff333333), height: 1.6),
                  decoration: const InputDecoration(
                    hintText: 'Write your note here...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Color(0xffcccccc)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
