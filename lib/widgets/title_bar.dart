// lib/widgets/title_bar.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';

class TitleBar extends StatelessWidget {
  final EditorController ctrl;
  final VoidCallback onPickFile, onShowSamples, onShowSettings, onShowPreview;
  const TitleBar({
    super.key,
    required this.ctrl,
    required this.onPickFile,
    required this.onShowSamples,
    required this.onShowSettings,
    required this.onShowPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: T.bg2,
      child: Row(children: [
        // Sidebar toggle
        _TBtn(icon: Icons.menu_rounded, onTap: ctrl.toggleSidebar, tt: 'Explorer'),

        // App logo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [BoxShadow(color: Color(0x403B82F6), blurRadius: 8)],
            ),
            child: const Center(
              child: Text(
                '✦',
                style: TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),

        // Active file name
        Expanded(
          child: Center(
            child: Text(
              ctrl.activeFile.name,
              style: TextStyle(
                color: T.textMid, fontSize: 11.5, fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        _TBtn(icon: Icons.folder_open_outlined,  onTap: onPickFile,      tt: 'Open File'),
        _TBtn(icon: Icons.grid_view_outlined,    onTap: onShowSamples,   tt: 'Samples'),
        _TBtn(icon: Icons.search,                onTap: ctrl.toggleFind, tt: 'Find (Ctrl+F)'),
        _TBtn(icon: Icons.web_outlined,          onTap: onShowPreview,   tt: 'Preview'),
        _TBtn(
          icon:  Icons.vertical_split_outlined,
          onTap: ctrl.toggleSplit,
          tt:    ctrl.splitMode ? 'Close Split' : 'Split View',
          active: ctrl.splitMode,
        ),
        _TBtn(icon: Icons.settings_outlined,     onTap: onShowSettings,  tt: 'Settings'),

        // Run button
        GestureDetector(
          onTap: ctrl.runCode,
          child: Container(
            width: 34, height: 34,
            margin: const EdgeInsets.only(right: 8, left: 2),
            decoration: BoxDecoration(
              color: T.accent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x403B82F6), blurRadius: 10)],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }
}

class _TBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tt;
  final bool active;
  const _TBtn({
    required this.icon, required this.onTap,
    required this.tt,   this.active = false});

  @override
  Widget build(BuildContext ctx) => Tooltip(
    message: tt,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 36, height: 46,
        child: Icon(icon, color: active ? T.accent : T.textMid, size: 17),
      ),
    ),
  );
}
