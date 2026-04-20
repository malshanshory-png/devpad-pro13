// lib/widgets/quick_keys.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class QuickKeys extends StatelessWidget {
  final EditorController ctrl;
  const QuickKeys({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final lang = ctrl.activeFile.lang;
    return Container(
      height: 44,
      color: T.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          // Universal — indent
          _QK('⇥', () => ctrl.insertAtCursor(' ' * ctrl.settings.tabSize)),
          _Sep(),

          // Bracket wraps
          _QK('{  }', () => ctrl.wrapSelection('{', '}')),
          _QK('(  )', () => ctrl.wrapSelection('(', ')')),
          _QK('[  ]', () => ctrl.wrapSelection('[', ']')),
          _QK('" "', () => ctrl.wrapSelection('"', '"')),
          _QK("' '", () => ctrl.wrapSelection("'", "'")),
          _QK('` `', () => ctrl.wrapSelection('`', '`')),
          _Sep(),

          // Language-specific
          if (lang == Language.html) ...[
            _QK('<div>', () => ctrl.insertAtCursor('<div></div>')),
            _QK('<p>',   () => ctrl.insertAtCursor('<p></p>')),
            _QK('<span>',() => ctrl.insertAtCursor('<span></span>')),
            _QK('class=""', () => ctrl.insertAtCursor(' class=""')),
            _QK('id=""',    () => ctrl.insertAtCursor(' id=""')),
            _Sep(),
          ],
          if (lang == Language.css) ...[
            _QK('px',    () => ctrl.insertAtCursor('px')),
            _QK('rem',   () => ctrl.insertAtCursor('rem')),
            _QK('%',     () => ctrl.insertAtCursor('%')),
            _QK('var(--)', () => ctrl.insertAtCursor('var(--)')),
            _Sep(),
          ],
          if (lang == Language.js || lang == Language.ts) ...[
            _QK('=>',  () => ctrl.insertAtCursor(' => ')),
            _QK('===', () => ctrl.insertAtCursor(' === ')),
            _QK('!==', () => ctrl.insertAtCursor(' !== ')),
            _QK('?.', () => ctrl.insertAtCursor('?.')),
            _QK('??', () => ctrl.insertAtCursor(' ?? ')),
            _QK('&&', () => ctrl.insertAtCursor(' && ')),
            _QK('||', () => ctrl.insertAtCursor(' || ')),
            _Sep(),
          ],

          // Operators
          _QK(';', () => ctrl.insertAtCursor(';')),
          _QK(':', () => ctrl.insertAtCursor(': ')),
          _QK('=', () => ctrl.insertAtCursor(' = ')),
          _QK('!', () => ctrl.insertAtCursor('!')),
          _QK('+', () => ctrl.insertAtCursor(' + ')),
          _QK('-', () => ctrl.insertAtCursor(' - ')),
          _Sep(),

          // Edit operations
          _QK('//',   ctrl.commentLine),
          _QK('dup↓', ctrl.duplicateLine),
          _QK('↑ln',  () => ctrl.moveLine(-1)),
          _QK('↓ln',  () => ctrl.moveLine(1)),
          _QK('→in',  () => ctrl.indentLine(1)),
          _QK('←in',  () => ctrl.indentLine(-1)),
          _QK('del',  ctrl.deleteLine),
          _Sep(),

          _QK('fmt',  ctrl.formatCode),
          _QK('undo', ctrl.undo),
          _QK('redo', ctrl.redo),
        ],
      ),
    );
  }
}

class _QK extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QK(this.label, this.onTap);

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: T.surface2,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: T.border2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: T.textMid,
            fontFamily: 'monospace',
            fontSize: 11.5,
          ),
        ),
      ),
    ),
  );
}

class _Sep extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Container(
    width: 1, height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    color: T.border2,
  );
}
