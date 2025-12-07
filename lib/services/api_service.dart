import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/folder_content.dart';

class ApiService {
  // 에뮬레이터: 10.0.2.2, iOS/데스크톱: 127.0.0.1
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  String? _accessToken;

  // ==========================================================
  // [회원가입 및 인증]
  // ==========================================================

  Future<bool> requestEmailAuth(String email, String pkBase64) async {
    try {
      await _dio.post(
        '/register/email',
        data: {"email": email, "pk": pkBase64},
      );
      return true;
    } catch (e) {
      print("Email auth error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyEmailCode(
    String email,
    String code,
  ) async {
    try {
      final response = await _dio.post(
        '/register/verify',
        data: {"email": email, "code": code},
      );
      return response.data;
    } catch (e) {
      print("Verify error: $e");
      return null;
    }
  }

  Future<bool> registerComplete(
    String email,
    String password,
    String encSk,
    String encMk,
  ) async {
    try {
      await _dio.post(
        '/register/complete',
        data: {
          "email": email,
          "password": password,
          "enc_sk": encSk,
          "enc_mk": encMk,
        },
      );
      return true;
    } catch (e) {
      print("Register complete error: $e");
      return false;
    }
  }

  // ==========================================================
  // [로그인 및 토큰 관리]
  // ==========================================================

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {"email": email, "password": password},
      );

      final data = response.data;
      _accessToken = data['access_token'];
      return data;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  Future<String?> getAccessToken() async {
    return _accessToken;
  }

  Future<void> logout() async {
    _accessToken = null;
  }

  // ==========================================================
  // [키 관리]
  // ==========================================================

  Future<bool> uploadKeys(String token, String keysDir) async {
    String relinPath = '$keysDir/relin_keys.k';
    String galPath = '$keysDir/gal_keys.k';

    if (!File(relinPath).existsSync() || !File(galPath).existsSync()) {
      return false;
    }

    try {
      FormData formData = FormData.fromMap({
        "relin_key": await MultipartFile.fromFile(
          relinPath,
          filename: "relin_keys.k",
        ),
        "galois_key": await MultipartFile.fromFile(
          galPath,
          filename: "gal_keys.k",
        ),
      });

      await _dio.post(
        '/keys/upload',
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );
      return true;
    } catch (e) {
      print("Key upload error: $e");
      return false;
    }
  }

  // ==========================================================
  // [폴더 관리]
  // ==========================================================

  Future<FolderContent?> getFolderContents(int folderId) async {
    if (_accessToken == null) return null;
    try {
      final response = await _dio.post(
        '/folder/list',
        data: {"folder_id": folderId},
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return FolderContent.fromJson(response.data);
    } catch (e) {
      print("Get folder contents error: $e");
      return null;
    }
  }

  Future<bool> createFolder(String name, int parentId) async {
    if (_accessToken == null) return false;
    try {
      await _dio.post(
        '/folder/create',
        data: {"enc_title": name, "parent_folder_id": parentId},
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return true;
    } catch (e) {
      print("Create folder error: $e");
      return false;
    }
  }

  // ==========================================================
  // [사전(Dictionary) 관리]
  // ==========================================================

  // 1. 사전 목록 가져오기 (다운로드)
  Future<List<dynamic>?> fetchMyDictionaries() async {
    if (_accessToken == null) return null;
    try {
      final res = await _dio.post(
        '/dict/download',
        data: {}, // 빈 객체를 보내면 서버가 전체 리스트 반환
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      // print(res.data['dictionaries']); //debug
      return res.data['dictionaries'];
    } catch (e) {
      print("Fetch dictionaries error: $e");
      return [];
    }
  }

  // 2. 사전 업데이트
  Future<bool> updateDictionary({
    required int version,
    required String encVocabBase64,
  }) async {
    if (_accessToken == null) return false;
    try {
      final requestBody = {
        "dictionaries": [
          {
            "version": version,
            "enc_vocab": encVocabBase64,
            "scheme": "BFV",
            "poly_degree": 8192,
            "slot_count": 8192,
            "encoding": "BATCH",
          },
        ],
      };

      await _dio.post(
        '/dict/upload',
        data: requestBody,
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return true;
    } catch (e) {
      print("Update dictionary error: $e");
      return false;
    }
  }

  // ==========================================================
  // [파일 업로드 (벡터 포함)] - 필수 구현
  // ==========================================================

  Future<bool> uploadFileWithVectors({
    required String cipherTitle,
    required String mime,
    required int folderId,
    required Uint8List encryptedFileBytes,
    required List<Uint8List> encryptedIndexVectors,
    required List<int> dictVersions,
  }) async {
    if (_accessToken == null) return false;

    try {
      // 1. 파일 데이터 준비
      final filePart = MultipartFile.fromBytes(
        encryptedFileBytes,
        filename: "file.enc",
      );

      // 2. 벡터 데이터 리스트 준비
      List<MultipartFile> vectorParts = [];
      for (int i = 0; i < encryptedIndexVectors.length; i++) {
        vectorParts.add(
          MultipartFile.fromBytes(
            encryptedIndexVectors[i],
            filename: "vector_$i.eiv",
          ),
        );
      }

      // 3. FormData 생성
      FormData formData = FormData.fromMap({
        "cipher_title": cipherTitle,
        "mime": mime,
        "folder_id": folderId,
        // JSON 문자열로 변환하여 전송 (backend: json.loads(dict_version_list))
        "dict_version_list": jsonEncode(dictVersions),
        "enc_file": filePart,
        "index_vectors": vectorParts,
      });

      await _dio.post(
        '/file/upload',
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return true;
    } on DioException catch (e) {
      print("Upload error response: ${e.response?.data}");
      return false;
    } catch (e) {
      print("Upload error: $e");
      return false;
    }
  }

  // ==========================================================
  // [보안 검색]
  // ==========================================================

  // 1. 암호화된 쿼리 벡터 업로드 -> Query ID 발급
  // 반환값: [{"query_id": "...", "dict_version": 1}, ...]
  Future<List<dynamic>?> uploadSearchQueries({
    required List<Uint8List> encryptedQueryVectors,
    required List<int> dictVersions,
  }) async {
    if (_accessToken == null) return null;

    try {
      List<MultipartFile> queryParts = [];
      for (int i = 0; i < encryptedQueryVectors.length; i++) {
        queryParts.add(
          MultipartFile.fromBytes(
            encryptedQueryVectors[i],
            filename: "query_$i.eiv",
          ),
        );
      }

      FormData formData = FormData.fromMap({
        "dict_versions": jsonEncode(dictVersions),
        "queries": queryParts,
      });

      final response = await _dio.post(
        '/upload/queries',
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );

      // 서버 응답 구조: {"queries": [...pairs...]}
      print(response.data);
      return response.data['queries'];
    } catch (e) {
      print("Search queries upload error: $e");
      return null;
    }
  }

  // 2. 웹소켓 연결 및 검색 스트림 반환
  WebSocketChannel? connectToSearchStream() {
    if (_accessToken == null) return null;

    final wsUrl =
        _baseUrl.replaceFirst('http', 'ws') + '/search?token=$_accessToken';

    try {
      return IOWebSocketChannel.connect(Uri.parse(wsUrl));
    } catch (e) {
      print("WebSocket connection failed: $e");
      return null;
    }
  }

  // 3. 파일 ID로 단일 파일 정보 조회 (검색 결과 표시용)
  Future<Map<String, dynamic>?> getFileInfo(int fileId) async {
    if (_accessToken == null) return null;
    try {
      final response = await _dio.post(
        '/file/$fileId',
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return response.data;
    } catch (e) {
      print("Get file info error: $e");
      return null;
    }
  }

  // ==========================================================
  // [파일 다운로드]
  // ==========================================================
  Future<Uint8List?> downloadFile(int fileId) async {
    if (_accessToken == null) return null;
    try {
      final response = await _dio.post(
        '/file/download',
        data: {"file_id": fileId},
        options: Options(
          headers: {"Authorization": "Bearer $_accessToken"},
          responseType: ResponseType.bytes, // [중요] 바이너리로 받기 설정
        ),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      print("Download file error: $e");
      return null;
    }
  }

  // ==========================================================
  // [파일/폴더 삭제]
  // ==========================================================
  Future<bool> deleteItem(String type, int id) async {
    if (_accessToken == null) return false;
    try {
      await _dio.post(
        '/delete',
        data: {"type": type, "id": id},
        options: Options(headers: {"Authorization": "Bearer $_accessToken"}),
      );
      return true;
    } catch (e) {
      print("Delete item error: $e");
      return false;
    }
  }
}
