import 'package:flutter/material.dart';
import 'package:scorvoai/screens/chat_screen.dart';
import 'package:scorvoai/screens/home_screen.dart';
import 'package:scorvoai/screens/learn_screen.dart';
import 'package:scorvoai/screens/quiz_screen.dart';
import 'package:scorvoai/screens/notes_screen.dart';
import 'package:scorvoai/screens/insights_screen.dart';
import 'package:scorvoai/theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    LearnScreen(),
    QuizScreen(),
    NotesScreen(),
    InsightsScreen(),
  ];

  static const _items = [
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.school_rounded, Icons.school_outlined, 'Learn'),
    (Icons.bolt_rounded, Icons.bolt_outlined, 'Quiz'),
    (Icons.note_alt_rounded, Icons.note_alt_outlined, 'Notes'),
    (Icons.insights_rounded, Icons.insights_outlined, 'Insights'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _currentIndex == 0
          ? null  // Home already has AI Tutor in AppBar — avoid duplicate CTA
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChatScreen())),
              backgroundColor: AppColors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.smart_toy_rounded, size: 20),
              label: const Text('Ask AI', style: TextStyle(fontWeight: FontWeight.w700)),
              elevation: 4,
            ),
      // Notes tab has its own FABs on the right — put Ask AI on the left there.
      floatingActionButtonLocation: _currentIndex == 3
          ? FloatingActionButtonLocation.startFloat
          : FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgElevated,
          border: Border(top: BorderSide(color: AppColors.surfaceLine, width: 0.5)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (i) => _navItem(i)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx) {
    final selected = _currentIndex == idx;
    final (activeIcon, inactiveIcon, label) = _items[idx];
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = idx),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.indigo.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : inactiveIcon,
                color: selected ? AppColors.indigoBright : AppColors.textTertiary,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.1,
                  color: selected ? AppColors.indigoBright : AppColors.textTertiary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
