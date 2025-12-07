import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_background.dart';
import 'create_folder_screen.dart';
import 'file_upload_screen.dart';

class CloudBrowserScreen extends StatelessWidget {
  const CloudBrowserScreen({super.key});

  Future<void> _handleDownload(
    BuildContext context,
    int fileId,
    String decodedName,
  ) async {
    // (기존 코드 유지)
    final provider = context.read<AppProvider>();
    final api = provider.apiService;
    final crypto = provider.crypto;

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '파일을 저장할 폴더를 선택하세요',
      );

      if (selectedDirectory == null) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다운로드 및 복호화 중...')));

      final encBytes = await api.downloadFile(fileId);
      if (encBytes == null) throw Exception("파일 다운로드 실패");

      final tempFileName = "temp_${DateTime.now().millisecondsSinceEpoch}.enc";
      final tempFile = File('$selectedDirectory/$tempFileName');
      await tempFile.writeAsBytes(encBytes);

      final decryptedBytes = crypto.decryptFileContent(encBytes);
      if (decryptedBytes == null) throw Exception("복호화 실패 (키 오류)");

      String finalPath = '$selectedDirectory/$decodedName';
      int count = 1;
      while (File(finalPath).existsSync()) {
        final dotIndex = decodedName.lastIndexOf('.');
        if (dotIndex == -1) {
          finalPath = '$selectedDirectory/$decodedName($count)';
        } else {
          final name = decodedName.substring(0, dotIndex);
          final ext = decodedName.substring(dotIndex);
          finalPath = '$selectedDirectory/$name($count)$ext';
        }
        count++;
      }

      final realFile = File(finalPath);
      await realFile.writeAsBytes(decryptedBytes);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 완료: ${realFile.path}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // [로직] 삭제 프로세스 (수정됨)
  Future<void> _handleDelete(
    BuildContext context,
    String type,
    int id,
    String name,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$name 삭제'),
        content: const Text('정말로 삭제하시겠습니까?\n(복구할 수 없습니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // [수정] 삭제 결과에 따라 스낵바 표시 (화면 유지)
      final success = await context.read<AppProvider>().deleteItem(type, id);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('삭제 실패: 권한이 없거나 파일이 존재하지 않습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // [신규] 새로고침 로직
  Future<void> _refresh(BuildContext context) async {
    final provider = context.read<AppProvider>();
    await provider.fetchFolder(provider.currentFolderId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return PatternBackground(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbs(context, provider),
                const SizedBox(height: 12),
                _buildHeader(context),
                const SizedBox(height: 12),
                Expanded(child: _buildContent(context, provider)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreadcrumbs(BuildContext context, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: provider.path.asMap().entries.map((entry) {
          final idx = entry.key;
          final segment = entry.value;
          final isLast = idx == provider.path.length - 1;
          final label = provider.getShortenedName(segment['name']);

          final button = OutlinedButton.icon(
            onPressed: isLast
                ? null
                : () => provider.fetchFolder(
                    segment['id'],
                    folderName: segment['name'],
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isLast ? Colors.white : AppTheme.accentBlueDark,
              backgroundColor: isLast
                  ? AppTheme.accentBlue
                  : AppTheme.accentBlue.withOpacity(0.08),
              side: BorderSide(
                color: isLast
                    ? AppTheme.accentBlue
                    : AppTheme.accentBlue.withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: Icon(
              Icons.folder,
              size: 18,
              color: isLast ? Colors.white : AppTheme.accentBlueDark,
            ),
            label: Text(
              label,
              style: TextStyle(
                fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
                color: isLast ? Colors.white : AppTheme.accentBlueDark,
              ),
            ),
          );
          return MouseRegion(
            cursor: isLast
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: button,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppTheme.accentBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.cloud, color: AppTheme.accentBlue),
            ),
            const SizedBox(width: 12),
            const Text(
              '클라우드 탐색기',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Spacer(),

        // [추가] 새로고침 버튼
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '새로고침',
          onPressed: () => _refresh(context),
        ),

        PopupMenuButton<String>(
          icon: const Icon(Icons.add_circle_outline, size: 32),
          tooltip: '파일/폴더 추가',
          onSelected: (value) async {
            if (value == 'upload') {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FileUploadScreen()),
              );
            } else if (value == 'folder') {
              final folderName = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const CreateFolderScreen()),
              );
              if (folderName != null && context.mounted) {
                await context.read<AppProvider>().createNewFolder(folderName);
              }
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'upload',
              child: ListTile(
                leading: Icon(Icons.upload_file),
                title: Text('파일 업로드'),
              ),
            ),
            PopupMenuItem(
              value: 'folder',
              child: ListTile(
                leading: Icon(Icons.create_new_folder),
                title: Text('폴더 생성'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AppProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null) {
      // [수정] 에러 발생 시에도 새로고침 버튼을 눌러 복구할 수 있도록 처리
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${provider.errorMessage}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _refresh(context),
              child: const Text('재시도'),
            ),
          ],
        ),
      );
    }
    if (provider.currentFolderContent == null) {
      return const Center(child: Text('폴더 정보를 불러올 수 없습니다.'));
    }

    final folders = provider.currentFolderContent!.childFolders;
    final files = provider.currentFolderContent!.files;

    // [수정] 당겨서 새로고침(RefreshIndicator) 추가
    // 리스트가 비어있어도 당겨서 새로고침 가능하도록 LayoutBuilder 사용
    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: (folders.isEmpty && files.isEmpty)
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: const Center(child: Text('폴더가 비어있습니다.')),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: folders.length + files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index < folders.length) {
                  final folder = folders[index];
                  return ListTile(
                    onTap: () => provider.fetchFolder(
                      folder.folderId,
                      folderName: folder.decodedName,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accentBlue.withOpacity(0.15),
                      child: const Icon(
                        Icons.folder,
                        color: AppTheme.accentBlueDark,
                      ),
                    ),
                    title: Text(provider.getShortenedName(folder.decodedName)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _handleDelete(
                            context,
                            'folder',
                            folder.folderId,
                            folder.decodedName,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            title: Text(
                              '폴더 삭제',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final file = files[index - folders.length];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentBlueLight.withOpacity(0.15),
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppTheme.accentBlueDark,
                    ),
                  ),
                  title: Text(provider.getShortenedName(file.decodedName)),
                  subtitle: Text(
                    '${file.mime} · ${DateFormat('yyyy-MM-dd HH:mm').format(file.uploadedAt)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'download') {
                        _handleDownload(context, file.fileId, file.decodedName);
                      } else if (value == 'delete') {
                        _handleDelete(
                          context,
                          'file',
                          file.fileId,
                          file.decodedName,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'download',
                        child: ListTile(
                          leading: Icon(Icons.file_download_outlined),
                          title: Text('파일 다운로드'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text(
                            '파일 삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
