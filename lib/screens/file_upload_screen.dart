import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:he_cloud_frontend/services/dictionary_manager.dart';
import 'package:provider/provider.dart';

import '../models/upload_task.dart';
import '../providers/app_provider.dart';
import '../services/keyword_extractor.dart';
import '../services/text_extractor.dart';

class FileUploadScreen extends StatefulWidget {
  const FileUploadScreen({super.key});

  @override
  State<FileUploadScreen> createState() => _FileUploadScreenState();
}

class _FileUploadScreenState extends State<FileUploadScreen> {
  final List<UploadTask> _tasks = [];
  bool _isPicking = false;
  bool _isUploading = false;

  final DictionaryManager _dictManager = DictionaryManager();

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 사전 미리 로드 (속도 향상)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      // Provider의 서비스들을 주입
      _dictManager.loadDictionaries(provider.apiService, provider.crypto);
    });
  }

  Future<void> _pickFiles() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
      );

      if (result == null) return;

      final newTasks = <UploadTask>[];

      for (final path in result.paths) {
        if (path == null) continue;
        final file = File(path);
        if (!file.existsSync()) continue;

        // 중복 방지
        final alreadyQueued = _tasks.any((task) => task.file.path == file.path);
        if (!alreadyQueued) {
          // [수정] 초기 상태를 'analyzing'으로 생성
          final task = UploadTask(file: file, status: UploadStatus.analyzing);
          setState(() => _tasks.add(task));
          newTasks.add(task);
        }
      }

      // [신규] 선택된 파일들을 즉시 비동기로 분석 시작
      for (final task in newTasks) {
        _analyzeTask(task);
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  // [신규] 자동 분석 함수
  Future<void> _analyzeTask(UploadTask task) async {
    try {
      // 1. 텍스트 추출
      final text = await TextExtractor.extractFromFile(task.file);

      if (text.trim().isEmpty) {
        // 텍스트가 없으면 그냥 준비 완료 처리 (키워드 없음)
        if (mounted) {
          setState(() => task.markStatus(UploadStatus.ready));
        }
        return;
      }

      // 2. 키워드 분석 (C++ Kiwi)
      final keywordsSet = await KeywordExtractor.extract(text);
      final keywordsList = keywordsSet.toList();
      keywordsList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          task.setKeywords(keywordsList);
          task.markStatus(UploadStatus.ready); // [중요] 자동으로 준비 완료 상태로 변경
        });
      }
    } catch (e) {
      print("자동 분석 실패: $e");
      if (mounted) {
        // 실패 시 검토 필요 상태로 두고 에러 메시지 표시 가능
        setState(
          () =>
              task.markStatus(UploadStatus.ready, error: "자동 분석 실패 (수동 입력 필요)"),
        );
      }
    }
  }

  Future<void> _openKeywordDialog(UploadTask task) async {
    // 분석 중일 때는 열지 않음
    if (task.status == UploadStatus.analyzing) return;

    final updated = await showDialog<List<String>>(
      context: context,
      builder: (_) => _KeywordEditorDialog(task: task),
    );

    if (updated != null) {
      setState(() {
        task.setKeywords(updated);
        // 사용자가 수정했으면 당연히 준비 완료
        task.markStatus(UploadStatus.ready);
      });
    }
  }

  Future<void> _startQueue() async {
    if (_isUploading) return;

    // 분석 중인 파일이 있으면 경고
    if (_tasks.any((t) => t.status == UploadStatus.analyzing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('아직 분석 중인 파일이 있습니다. 잠시만 기다려주세요.')),
      );
      return;
    }

    final readyTasks = _tasks
        .where((task) => task.status == UploadStatus.ready)
        .toList();

    if (readyTasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('업로드할 파일이 없습니다.')));
      return;
    }

    final provider = context.read<AppProvider>();
    setState(() => _isUploading = true);

    for (final task in readyTasks) {
      if (!mounted) break;
      setState(() {
        task.markStatus(UploadStatus.uploading, error: null);
      });
      try {
        await _uploadThroughProvider(provider, task);
        if (!mounted) return;
        setState(() {
          task.markStatus(UploadStatus.success);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          task.markStatus(UploadStatus.error, error: e.toString());
        });
      }
    }

    if (mounted) {
      setState(() => _isUploading = false);
    }
  }

  void _removeTask(UploadTask task) {
    if (_isUploading && task.status == UploadStatus.uploading) return;
    setState(() => _tasks.remove(task));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('파일 업로드')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '보안 업로드',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '파일을 선택하면 자동으로 분석됩니다. 카드를 눌러 키워드를 수정할 수 있습니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isPicking ? null : _pickFiles,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_isPicking ? '선택 중...' : '파일 선택'),
                  ),
                  const SizedBox(width: 12),
                  Text('선택된 파일 ${_tasks.length}개'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _tasks.isEmpty
                    ? const _EmptyQueuePlaceholder()
                    : ListView.separated(
                        itemBuilder: (_, index) => _TaskTile(
                          key: ValueKey(_tasks[index].file.path),
                          task: _tasks[index],
                          onTap: () => _openKeywordDialog(_tasks[index]),
                          onRemove: () => _removeTask(_tasks[index]),
                        ),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: _tasks.length,
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _startQueue,
                  icon: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isUploading ? '업로드 중...' : '업로드 시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadThroughProvider(
    AppProvider provider,
    UploadTask task,
  ) async {
    try {
      // 1. 사전 처리 및 벡터 생성
      final vectorsMap = await _dictManager.processKeywords(
        task.keywords,
        provider.apiService,
        provider.crypto,
      );

      // 2. 암호화 준비
      // [수정] 새 객체 생성(X) -> Provider에 있는(로그인된) 객체 사용(O)
      final crypto = provider.crypto;

      // 2-1. 파일 암호화 (AES)
      final fileBytes = await task.file.readAsBytes();
      final encFileBytes = crypto.encryptFileContent(fileBytes);
      final encFileName = crypto.encryptString(task.fileName);

      if (encFileBytes == null || encFileName == null) {
        throw Exception("파일 암호화 실패 (Master Key를 확인하세요)");
      }

      // 2-2. 인덱스 벡터 암호화 (HE - C++)
      List<Uint8List> encVectors = [];
      List<int> vectorVersions = [];

      for (var entry in vectorsMap.entries) {
        final version = entry.key;
        final rawVector = entry.value;

        final encVec = await crypto.encryptIndexVector(rawVector);
        if (encVec != null) {
          encVectors.add(encVec);
          vectorVersions.add(version);
        }
      }

      // 3. 서버 API 호출
      final api = provider.apiService;
      final success = await api.uploadFileWithVectors(
        cipherTitle: encFileName,
        mime: "application/octet-stream",
        folderId: provider.currentFolderId,
        encryptedFileBytes: encFileBytes,
        encryptedIndexVectors: encVectors,
        dictVersions: vectorVersions,
      );

      if (!success) throw Exception("서버 전송 실패");
    } catch (e) {
      print("업로드 중 오류: $e");
      rethrow;
    }
  }
}

// [UI] 타일 위젯 수정 (분석 중 표시 추가)
class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final UploadTask task;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = task.status.colorScheme;

    // 분석 중이면 로딩 표시, 아니면 상태 텍스트 표시
    final bool isAnalyzing = task.status == UploadStatus.analyzing;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAnalyzing ? null : onTap, // 분석 중에는 클릭 방지
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 아이콘
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.insert_drive_file_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 파일명
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.fileName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.file.path,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Theme.of(context).hintColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 상태 배지 (분석 중일 땐 스피너)
                  if (isAnalyzing)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(scheme.backgroundColor),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.status.label,
                        style: TextStyle(
                          color: Color(scheme.textColor),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    tooltip: '제거',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 키워드 미리보기 (분석 중일 땐 안내 문구)
              if (isAnalyzing)
                Text(
                  '문서 내용을 분석하고 있습니다...',
                  style: TextStyle(color: Colors.blue[700], fontSize: 13),
                )
              else if (task.keywords.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 1. 키워드 5개까지만 전개 (...)
                    ...task.keywords
                        .take(5)
                        .map(
                          (k) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              k,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),

                    // 2. 5개 넘으면 '+N' 텍스트 추가 (if 문 사용)
                    if (task.keywords.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4), // 살짝 높이 맞춤
                        child: Text(
                          '+${task.keywords.length - 5}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  '추출된 키워드가 없습니다. 눌러서 추가하세요.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// _KeywordEditorDialog는 기존과 동일하되, loadAndExtract 로직을 단순화할 수 있습니다.
// (이미 task.keywords에 값이 있으므로 바로 보여주기만 하면 됨)
class _KeywordEditorDialog extends StatefulWidget {
  const _KeywordEditorDialog({required this.task});
  final UploadTask task;

  @override
  State<_KeywordEditorDialog> createState() => _KeywordEditorDialogState();
}

class _KeywordEditorDialogState extends State<_KeywordEditorDialog> {
  final TextEditingController _controller = TextEditingController();
  List<String> _confirmedKeywords = [];

  @override
  void initState() {
    super.initState();
    // 이미 분석된 키워드를 가져옴
    _confirmedKeywords = List.of(widget.task.keywords);
  }

  void _addKeyword(String value) {
    final trimVal = value.trim();
    if (trimVal.isEmpty) return;
    if (!_confirmedKeywords.contains(trimVal)) {
      setState(() => _confirmedKeywords.add(trimVal));
    }
    _controller.clear();
  }

  void _removeKeyword(String value) {
    setState(() => _confirmedKeywords.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(widget.task.fileName, style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '키워드 추가',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addKeyword(_controller.text),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: _addKeyword,
            ),
            const SizedBox(height: 16),
            Text(
              '적용된 키워드 (${_confirmedKeywords.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _confirmedKeywords
                      .map(
                        (k) => InputChip(
                          label: Text(
                            k,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          onDeleted: () => _removeKeyword(k),
                          backgroundColor: Colors.blue[50],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _confirmedKeywords),
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// _EmptyQueuePlaceholder와 _QueueSummary는 기존 코드 유지
class _EmptyQueuePlaceholder extends StatelessWidget {
  const _EmptyQueuePlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("파일을 선택해주세요."));
  }
}
