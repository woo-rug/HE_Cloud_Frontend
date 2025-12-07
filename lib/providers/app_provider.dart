import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/crypto_manager.dart';
import '../models/folder_content.dart';
import '../services/api_service.dart';
import '../services/keyword_extractor.dart';

enum AuthState { checking, loggedOut, loggedIn }

class AppProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  final CryptoManager _crypto = CryptoManager();
  CryptoManager get crypto => _crypto;

  // --- Authentication State ---
  AuthState _authState = AuthState.checking;
  AuthState get authState => _authState;
  String _userEmail = "";
  String get userEmail => _userEmail;

  String? _registrationErrorMessage;
  String? get registrationErrorMessage => _registrationErrorMessage;

  // 회원가입 중 임시 저장 데이터
  String? _keysDir;
  String? _serverSalt;

  // --- Folder State ---
  FolderContent? _currentFolderContent;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentFolderId = 0;
  int get currentFolderId => _currentFolderId;

  final List<Map<String, dynamic>> _path = [
    {'id': 0, 'name': 'Home'},
  ];

  FolderContent? get currentFolderContent => _currentFolderContent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get path => _path;

  // [보안] 키 상태 확인용 Getters (디버깅용)
  Uint8List? get debugKek => _crypto.kek;
  Uint8List? get debugMasterKey => _crypto.masterKey;
  Uint8List? get debugHeSecretKey => _crypto.heSecretKey;

  AppProvider() {
    _warmUpHeavyServices();
    checkLoginStatus();
  }

  // ------------------------------------------------------------------------
  // [인증 관련]
  // ------------------------------------------------------------------------

  Future<void> checkLoginStatus() async {
    final token = await _apiService.getAccessToken();
    _authState = (token != null) ? AuthState.loggedIn : AuthState.loggedOut;

    // *주의*: 자동 로그인 시에는 비밀번호가 없어 키 복구가 안 될 수 있음.
    // 실제 앱에서는 SecureStorage 등을 활용해야 함.
    if (_authState == AuthState.loggedIn) {
      fetchFolder(0);
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _registrationErrorMessage = null;
    try {
      final data = await _apiService.login(email, password);
      if (data != null) {
        final salt = data['salt'];
        final encSk = data['enc_sk'];
        final encMk = data['enc_mk'];
        final mem = data['argon_mem'];
        final time = data['argon_time'];

        // 1. KEK 유도
        _crypto.deriveKek(password, salt, serverMem: mem, serverTime: time);

        // 2. Master Key 복구
        if (encMk != null) _crypto.decryptAndLoadMasterKey(encMk);

        // 3. SK 복구
        if (encSk != null) await _crypto.decryptAndLoadSecretKey(encSk);

        _authState = AuthState.loggedIn;
        fetchFolder(0);
        notifyListeners();
        _userEmail = email;
        return true;
      }
      _errorMessage = '로그인 실패';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '오류: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _crypto.clear(); // 보안 키 메모리 삭제
    _authState = AuthState.loggedOut;
    _currentFolderContent = null;
    _path.clear();
    _path.add({'id': 0, 'name': 'Home'});
    _userEmail = "";
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  // [회원가입 프로세스]
  // ------------------------------------------------------------------------

  // Step 1: 이메일 인증 요청 (키 생성 포함)
  Future<bool> requestVerificationCode(String email) async {
    try {
      _keysDir = await _crypto.generateHeKeys();
      String pk = await _crypto.getPublicKey(_keysDir!);
      return await _apiService.requestEmailAuth(email, pk);
    } catch (e) {
      print("Step 1 Error: $e");
      return false;
    }
  }

  // Step 2: 인증코드 확인
  Future<bool> submitVerificationCode(String email, String code) async {
    final data = await _apiService.verifyEmailCode(email, code);
    if (data != null) {
      _serverSalt = data['salt'];
      return true;
    }
    return false;
  }

  // Step 3: 최종 가입 (암호화된 키 전송)
  Future<bool> finalizeRegistration(String email, String password) async {
    if (_keysDir == null || _serverSalt == null) return false;
    try {
      _crypto.deriveKek(password, _serverSalt!);
      _crypto.generateMasterKey();

      String encMk = _crypto.encryptMasterKey();
      String encSk = _crypto.encryptHeSecretKeyInMemory();

      bool regSuccess = await _apiService.registerComplete(
        email,
        password,
        encSk,
        encMk,
      );
      if (!regSuccess) return false;

      // 자동 로그인 후 키 파일 업로드
      final loginData = await _apiService.login(email, password);
      if (loginData == null) return false;

      bool uploadSuccess = await _apiService.uploadKeys(
        loginData['access_token'],
        _keysDir!,
      );
      return uploadSuccess;
    } catch (e) {
      print(e);
      return false;
    }
  }

  // ------------------------------------------------------------------------
  // [폴더 및 파일 관리 (암호화 적용)]
  // ------------------------------------------------------------------------

  Future<void> fetchFolder(int folderId, {String? folderName}) async {
    _isLoading = true;
    _errorMessage = null;
    _currentFolderId = folderId;
    notifyListeners();

    try {
      final content = await _apiService.getFolderContents(folderId);

      if (content != null) {
        for (var folder in content.childFolders) {
          folder.decodedName = _crypto.decryptString(folder.encName);
        }

        for (var file in content.files) {
          file.decodedName = _crypto.decryptString(file.cipherTitle);
        }

        _currentFolderContent = content;
        _updatePath(folderId, folderName);
      } else {
        _currentFolderContent = null;
      }
    } catch (e) {
      _errorMessage = '$e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createNewFolder(String plainName) async {
    // [수정] 폴더 생성 시 이름을 암호화해서 전송
    final encryptedName = _crypto.encryptString(plainName);

    if (encryptedName == null) {
      _errorMessage = "암호화 실패: Master Key가 없습니다.";
      notifyListeners();
      return false;
    }

    final success = await _apiService.createFolder(
      encryptedName,
      _currentFolderId,
    );

    if (success) {
      // 생성 성공 시 현재 폴더 새로고침
      await fetchFolder(_currentFolderId);
    }
    return success;
  }

  // ------------------------------------------------------------------------
  // [폴더 및 파일 삭제]
  // ------------------------------------------------------------------------
  Future<bool> deleteItem(String type, int id) async {
    _isLoading = true;
    notifyListeners();

    final success = await _apiService.deleteItem(type, id);

    if (success) {
      // 삭제 성공 시 현재 폴더 목록 새로고침
      await fetchFolder(_currentFolderId);
    } else {
      await fetchFolder(_currentFolderId);
      _isLoading = false;
      notifyListeners();
    }
    return success;
  }

  // ------------------------------------------------------------------------
  // [Helper Methods]
  // ------------------------------------------------------------------------

  void _warmUpHeavyServices() {
    // Preload Kiwi on app start so later keyword extraction is instant.
    KeywordExtractor.init();
  }

  void _updatePath(int folderId, String? folderName) {
    if (folderId == 0) {
      // 홈으로 초기화
      _path.clear();
      _path.add({'id': 0, 'name': 'Home'});
    } else if (folderName != null) {
      final index = _path.indexWhere((p) => p['id'] == folderId);
      if (index != -1) {
        // 이미 경로에 있다면 그 뒤를 자름 (뒤로가기 효과)
        _path.removeRange(index + 1, _path.length);
      } else {
        // 새로운 경로 추가
        _path.add({'id': folderId, 'name': folderName});
      }
    }
  }

  // 이름이 너무 길 경우 자르는 헬퍼 함수
  String getShortenedName(String name) {
    if (name == 'Home') return 'Home';
    if (name.length > 100) {
      return '${name.substring(0, 100)}...';
    }
    return name;
  }
}
