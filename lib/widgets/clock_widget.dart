
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({super.key});

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(DateFormat('HH:mm').format(_now),
            style: GoogleFonts.rubik(
                fontSize: 120,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: -2)),
        Text(
            DateFormat('EEEE, MMM dd, yyyy')
                .format(_now),
            style: const TextStyle(
                fontSize: 24, color: Colors.white70)),
      ],
    );
  }
}
