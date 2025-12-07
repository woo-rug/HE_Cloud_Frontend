import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클라우드 검색 작동 원리'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.auto_stories, size: 32),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      '클라우드 검색 작동 원리',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '(추후 작성)',
                  style: TextStyle(fontSize: 16, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
