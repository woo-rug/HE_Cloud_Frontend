import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:argon2/argon2.dart';
import 'package:encrypt/encrypt.dart' as enc;

// FFI 함수 정의
typedef GenerateKeysFunc =
    ffi.Void Function(ffi.Pointer<Utf8> path, ffi.Int32 degree);
typedef GenerateKeys = void Function(ffi.Pointer<Utf8> path, int degree);

typedef DecryptScoreFunc =
    ffi.Int32 Function(
      ffi.Pointer<Utf8> encScore,
      ffi.Pointer<ffi.Uint8> skBytes,
      ffi.Int32 skSize,
    );
typedef DecryptScore =
    int Function(
      ffi.Pointer<Utf8> encScore,
      ffi.Pointer<ffi.Uint8> skBytes,
      int skSize,
    );

typedef EncryptVectorFunc =
    ffi.Int32 Function(
      ffi.Pointer<ffi.Int32> vec,
      ffi.Int32 vecLen,
      ffi.Pointer<Utf8> outBuf,
      ffi.Int32 outMaxLen,
      ffi.Pointer<Utf8> keysDir,
    );
typedef EncryptVector =
    int Function(
      ffi.Pointer<ffi.Int32> vec,
      int vecLen,
      ffi.Pointer<Utf8> outBuf,
      int outMaxLen,
      ffi.Pointer<Utf8> keysDir,
    );

class CryptoManager {
  late ffi.DynamicLibrary _lib;
  late GenerateKeys _generateKeys;
  late DecryptScore _decryptScore;
  late EncryptVector _encryptVector; // [NEW]

  bool _isFheLoaded = false;

  Uint8List? _kek;
  Uint8List? _masterKey;
  Uint8List? _heSecretKey;

  // Getter
  Uint8List? get kek => _kek;
  Uint8List? get masterKey => _masterKey;
  Uint8List? get heSecretKey => _heSecretKey;

  CryptoManager() {
    _loadNativeLibrary();
  }

  void _loadNativeLibrary() {
    try {
      String libraryPath = "";
      if (Platform.isMacOS) {
        // seal_wrapper.dylib (HE 라이브러리)
        libraryPath = p.join(
          Directory.current.path,
          'assets',
          'libs',
          'libseal_wrapper.dylib',
        );
        // 배포 환경 고려 시 경로 수정 필요할 수 있음
      } else if (Platform.isWindows) {
        libraryPath = 'seal_wrapper.dll';
      }

      print("[Crypto] HE 라이브러리 로드 시도: $libraryPath");

      // 라이브러리가 없으면 로드 건너뜀 (테스트용)
      if (!File(libraryPath).existsSync() && !Platform.isWindows) {
        print("[Crypto] 라이브러리 파일을 찾을 수 없습니다. (HE 기능 제한됨)");
        return;
      }

      _lib = ffi.DynamicLibrary.open(libraryPath);

      _generateKeys = _lib
          .lookup<ffi.NativeFunction<GenerateKeysFunc>>('generate_keys')
          .asFunction();

      _decryptScore = _lib
          .lookup<ffi.NativeFunction<DecryptScoreFunc>>('decrypt_score_memory')
          .asFunction();

      // [NEW] 벡터 암호화 함수 로드
      _encryptVector = _lib
          .lookup<ffi.NativeFunction<EncryptVectorFunc>>('encrypt_vector')
          .asFunction();

      _isFheLoaded = true;
      print("[Crypto] C++ HE 라이브러리 로드 완료");
    } catch (e) {
      print('[Crypto] C++ HE 라이브러리 로드 실패: $e');
    }
  }

  // ============================================================
  // Part A: AES 키 관리 (KEK & Master Key)
  // ============================================================

  void deriveKek(
    String password,
    String saltBase64, {
    int serverMem = 65536,
    int serverTime = 3,
  }) {
    final salt = base64Decode(saltBase64);
    int memoryPowerOf2 = (log(serverMem) / log(2)).round();

    var parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: serverTime,
      memoryPowerOf2: memoryPowerOf2,
    );

    var argon2 = Argon2BytesGenerator();
    argon2.init(parameters);

    var passwordBytes = utf8.encode(password);
    var keyBytes = Uint8List(32);
    argon2.generateBytes(passwordBytes, keyBytes, 0, keyBytes.length);

    _kek = keyBytes;
    print("[Crypto] KEK 생성 완료");
  }

  void generateMasterKey() {
    final key = enc.Key.fromSecureRandom(32);
    _masterKey = key.bytes;
    print("[Crypto] Master Key 생성 완료");
  }

  String encryptMasterKey() {
    if (_kek == null || _masterKey == null) {
      throw Exception("Keys not initialized");
    }
    return _encryptData(_masterKey!, _kek!);
  }

  void decryptAndLoadMasterKey(String encMkBase64) {
    if (_kek == null) throw Exception("KEK not initialized");
    try {
      final mkBytes = _decryptData(encMkBase64, _kek!);
      _masterKey = mkBytes;
      print("[Crypto] Master Key 복호화 완료");
    } catch (e) {
      print("[Crypto] MK 복호화 실패: $e");
      throw Exception("Failed to decrypt Master Key");
    }
  }

  // ============================================================
  // Part B: 데이터 암/복호화 (파일명, 파일내용, SK, AES)
  // ============================================================

  String? encryptString(String plainText) {
    if (_masterKey == null) return null;
    final key = enc.Key(_masterKey!);
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return base64Encode(iv.bytes + encrypted.bytes);
  }

  String decryptString(String cipherBase64) {
    if (_masterKey == null) return cipherBase64;
    try {
      final decoded = base64Decode(cipherBase64);
      if (decoded.length < 16) return cipherBase64;
      final ivBytes = decoded.sublist(0, 16);
      final cipherBytes = decoded.sublist(16);
      final key = enc.Key(_masterKey!);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
    } catch (e) {
      return cipherBase64;
    }
  }

  // [NEW] 파일 내용 암호화 (AES)
  // Return: IV(16bytes) + EncryptedBytes
  Uint8List? encryptFileContent(Uint8List fileBytes) {
    if (_masterKey == null) {
      print("[Crypto] Master Key 없음");
      return null;
    }

    try {
      final key = enc.Key(_masterKey!);
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

      // IV + Ciphertext 결합
      return Uint8List.fromList(iv.bytes + encrypted.bytes);
    } catch (e) {
      print("[Crypto] 파일 암호화 실패: $e");
      return null;
    }
  }

  String encryptHeSecretKeyInMemory() {
    if (_masterKey == null) throw Exception("Master Key not initialized");
    if (_heSecretKey == null) throw Exception("HE Secret Key not in memory");
    return _encryptData(_heSecretKey!, _masterKey!);
  }

  Future<void> decryptAndLoadSecretKey(String encSkBase64) async {
    if (_masterKey == null) throw Exception("Master Key not initialized");
    try {
      final skBytes = _decryptData(encSkBase64, _masterKey!);
      _heSecretKey = skBytes;
      print("[Crypto] HE Secret Key 로드 완료");
    } catch (e) {
      print("[Crypto] SK 복호화 실패: $e");
      throw Exception("Failed to decrypt SK");
    }
  }

  Uint8List? decryptFileContent(Uint8List encryptedData) {
    if (_masterKey == null) return null;

    try {
      if (encryptedData.length < 16) return null; // 데이터 손상

      final key = enc.Key(_masterKey!);

      // 앞 16바이트는 IV
      final ivBytes = encryptedData.sublist(0, 16);
      final cipherBytes = encryptedData.sublist(16);

      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      // 복호화 수행
      final decrypted = encrypter.decryptBytes(
        enc.Encrypted(cipherBytes),
        iv: iv,
      );
      return Uint8List.fromList(decrypted);
    } catch (e) {
      print("[Crypto] 파일 복호화 실패: $e");
      return null;
    }
  }

  // ============================================================
  // Part C: 동형암호(HE) 관련
  // ============================================================

  Future<String> generateHeKeys() async {
    if (!_isFheLoaded) throw Exception("HE Library not loaded");

    final dir = await getApplicationDocumentsDirectory();
    final keysDir = Directory('${dir.path}/keys');
    if (await keysDir.exists()) await keysDir.delete(recursive: true);
    await keysDir.create(recursive: true);

    print("[Crypto] 동형암호 키 생성 시작... 경로: ${keysDir.path}");
    final pathPtr = keysDir.path.toNativeUtf8();

    _generateKeys(pathPtr, 8192);
    calloc.free(pathPtr);

    final skFile = File('${keysDir.path}/secret_key.k');
    if (await skFile.exists()) {
      _heSecretKey = await skFile.readAsBytes();
      await skFile.delete();
      print("[Crypto] 로컬 SK 파일 삭제 완료");
    }

    return keysDir.path;
  }

  Future<String> getPublicKey(String keysDir) async {
    final file = File('$keysDir/public_key.k');
    return base64Encode(await file.readAsBytes());
  }

  // [NEW] 인덱스 벡터 암호화 (HE)
  Future<Uint8List?> encryptIndexVector(List<int> rawVector) async {
    if (!_isFheLoaded) {
      print("[Crypto] HE 라이브러리가 로드되지 않음");
      return null;
    }

    try {
      // 1. 키 경로 찾기 (Documents/keys)
      final dir = await getApplicationDocumentsDirectory();
      final keysDirPath = '${dir.path}/keys';

      // 2. 입력 벡터 준비
      final vecPtr = calloc<ffi.Int32>(rawVector.length);
      for (int i = 0; i < rawVector.length; i++) {
        vecPtr[i] = rawVector[i];
      }

      // 3. 출력 버퍼 준비 (충분히 크게, 예: 1MB)
      // SEAL 암호문은 꽤 큽니다 (수십~수백 KB)
      const maxOutLen = 1024 * 1024;
      final outBuf = calloc<ffi.Uint8>(maxOutLen).cast<Utf8>();
      final keysDirPtr = keysDirPath.toNativeUtf8();

      // 4. C++ 함수 호출
      // int encrypt_vector(int* vec, int vecLen, char* outBuf, int outMaxLen, char* keysDir)
      int writtenBytes = _encryptVector(
        vecPtr,
        rawVector.length,
        outBuf,
        maxOutLen,
        keysDirPtr,
      );

      // 5. 결과 처리
      Uint8List? result;
      if (writtenBytes > 0) {
        // 바이트 복사
        final ptr = outBuf.cast<ffi.Uint8>();
        result = Uint8List.fromList(ptr.asTypedList(writtenBytes));
      } else {
        print("[Crypto] 벡터 암호화 실패 (C++ 오류)");
      }

      // 6. 메모리 해제
      calloc.free(vecPtr);
      calloc.free(outBuf);
      calloc.free(keysDirPtr);

      return result;
    } catch (e) {
      print("[Crypto] 벡터 암호화 중 예외: $e");
      return null;
    }
  }

  int decryptSearchScore(String encScoreBase64) {
    if (_heSecretKey == null) {
      print("[Crypto] SK가 메모리에 없습니다.");
      return -1;
    }

    final encScorePtr = encScoreBase64.toNativeUtf8();
    final skPtr = calloc<ffi.Uint8>(_heSecretKey!.length);
    final skList = skPtr.asTypedList(_heSecretKey!.length);
    skList.setAll(0, _heSecretKey!);

    final score = _decryptScore(encScorePtr, skPtr, _heSecretKey!.length);

    calloc.free(encScorePtr);
    calloc.free(skPtr);

    return score;
  }

  // Helpers
  String _encryptData(Uint8List data, Uint8List keyBytes) {
    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    return base64Encode(iv.bytes + encrypted.bytes);
  }

  Uint8List _decryptData(String base64Data, Uint8List keyBytes) {
    final decoded = base64Decode(base64Data);
    final ivBytes = decoded.sublist(0, 16);
    final cipherBytes = decoded.sublist(16);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return Uint8List.fromList(
      encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv),
    );
  }

  void clear() {
    _kek = null;
    _masterKey = null;
    _heSecretKey = null;
    print("[Crypto] 모든 보안 키 메모리 소거 완료");
  }
}
