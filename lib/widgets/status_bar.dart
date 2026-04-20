// lib/widgets/status_bar.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class StatusBar extends StatefulWidget {
  final EditorController ctrl;
  const StatusBar({super.key, required this.ctrl});
  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  int _ln = 1, _col = 1, _sel = 0;

  TextEditingController? _trackedTextCtrl;
  EditorController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    ctrl.addListener(_onControllerChanged);
    _attachTextListener();
  }

  @override
  void dispose() {
    ctrl.removeListener(_onControllerChanged);
    _trackedTextCtrl?.removeListener(_update);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_trackedTextCtrl != ctrl.activeCtrl) {
      _attachTextListener();
    }
    if (mounted) setState(() {});
  }

  void _attachTextListener() {
    _trackedTextCtrl?.removeListener(_update);
    _trackedTextCtrl = ctrl.activeCtrl;
    _trackedTextCtrl!.addListener(_update);
    _update();
  }

  void _update() {
    final text = ctrl.activeCtrl.text;
    final sel  = ctrl.activeCtrl.selection;
    if (!sel.isValid) return;
    final before = text.substring(0, sel.start.clamp(0, text.length));
    final lines  = before.split('\n');
    final ln  = lines.length;
    final col = lines.last.length + 1;
    final s   = sel.end - sel.start;
    if (ln != _ln || col != _col || s != _sel) {
      if (mounted) setState(() { _ln = ln; _col = col; _sel = s; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color dot;
    switch (ctrl.status) {
      case AppStatus.idle:    dot = T.green;  break;
      case AppStatus.running: dot = T.accent; break;
      case AppStatus.error:   dot = T.red;    break;
    }

    return Container(
      height: 22,
      color: T.bg2,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(children: [
        // Status dot
        Container(
          width: 7, height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: dot, borderRadius: BorderRadius.circular(3.5),
          ),
        ),
        _SI(ctrl.activeFile.lang.displayName),
        _SS(),
        _SI('Ln $_ln  Col $_col'),
        _SS(),
        _SI(_sel > 0 ? '$_sel selected' : 'No sel'),
        const Spacer(),
        _SI(ctrl.statusMsg),
        if (ctrl.activeFile.dirty) ...[
          _SS(),
          _SI('●  unsaved', color: T.orange),
        ],
      ]),
    );
  }
}

class _SI extends StatelessWidget {
  final String text;
  final Color color;
  _SI(this.text, {this.color = const Color(0xFF4A5568)});
  @override
  Widget build(BuildContext ctx) => Text(
    text,
    style: TextStyle(color: color, fontSize: 10.5, fontFamily: 'monospace'),
  );
}

class _SS extends StatelessWidget {
  @override
  Widget build(BuildContext ctx) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 7),
    child: Text('|', style: TextStyle(color: T.border2, fontSize: 10)),
  );
}
