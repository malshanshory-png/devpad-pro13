// lib/widgets/tabs_row.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class TabsRow extends StatelessWidget {
  final EditorController ctrl;
  const TabsRow({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: T.bg2,
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ctrl.files.map((f) {
              final isActive = f.id == ctrl.activeId;
              return GestureDetector(
                onTap: () => ctrl.switchFile(f.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isActive ? T.surface : Colors.transparent,
                    border: Border(
                      right: BorderSide(color: T.border, width: 1),
                      bottom: isActive
                          ? BorderSide(color: T.accent, width: 2)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7, height: 7,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: f.lang.color,
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                      ),
                      Text(
                        f.name,
                        style: TextStyle(
                          color: isActive ? T.text : T.textDim,
                          fontSize: 11.5, fontFamily: 'monospace',
                        ),
                      ),
                      // Unsaved indicator dot
                      if (f.dirty)
                        Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: T.orange,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      // Close button (only when more than 1 file open)
                      if (ctrl.files.length > 1)
                        GestureDetector(
                          onTap: () => ctrl.closeFile(f.id),
                          child: Container(
                            margin: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.close, size: 12, color: T.textDim),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // New file button
        GestureDetector(
          onTap: () => _showNewFileDialog(context, ctrl),
          child: Container(
            width: 36, height: 36,
            child: Icon(Icons.add, color: T.textDim, size: 18),
          ),
        ),
      ]),
    );
  }

  void _showNewFileDialog(BuildContext context, EditorController ctrl) {
    final nameCtrl = TextEditingController(text: 'new.js');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: T.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: T.border2),
        ),
        title: Text('New File', style: TextStyle(color: T.text, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: T.text, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'filename.html',
            hintStyle: TextStyle(color: T.textDim),
            filled: true,
            fillColor: T.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: T.border2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: T.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: T.textMid)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                final ext  = name.contains('.') ? name.split('.').last : 'txt';
                final lang = languageFromExtension(ext);
                ctrl.addNewFile(name, lang);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: T.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
