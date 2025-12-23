import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class MedicalApp extends StatelessWidget {
  const MedicalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: createRouter(),
    );
  }
}