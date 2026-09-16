import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend_tecsys/theme/app_colors.dart';

class AppBarTime extends StatefulWidget {
  const AppBarTime({super.key});
  @override
  State<AppBarTime> createState() => _AppBarTime();
}

class _AppBarTime extends State<AppBarTime> {
  String _timeString = "";
  Timer? _timer;

  void updateTime() {
    final now = DateTime.now();
    setState(() {
      _timeString = "${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}";
    });
  }

  @override
  void initState() {
    super.initState();
    updateTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        title: Text(_timeString) ,titleTextStyle: TextStyle(fontSize: 13, color: Colors.white),
    );
  }
}