import 'package:flutter/material.dart';

class FileDownloadScreen extends StatelessWidget {
  const FileDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파일 다운로드'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('파일을 다운로드 중입니다...'),
          ],
        ),
      ),
    );
  }
}
