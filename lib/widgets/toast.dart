// lib/widgets/toast.dart
import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ToastWidget extends StatefulWidget {
  final String msg;
  const ToastWidget({super.key, required this.msg});
  @override
  State<ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: T.surface3,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: T.border2),
          boxShadow: const [
            BoxShadow(color: Color(0x60000000), blurRadius: 16, offset: Offset(0, 4)),
          ],
        ),
        child: Text(
          widget.msg,
          style: TextStyle(color: T.text, fontSize: 12.5),
        ),
      ),
    ),
  );
}
