// lib/widgets/bottom_panel.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../services/lsp_service.dart';
import '../models/models.dart';

class BottomPanel extends StatefulWidget {
  final EditorController ctrl;
  const BottomPanel({super.key, required this.ctrl});
  @override
  State<BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<BottomPanel> {
  WebViewController? _wv;
  double _panelH    = 220;
  double _dragY     = 0;
  double _dragH     = 0;
  String _lastHtml  = '';
  final _consoleScroll = ScrollController();

  EditorController get ctrl => widget.ctrl;

  @override
  void initState() {
    super.initState();
    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
          'DevPadCh',
          onMessageReceived: (m) => ctrl.handleWebViewMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate());
  }

  @override
  void didUpdateWidget(covariant BottomPanel old) {
    super.didUpdateWidget(old);
    if (ctrl.previewHtml != _lastHtml && ctrl.previewHtml.isNotEmpty) {
      _lastHtml = ctrl.previewHtml;
      _wv?.loadHtmlString(ctrl.previewHtml);
    }
    if (ctrl.logs.length != old.ctrl.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_consoleScroll.hasClients) {
          _consoleScroll.animateTo(
            _consoleScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _consoleScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ctrl.panelOpen) return const SizedBox.shrink();
    final h = ctrl.panelTall
        ? MediaQuery.of(context).size.height * 0.55
        : _panelH;

    return Column(children: [
      // Resize handle
      GestureDetector(
        onVerticalDragStart:  (d) { _dragY = d.globalPosition.dy; _dragH = _panelH; },
        onVerticalDragUpdate: (d) {
          final dy     = _dragY - d.globalPosition.dy;
          final screen = MediaQuery.of(context).size.height;
          setState(() => _panelH = (_dragH + dy).clamp(80, screen * 0.7));
        },
        child: Container(
          height: 6, color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40, height: 3,
              decoration: BoxDecoration(
                color: T.border2, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),

      // Panel body
      SizedBox(
        height: h,
        child: Container(
          decoration: BoxDecoration(
            color: T.bg2,
            border: Border(top: BorderSide(color: T.border)),
          ),
          child: Column(children: [
            // Tab bar
            Container(
              height: 30, color: T.bg,
              child: Row(children: [
                _PTab(
                  'Console', ctrl.panelTab == PanelTab.console,
                  () => ctrl.switchPanelTab(PanelTab.console),
                  badge: ctrl.errorCount > 0 ? '${ctrl.errorCount}' : null,
                ),
                _PTab(
                  'Preview', ctrl.panelTab == PanelTab.preview,
                  () => ctrl.switchPanelTab(PanelTab.preview),
                ),
                _PTab(
                  'Git Diff', ctrl.panelTab == PanelTab.git,
                  () => ctrl.switchPanelTab(PanelTab.git),
                  badge: ctrl.gitDiff.added + ctrl.gitDiff.modified > 0
                      ? '+${ctrl.gitDiff.added + ctrl.gitDiff.modified}'
                      : null,
                  badgeColor: T.green,
                ),
                _PTab(
                  'Problems', ctrl.panelTab == PanelTab.lsp,
                  () => ctrl.switchPanelTab(PanelTab.lsp),
                  badge: ctrl.lspErrorCount > 0
                      ? '${ctrl.lspErrorCount}'
                      : ctrl.lspWarningCount > 0
                          ? '${ctrl.lspWarningCount}'
                          : null,
                  badgeColor: ctrl.lspErrorCount > 0 ? T.red : T.orange,
                ),
                const Spacer(),
                if (ctrl.panelTab == PanelTab.console)
                  _PBtn(Icons.delete_outline, ctrl.clearConsole, 'Clear'),
                if (ctrl.panelTab == PanelTab.preview)
                  _PBtn(Icons.refresh, ctrl.runCode, 'Reload'),
                _PBtn(
                  ctrl.panelTall ? Icons.compress : Icons.open_in_full,
                  ctrl.togglePanelTall, 'Resize',
                ),
                _PBtn(Icons.close, ctrl.closePanel, 'Close'),
              ]),
            ),

            // Content
            Expanded(
              child: switch (ctrl.panelTab) {
                PanelTab.console => _ConsoleView(logs: ctrl.logs, scroll: _consoleScroll),
                PanelTab.preview => _PreviewView(wv: _wv ?? WebViewController()),
                PanelTab.git    => _GitDiffView(ctrl: ctrl),
                PanelTab.lsp    => _LspPanel(ctrl: ctrl),
              },
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _ConsoleView extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController scroll;
  const _ConsoleView({required this.logs, required this.scroll});

  @override
  Widget build(BuildContext ctx) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Console output will appear here',
          style: TextStyle(color: T.textDim, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final l = logs[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              l.level.icon,
              style: TextStyle(
                color: l.level.color, fontSize: 12, fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                l.message,
                style: TextStyle(
                  color: l.level.color, fontSize: 11.5, fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              l.time,
              style: const TextStyle(
                color: T.textDim, fontSize: 9.5, fontFamily: 'monospace',
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _PreviewView extends StatelessWidget {
  final WebViewController wv;
  const _PreviewView({required this.wv});

  @override
  Widget build(BuildContext ctx) => Column(children: [
    Container(
      height: 26, color: T.surface,
      child: const Center(
        child: Text(
          'preview://localhost',
          style: TextStyle(color: T.textDim, fontSize: 10.5, fontFamily: 'monospace'),
        ),
      ),
    ),
    Expanded(child: WebViewWidget(controller: wv)),
  ]);
}

class _PTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
  const _PTab(this.label, this.active, this.onTap,
      {this.badge, this.badgeColor});

  @override
  Widget build(BuildContext ctx) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? T.accent : Colors.transparent, width: 2,
          ),
        ),
      ),
      child: Row(children: [
        Text(
          label,
          style: TextStyle(
            color: active ? T.text : T.textDim, fontSize: 11,
          ),
        ),
        if (badge != null)
          Container(
            margin: const EdgeInsets.only(left: 5),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor ?? T.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ]),
    ),
  );
}

class _PBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tt;
  const _PBtn(this.icon, this.onTap, this.tt);

  @override
  Widget build(BuildContext ctx) => Tooltip(
    message: tt,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 30, height: 30,
        child: Icon(icon, size: 14, color: T.textDim),
      ),
    ),
  );
}

// ── Git Diff View ─────────────────────────────────────────────────────────────
class _GitDiffView extends StatelessWidget {
  final EditorController ctrl;
  const _GitDiffView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final diff = ctrl.gitDiff;
    if (diff.lines.isEmpty) {
      return Center(
        child: Text('No changes since last save',
            style: TextStyle(color: T.textDim, fontSize: 12)),
      );
    }

    final lines    = ctrl.activeCtrl.text.split('\n');
    final allLines = diff.lines;

    return Column(children: [
      // ── Summary bar ────────────────────────────────────────────────────
      Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: T.bg2,
        child: Row(children: [
          _DiffStat('+${diff.added}',    T.green),
          const SizedBox(width: 10),
          _DiffStat('~${diff.modified}', T.accent),
          const SizedBox(width: 10),
          _DiffStat('-${diff.removed}',  T.red),
          const Spacer(),
          Text(ctrl.activeFile.name,
              style: TextStyle(color: T.textDim, fontSize: 10.5,
                  fontFamily: 'monospace')),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: ctrl.saveCurrentFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: T.accentDim,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: T.accent),
              ),
              child: Text('Save', style: TextStyle(color: T.accent, fontSize: 10.5)),
            ),
          ),
        ]),
      ),
      // ── Diff lines ─────────────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          itemCount: allLines.length,
          itemBuilder: (ctx, i) {
            final dl      = allLines[i];
            final lineIdx = dl.lineNo - 1;
            final text    = lineIdx < lines.length ? lines[lineIdx] : '';
            final bg = switch (dl.type) {
              DiffLineType.added    => T.green.withOpacity(0.10),
              DiffLineType.modified => T.accent.withOpacity(0.08),
              DiffLineType.removed  => T.red.withOpacity(0.10),
              _                     => Colors.transparent,
            };
            final marker = switch (dl.type) {
              DiffLineType.added    => '+',
              DiffLineType.modified => '~',
              DiffLineType.removed  => '-',
              _                     => ' ',
            };
            final markerColor = switch (dl.type) {
              DiffLineType.added    => T.green,
              DiffLineType.modified => T.accent,
              DiffLineType.removed  => T.red,
              _                     => Colors.transparent,
            };
            return GestureDetector(
              onTap: () => ctrl.goToLine(dl.lineNo),
              child: Container(
                color: bg,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 1),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Marker
                  SizedBox(
                    width: 14,
                    child: Center(
                      child: Text(marker,
                          style: TextStyle(color: markerColor, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  // Line number
                  SizedBox(
                    width: 36,
                    child: Text('${dl.lineNo}',
                        style: TextStyle(color: T.lineNum, fontSize: 10.5,
                            fontFamily: 'monospace')),
                  ),
                  // Line content
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(color: T.text, fontSize: 11,
                          fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _DiffStat extends StatelessWidget {
  final String text;
  final Color  color;
  const _DiffStat(this.text, this.color);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w700, fontFamily: 'monospace'));
}

// ── LSP Problems Panel ────────────────────────────────────────────────────────
class _LspPanel extends StatelessWidget {
  final EditorController ctrl;
  const _LspPanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final diags = ctrl.lspDiagnostics;
    if (diags.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, color: T.green, size: 28),
          const SizedBox(height: 8),
          Text('No problems detected',
              style: TextStyle(color: T.textDim, fontSize: 12)),
        ]),
      );
    }

    // Group by severity
    final errors   = diags.where((d) => d.severity == DiagnosticSeverity.error).toList();
    final warnings = diags.where((d) => d.severity == DiagnosticSeverity.warning).toList();
    final infos    = diags.where((d) => d.severity == DiagnosticSeverity.info || d.severity == DiagnosticSeverity.hint).toList();

    return Column(children: [
      // Summary bar
      Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: T.bg2,
        child: Row(children: [
          if (errors.isNotEmpty) ...[
            Icon(Icons.error_outline, size: 13, color: T.red),
            const SizedBox(width: 4),
            Text('${errors.length} error${errors.length == 1 ? "" : "s"}',
                style: TextStyle(color: T.red, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
          ],
          if (warnings.isNotEmpty) ...[
            Icon(Icons.warning_amber_outlined, size: 13, color: T.orange),
            const SizedBox(width: 4),
            Text('${warnings.length} warning${warnings.length == 1 ? "" : "s"}',
                style: TextStyle(color: T.orange, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
          ],
          if (infos.isNotEmpty) ...[
            Icon(Icons.info_outline, size: 13, color: T.accent),
            const SizedBox(width: 4),
            Text('${infos.length} info',
                style: TextStyle(color: T.accent, fontSize: 11)),
          ],
          const Spacer(),
          Text(ctrl.activeFile.name,
              style: TextStyle(color: T.textDim, fontSize: 10.5,
                  fontFamily: 'monospace')),
        ]),
      ),
      // Diagnostic list
      Expanded(
        child: ListView(
          children: [
            ...errors.map((d) => _DiagRow(d, ctrl)),
            ...warnings.map((d) => _DiagRow(d, ctrl)),
            ...infos.map((d) => _DiagRow(d, ctrl)),
          ],
        ),
      ),
    ]);
  }
}

class _DiagRow extends StatelessWidget {
  final LspDiagnostic    diag;
  final EditorController ctrl;
  const _DiagRow(this.diag, this.ctrl);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (diag.severity) {
      DiagnosticSeverity.error   => (Icons.error_outline,          T.red),
      DiagnosticSeverity.warning => (Icons.warning_amber_outlined,  T.orange),
      DiagnosticSeverity.info    => (Icons.info_outline,            T.accent),
      DiagnosticSeverity.hint    => (Icons.lightbulb_outline,       T.textDim),
    };

    return GestureDetector(
      onTap: () => ctrl.goToLine(diag.line1),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.border, width: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(diag.message,
                  style: TextStyle(color: T.text, fontSize: 11.5),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(
                '${ctrl.activeFile.name}:${diag.line1}:${diag.range.start.column + 1}  [${diag.source}]',
                style: TextStyle(color: T.textDim, fontSize: 10,
                    fontFamily: 'monospace'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
