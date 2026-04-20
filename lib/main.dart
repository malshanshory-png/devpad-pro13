// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';
import 'services/editor_controller.dart';
import 'screens/editor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Support all orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // System UI — uses hardcoded dark defaults at startup.
  // After the controller loads settings the theme is applied and
  // notifyListeners() triggers a Consumer rebuild which updates the UI.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    statusBarIconBrightness:           Brightness.light,
    systemNavigationBarColor:          Color(0xFF080B14),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const DevPadApp());
}

class DevPadApp extends StatelessWidget {
  const DevPadApp({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => EditorController(),
    child: Consumer<EditorController>(
      builder: (ctx, ctrl, _) => MaterialApp(
        title: 'DevPad Pro',
        debugShowCheckedModeBanner: false,
        // T.theme reads T._active which is updated by T.useId() in the
        // controller whenever settings.themeId changes.
        theme: T.theme,
        home: const _Loader(),
      ),
    ),
  );
}

// ── Loader: init controller then hand off to EditorScreen ───────────────────
class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    context.read<EditorController>().init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? const EditorScreen() : const _Splash();
}

// ── Splash screen ─────────────────────────────────────────────────────────────
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF080B14),
    body: Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Logo(),
        SizedBox(height: 20),
        Text(
          'DevPad Pro',
          style: TextStyle(
            color: Color(0xFFE2E8F4), fontSize: 22,
            fontWeight: FontWeight.w700, letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'v2.0',
          style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
        ),
      ]),
    ),
  );
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Container(
    width: 64, height: 64,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(color: Color(0x503B82F6), blurRadius: 24, offset: Offset(0, 8)),
      ],
    ),
    child: const Center(
      child: Text(
        '✦',
        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
