// lib/widgets/ac_overlay.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';

class AcOverlay extends StatelessWidget {
  final EditorController ctrl;
  const AcOverlay({super.key, required this.ctrl});

  static final _kindColors = <String, Color>{
    'keyword': T.sKw,   'snippet': T.accent, 'method': T.sFn,  'fn': T.sFn,
    'attr':    T.sAtr,  'prop':    T.sProp,  'tag':    T.sTag, 'value': T.sVal,
    'class':   T.sCls,  'op':      T.sOp,
  };
  static const _kindIcons = <String, String>{
    'keyword': 'K', 'snippet': 'S', 'method': 'M', 'fn': 'f',
    'attr':    'A', 'prop':    'P', 'tag':    'T', 'value': 'V',
    'class':   'C', 'op':      'O',
  };

  @override
  Widget build(BuildContext context) {
    if (ctrl.acCursorOffset == Offset.zero) return const SizedBox.shrink();

    final screenSize     = MediaQuery.of(context).size;
    const overlayW      = 280.0;
    const overlayMaxH   = 240.0;
    const itemH         = 40.0;
    const gap           = 4.0;

    final cursorDx = ctrl.acCursorOffset.dx;
    final cursorDy = ctrl.acCursorOffset.dy;

    final estH      = (ctrl.acItems.length * itemH).clamp(0.0, overlayMaxH);
    final spaceBelow = screenSize.height - cursorDy;
    final showBelow  = spaceBelow >= estH + gap + 32;

    final left = cursorDx.clamp(4.0, screenSize.width - overlayW - 4.0);

    return Positioned(
      left:   left,
      width:  overlayW,
      top:    showBelow ? cursorDy + gap : null,
      bottom: showBelow ? null : screenSize.height - cursorDy + gap,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: overlayMaxH),
          decoration: BoxDecoration(
            color: T.surface3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: T.border2),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 20, offset: Offset(0, 6)),
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: ctrl.acItems.length,
            itemBuilder: (_, i) {
              final item  = ctrl.acItems[i];
              final sel   = i == ctrl.acIdx;
              final color = _kindColors[item.kind] ?? T.textMid;
              final icon  = _kindIcons[item.kind]  ?? '·';

              BorderRadius? borderRadius;
              if (i == 0 && ctrl.acItems.length == 1) {
                borderRadius = BorderRadius.circular(12);
              } else if (i == 0) {
                borderRadius = BorderRadius.vertical(top: Radius.circular(12));
              } else if (i == ctrl.acItems.length - 1) {
                borderRadius = BorderRadius.vertical(bottom: Radius.circular(12));
              }

              return GestureDetector(
                onTap: () { ctrl.acIdx = i; ctrl.acAccept(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? T.accentDim : Colors.transparent,
                    borderRadius: borderRadius,
                  ),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          icon,
                          style: TextStyle(
                            color: color, fontSize: 9, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: sel ? T.text : T.textMid,
                          fontSize: 12, fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (item.detail.isNotEmpty)
                      Text(item.detail, style: TextStyle(color: T.textDim, fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(item.kind, style: TextStyle(color: T.textFaint, fontSize: 9)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
