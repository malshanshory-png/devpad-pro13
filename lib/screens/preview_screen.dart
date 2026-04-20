// lib/screens/preview_screen.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../utils/theme.dart';
import '../services/editor_controller.dart';
import '../models/models.dart';

class PreviewScreen extends StatefulWidget {
  final EditorController ctrl;
  const PreviewScreen({super.key, required this.ctrl});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late WebViewController _wv;
  String _lastHtml = '';
  final ScrollController _consoleScroll = ScrollController();

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

    if (ctrl.previewHtml.isNotEmpty) {
      _lastHtml = ctrl.previewHtml;
      _wv.loadHtmlString(ctrl.previewHtml);
    }

    ctrl.addListener(_onCtrlChanged);
  }

  @override
  void dispose() {
    ctrl.removeListener(_onCtrlChanged);
    _consoleScroll.dispose();
    super.dispose();
  }

  void _onCtrlChanged() {
    if (!mounted) return;

    // Reload WebView when new HTML is generated
    if (ctrl.previewHtml != _lastHtml && ctrl.previewHtml.isNotEmpty) {
      _lastHtml = ctrl.previewHtml;
      _wv.loadHtmlString(ctrl.previewHtml);
    }

    // Auto-scroll console to bottom on new logs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScroll.hasClients &&
          _consoleScroll.position.maxScrollExtent > 0) {
        _consoleScroll.animateTo(
          _consoleScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });

    if (mounted) setState(() {});
  }

  void _goBack() {
    ctrl.closePreviewScreen();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isConsole = ctrl.panelTab == PanelTab.console;

    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar ───────────────────────────────────────────────────
          Container(
            height: 52,
            color: T.bg2,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              // Back button
              GestureDetector(
                onTap: _goBack,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: T.surface3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: T.border2),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: T.textMid, size: 16,
                  ),
                ),
              ),

              const Spacer(),

              // Console / Preview toggle pill
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: T.surface3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: T.border2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _TabBtn(
                    label: 'Console',
                    active: isConsole,
                    badge: ctrl.errorCount > 0 ? '${ctrl.errorCount}' : null,
                    onTap: () { ctrl.switchPanelTab(PanelTab.console); setState(() {}); },
                  ),
                  Container(width: 1, height: 20, color: T.border2),
                  _TabBtn(
                    label: 'Preview',
                    active: !isConsole,
                    onTap: () { ctrl.switchPanelTab(PanelTab.preview); setState(() {}); },
                  ),
                ]),
              ),

              const Spacer(),

              // Action: clear console / reload preview
              GestureDetector(
                onTap: isConsole ? ctrl.clearConsole : ctrl.runCode,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: T.surface3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: T.border2),
                  ),
                  child: Icon(
                    isConsole
                        ? Icons.delete_outline_rounded
                        : Icons.refresh_rounded,
                    color: T.textMid, size: 17,
                  ),
                ),
              ),
            ]),
          ),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: isConsole
                ? _ConsoleView(logs: ctrl.logs, scroll: _consoleScroll)
                : _PreviewView(wv: _wv),
          ),
        ]),
      ),
    );
  }
}

// ── Tab pill button ───────────────────────────────────────────────────────────
class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: active ? T.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : T.textDim,
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: T.red, borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ]),
    ),
  );
}

// ── Console view ──────────────────────────────────────────────────────────────
class _ConsoleView extends StatelessWidget {
  final List<LogEntry> logs;
  final ScrollController scroll;
  const _ConsoleView({required this.logs, required this.scroll});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.terminal, color: T.textDim, size: 40),
          SizedBox(height: 12),
          Text(
            'Console output will appear here',
            style: TextStyle(color: T.textDim, fontSize: 13),
          ),
        ]),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final l = logs[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              l.level.icon,
              style: TextStyle(
                color: l.level.color, fontSize: 13, fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(
                l.message,
                style: TextStyle(
                  color: l.level.color, fontSize: 12, fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l.time,
              style: TextStyle(
                color: T.textDim, fontSize: 10, fontFamily: 'monospace',
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── WebView preview ───────────────────────────────────────────────────────────
class _PreviewView extends StatelessWidget {
  final WebViewController wv;
  const _PreviewView({required this.wv});

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      height: 28, color: T.surface,
      child: Center(
        child: Text(
          'preview://localhost',
          style: TextStyle(color: T.textDim, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    ),
    Expanded(child: WebViewWidget(controller: wv)),
  ]);
}
