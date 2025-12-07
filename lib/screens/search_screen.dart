import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // [필수] File 사용
import 'package:file_picker/file_picker.dart'; // [필수] 폴더 선택
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../providers/app_provider.dart';
import '../services/dictionary_manager.dart';
import '../services/keyword_extractor.dart';
import '../widgets/pattern_background.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DictionaryManager _dictManager = DictionaryManager();

  bool _isSearching = false;
  String _statusMessage = "";

  // 검색 결과 리스트
  final List<Map<String, dynamic>> _searchResults = [];
  // 파일별 점수 누적 맵 (FileID -> Score)
  final Map<int, int> _accumulatedScores = {};

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDictionaries();
    });
  }

  Future<void> _loadDictionaries() async {
    final provider = context.read<AppProvider>();
    await _dictManager.loadDictionaries(provider.apiService, provider.crypto);
    print("검색용 사전 로드 완료");
  }

  // [신규] 파일 다운로드 로직 (CloudBrowserScreen과 동일)
  Future<void> _handleDownload(int fileId, String decodedName) async {
    final provider = context.read<AppProvider>();
    final api = provider.apiService;
    final crypto = provider.crypto;

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '파일을 저장할 폴더를 선택하세요',
      );

      if (selectedDirectory == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다운로드 및 복호화 중...')));

      final encBytes = await api.downloadFile(fileId);
      if (encBytes == null) throw Exception("파일 다운로드 실패");

      // 임시 파일 저장
      final tempFileName = "temp_${DateTime.now().millisecondsSinceEpoch}.enc";
      final tempFile = File('$selectedDirectory/$tempFileName');
      await tempFile.writeAsBytes(encBytes);

      // 복호화
      final decryptedBytes = crypto.decryptFileContent(encBytes);
      if (decryptedBytes == null) throw Exception("복호화 실패 (키 오류)");

      // 실제 파일 저장 (중복 처리)
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

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 완료: ${realFile.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // [신규] 파일 삭제 로직
  Future<void> _handleDelete(int fileId, String name) async {
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
      // Provider를 통해 삭제 요청
      final success = await context.read<AppProvider>().deleteItem(
        'file',
        fileId,
      );

      if (!mounted) return;

      if (success) {
        // [중요] 검색 결과 리스트에서도 제거하여 UI 갱신
        setState(() {
          _searchResults.removeWhere((item) => item['file_id'] == fileId);
        });

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

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final provider = context.read<AppProvider>();
    final crypto = provider.crypto;
    final api = provider.apiService;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _accumulatedScores.clear();
      _statusMessage = "키워드 분석 중...";
    });

    // [신규] 비동기 요청 상태 관리 변수
    int pendingRequests = 0; // 현재 정보를 가져오고 있는 파일 수
    bool isServerEnded = false; // 서버가 끝났다는 신호를 보냈는지 여부

    // [신규] 종료 체크 함수 (서버도 끝났고, 파일 정보도 다 가져왔을 때만 종료)
    void checkCompletion() {
      if (isServerEnded && pendingRequests == 0) {
        _channel?.sink.close();
        if (mounted) {
          setState(() {
            _isSearching = false;
            _statusMessage = _searchResults.isEmpty ? "검색 결과가 없습니다." : "검색 완료";
          });
        }
      }
    }

    try {
      final keywords = await KeywordExtractor.extract(query);
      if (keywords.isEmpty) throw "유효한 검색어가 없습니다.";

      setState(() => _statusMessage = "검색 벡터 생성 및 암호화 중...");

      final vectorsMap = _dictManager.generateSearchVectors(keywords.toList());

      if (vectorsMap.isEmpty) {
        throw "사전에 등록되지 않은 검색어입니다.";
      }

      List<Uint8List> encVectors = [];
      List<int> vectorVersions = [];

      for (var entry in vectorsMap.entries) {
        final encVec = await crypto.encryptIndexVector(entry.value);
        if (encVec != null) {
          encVectors.add(encVec);
          vectorVersions.add(entry.key);
        }
      }

      setState(() => _statusMessage = "서버에 보안 쿼리 전송 중...");
      final queryPairs = await api.uploadSearchQueries(
        encryptedQueryVectors: encVectors,
        dictVersions: vectorVersions,
      );

      if (queryPairs == null) throw "쿼리 업로드 실패";

      _channel = api.connectToSearchStream();
      if (_channel == null) throw "검색 서버 연결 실패";

      setState(() => _statusMessage = "보안 검색 수행 중...");

      _channel!.sink.add(jsonEncode(queryPairs));

      _channel!.stream.listen(
        (message) {
          // async 제거 (내부에서 then 사용)
          try {
            final data = jsonDecode(message);

            if (data['error'] != null) {
              print("Server Error: ${data['error']}");
              return;
            }

            // [종료 신호 처리]
            if (data['status'] == 'end') {
              isServerEnded = true;
              checkCompletion(); // 작업 남았는지 확인 후 종료
              return;
            }

            final int fileId = data['file_id'];
            final String encScore = data['score'];

            final int partialScore = crypto.decryptSearchScore(encScore);

            if (partialScore > 0) {
              _accumulatedScores[fileId] =
                  (_accumulatedScores[fileId] ?? 0) + partialScore;
              final totalScore = _accumulatedScores[fileId]!;

              bool alreadyListed = _searchResults.any(
                (f) => f['file_id'] == fileId,
              );

              if (!alreadyListed && totalScore >= keywords.length) {
                // [핵심 수정] await 대신 카운터 증가 후 then 사용
                pendingRequests++;

                api
                    .getFileInfo(fileId)
                    .then((fileInfo) {
                      if (fileInfo != null && mounted) {
                        fileInfo['decoded_name'] = crypto.decryptString(
                          fileInfo['cipher_title'],
                        );

                        // 중복 체크 후 추가
                        if (!_searchResults.any(
                          (f) => f['file_id'] == fileId,
                        )) {
                          setState(() {
                            _searchResults.add(fileInfo);
                          });
                        }
                      }
                    })
                    .whenComplete(() {
                      // 성공하든 실패하든 카운터 감소 후 종료 체크
                      pendingRequests--;
                      checkCompletion();
                    });
              }
            }
          } catch (e) {
            print("Stream Error: $e");
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isSearching = false;
              _statusMessage = "서버 연결 끊김";
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _statusMessage = "오류: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PatternBackground(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 검색창
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _performSearch(),
                    enabled: !_isSearching,
                    decoration: InputDecoration(
                      hintText: '보안 검색 (파일 내용 검색)',
                      prefixIcon: const Icon(Icons.security),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSearching ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(16),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.black87),
                ),
              ),

            // 결과 리스트
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.manage_search,
                        size: 80,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final file = _searchResults[index];
                        final fileId = file['file_id'];
                        final fileName = file['decoded_name'] ?? '알 수 없는 파일';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.indigo,
                              child: Icon(Icons.lock_open, color: Colors.white),
                            ),
                            title: Text(fileName),
                            subtitle: Text('ID: $fileId • ${file['mime']}'),
                            // [수정] 메뉴 버튼으로 교체
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'download') {
                                  _handleDownload(fileId, fileName);
                                } else if (value == 'delete') {
                                  _handleDelete(fileId, fileName);
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
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
