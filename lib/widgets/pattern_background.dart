import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PatternBackground extends StatelessWidget {
  final Widget child;
  const PatternBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.canvas,
      child: child,
    );
  }
}
