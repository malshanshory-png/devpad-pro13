// lib/widgets/samples_sheet.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/sample_projects.dart';

class SamplesSheet extends StatelessWidget {
  final void Function(SampleProject) onSelect;
  const SamplesSheet({super.key, required this.onSelect});

  static const _icons = ['✅', '🌤', '🔢', '📋'];
  static const _descs = [
    'Full-featured todo app with priorities,\nfiltering, localStorage, animations',
    'Weather dashboard with simulated API,\n8 cities, 7-day forecast, details grid',
    'Scientific calculator with trig, log,\nfactorial, history, keyboard support',
    'Drag-and-drop kanban board with\n4 columns, priorities, localStorage',
  ];

  @override
  Widget build(BuildContext context) {
    // FIX: Guard against mismatch between allSamples length and _icons/_descs.
    final count = allSamples.length.clamp(0, _icons.length);

    return Container(
      decoration: BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          decoration: BoxDecoration(color: T.border2, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text('📂  Sample Projects',
              style: TextStyle(color: T.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'Load a complete project to test the editor.\nYour current code will be replaced.',
            textAlign: TextAlign.center,
            style: TextStyle(color: T.textDim, fontSize: 12),
          ),
        ),
        Divider(color: T.border, height: 1),
        // Scrollable list in case there are many samples
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: count,
            itemBuilder: (_, i) {
              final p = allSamples[i];
              return GestureDetector(
                onTap: () => onSelect(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: T.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: T.surface3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(_icons[i], style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name,
                            style: TextStyle(
                                color: T.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(_descs[i],
                            style: TextStyle(
                                color: T.textDim, fontSize: 11.5, height: 1.4)),
                      ]),
                    ),
                    Icon(Icons.chevron_right, color: T.textDim, size: 18),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}
