// lib/widgets/settings_sheet.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class SettingsSheet extends StatefulWidget {
  final EditorController ctrl;
  const SettingsSheet({super.key, required this.ctrl});
  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late EditorSettings s;

  @override
  void initState() {
    super.initState();
    s = widget.ctrl.settings.copy();
  }

  void _changed() {
    widget.ctrl.settings = s;
    widget.ctrl.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: T.border2, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('⚙️  Settings',
                style: TextStyle(color: T.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Divider(color: T.border, height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              children: [
                // ── Theme ──────────────────────────────────────────────
                _SectionHeader('Theme'),
                _ThemePicker(
                  current: s.themeId,
                  onChanged: (id) {
                    setState(() => s.themeId = id);
                    _changed();
                  },
                ),

                // ── Editor ─────────────────────────────────────────────
                _SectionHeader('Editor'),
                _TogRow('Auto Run',              'Run on every change',     s.autorun,          () { setState(() => s.autorun          = !s.autorun);          _changed(); }),
                _TogRow('Highlight Current Line','',                        s.curlineHighlight, () { setState(() => s.curlineHighlight = !s.curlineHighlight); _changed(); }),
                _TogRow('Autocomplete',          'Smart code suggestions',  s.autocomplete,     () { setState(() => s.autocomplete     = !s.autocomplete);     _changed(); }),
                _TogRow('Auto Close Brackets',   'Auto-pair {}, (), []',    s.autopairs,        () { setState(() => s.autopairs        = !s.autopairs);        _changed(); }),
                _TogRow('Word Wrap',             'Wrap long lines',         s.wordwrap,         () { setState(() => s.wordwrap         = !s.wordwrap);         _changed(); }),
                _TogRow('Show Whitespace',       'Show space/tab markers',  s.showWhitespace,   () { setState(() => s.showWhitespace   = !s.showWhitespace);   _changed(); }),

                // ── Appearance ─────────────────────────────────────────
                _SectionHeader('Appearance'),
                _SliderRow('Font Size',   '${s.fontSize.round()}px',             s.fontSize,   10,  20,  (v) { setState(() => s.fontSize   = v); _changed(); }),
                _SliderRow('Line Height', '${s.lineHeight.toStringAsFixed(1)}x', s.lineHeight, 1.2, 2.4, (v) { setState(() => s.lineHeight = v); _changed(); }),

                // ── Indentation ────────────────────────────────────────
                _SectionHeader('Indentation'),
                _SelectRow<int>('Tab Size', s.tabSize, [2, 4, 8],
                    (v) { setState(() => s.tabSize = v); _changed(); }),
                _TogRow('Use Hard Tabs', 'Insert \\t instead of spaces', s.useTabs,
                    () { setState(() => s.useTabs = !s.useTabs); _changed(); }),

                // ── Auto-Run ───────────────────────────────────────────
                _SectionHeader('Auto-Run'),
                _SelectRow<int>(
                  'Delay', s.autorunDelay, [500, 800, 1200, 2000, 3000],
                  (v) { setState(() => s.autorunDelay = v); _changed(); },
                  labelFn: (v) => '${v}ms',
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Theme Picker ─────────────────────────────────────────────────────────────
class _ThemePicker extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _ThemePicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: EditorTheme.all.map((theme) {
          final selected = theme.id == current;
          return GestureDetector(
            onTap: () => onChanged(theme.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? T.accent : theme.border,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected ? [
                  BoxShadow(color: T.accentDim, blurRadius: 8, spreadRadius: 1),
                ] : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  // Colour swatches
                  _Swatches(theme: theme),
                  const SizedBox(width: 12),
                  // Name + dark/light label
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(theme.name,
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Text(theme.dark ? 'Dark' : 'Light',
                          style: TextStyle(color: theme.textMid, fontSize: 11)),
                    ]),
                  ),
                  // Selected indicator
                  if (selected)
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: T.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Five syntax-colour swatches as a preview of the theme.
class _Swatches extends StatelessWidget {
  final EditorTheme theme;
  const _Swatches({required this.theme});

  @override
  Widget build(BuildContext context) {
    final colors = [
      theme.sKw, theme.sFn, theme.sStr, theme.sNum, theme.sCmt,
    ];
    return Row(
      children: colors.map((c) => Container(
        width: 10, height: 28,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      )).toList(),
    );
  }
}

// ── Shared row widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(color: T.textDim, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
    ),
  );
}

class _TogRow extends StatelessWidget {
  final String label, desc;
  final bool val;
  final VoidCallback onTap;
  const _TogRow(this.label, this.desc, this.val, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.border, width: 0.5))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: T.text, fontSize: 14)),
          if (desc.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(desc, style: TextStyle(color: T.textDim, fontSize: 12)),
            ),
        ])),
        _Toggle(val),
      ]),
    ),
  );
}

class _Toggle extends StatelessWidget {
  final bool val;
  const _Toggle(this.val);
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: 44, height: 24,
    decoration: BoxDecoration(
      color: val ? T.accent : T.surface3,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: val ? T.accent : T.border2),
    ),
    child: Stack(children: [
      AnimatedPositioned(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        left: val ? 22 : 2, top: 2,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 4)],
          ),
        ),
      ),
    ]),
  );
}

class _SliderRow extends StatelessWidget {
  final String label, valueLabel;
  final double val, min, max;
  final ValueChanged<double> onChanged;
  const _SliderRow(this.label, this.valueLabel, this.val, this.min, this.max, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.border, width: 0.5))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(color: T.text, fontSize: 14)),
        const Spacer(),
        Text(valueLabel, style: TextStyle(color: T.accent, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor:   T.accent,
          inactiveTrackColor: T.surface3,
          thumbColor:         T.accent,
          overlayColor:       T.accentDim,
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        ),
        child: Slider(value: val, min: min, max: max, onChanged: onChanged),
      ),
    ]),
  );
}

class _SelectRow<V> extends StatelessWidget {
  final String label;
  final V val;
  final List<V> options;
  final ValueChanged<V> onChanged;
  final String Function(V)? labelFn;
  const _SelectRow(this.label, this.val, this.options, this.onChanged, {this.labelFn});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: T.border, width: 0.5))),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: T.text, fontSize: 14))),
      Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: T.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.border2),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<V>(
            value: val,
            dropdownColor: T.surface3,
            isDense: true,
            style: TextStyle(color: T.text, fontSize: 13, fontFamily: 'monospace'),
            items: options.map((o) => DropdownMenuItem(
              value: o,
              child: Text(labelFn != null ? labelFn!(o) : '$o'),
            )).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    ]),
  );
}
