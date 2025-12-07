import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HE Cloud 홈',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '현재 동기화 상태와 보안 키 정보를 확인하세요.',
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 24),

                // 정보 패널들
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _infoPanel(
                      title: '동기화 상태',
                      description: '모든 파일이 최신 상태입니다.',
                      actionLabel: '동기화 상세보기',
                      icon: Icons.sync,
                      color: Colors.green.shade600,
                    ),
                    _infoPanel(
                      title: '작동 방식 안내',
                      description: 'HE Cloud의 암호화 및 저장 절차를 알아보세요.',
                      actionLabel: '작동 방식 보기',
                      icon: Icons.info_outline,
                      color: AppTheme.accentBlueLight,
                      onTap: () {
                        Navigator.of(context).pushNamed('/how-it-works');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // [NEW] 보안 키 상태 확인 섹션
                const Text(
                  '🔐 현재 메모리에 로드된 보안 키 (Debug Info)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildKeyInfoCard(
                  "KEK (Key Encryption Key)",
                  provider.debugKek,
                ),
                const SizedBox(height: 12),
                _buildKeyInfoCard("Master Key (MK)", provider.debugMasterKey),
                const SizedBox(height: 12),
                _buildKeyInfoCard(
                  "HE Secret Key (SK)",
                  provider.debugHeSecretKey,
                  isLong: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyInfoCard(
    String title,
    List<int>? keyBytes, {
    bool isLong = false,
  }) {
    String displayValue;
    Color statusColor;
    IconData statusIcon;

    if (keyBytes != null) {
      // 키가 있으면 Base64로 변환해서 보여줌 (너무 길면 자름)
      String base64Str = base64Encode(keyBytes);
      if (isLong && base64Str.length > 50) {
        displayValue =
            "${base64Str.substring(0, 50)}... (${keyBytes.length} bytes)";
      } else {
        displayValue = base64Str;
      }
      statusColor = Colors.green.shade700;
      statusIcon = Icons.check_circle_outline;
    } else {
      displayValue = "로드되지 않음 (NULL)";
      statusColor = Colors.red.shade700;
      statusIcon = Icons.error_outline;
    }

    return Card(
      elevation: 0,
      color: statusColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: SelectableText(
          displayValue,
          style: TextStyle(
            fontFamily: 'monospace',
            color: keyBytes != null ? Colors.black87 : Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _infoPanel({
    required String title,
    required String description,
    required String actionLabel,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    // ... (기존 UI 코드 동일) ...
    return SizedBox(
      width: 340,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onTap, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
