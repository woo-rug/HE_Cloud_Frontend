import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:argon2/argon2.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;

// FFI 함수 시그니처 정의
typedef GenerateKeysFunc =
    ffi.Void Function(ffi.Pointer<Utf8> path, ffi.Int32 degree);
typedef GenerateKeys = void Function(ffi.Pointer<Utf8> path, int degree);

class KeyManager {
  late ffi.DynamicLibrary _lib;
  late GenerateKeys _generateKeys;
  bool _isLoaded = false;

  KeyManager() {
    try {
      String libraryPath = "";
      if (Platform.isMacOS) {
        libraryPath = p.join(Directory.current.path, 'libseal_wrapper.dylib');
      } else if (Platform.isWindows) {
        libraryPath = p.join(Directory.current.path, 'seal_wrapper.dll');
      }

      print("[KeyManager] 라이브러리 로드 시도: $libraryPath");
      _lib = ffi.DynamicLibrary.open(libraryPath);

      _generateKeys = _lib
          .lookup<ffi.NativeFunction<GenerateKeysFunc>>('generate_keys')
          .asFunction();

      _isLoaded = true;
      print("[KeyManager] C++ 라이브러리 로드 성공");
    } catch (e) {
      print('[KeyManager] C++ 라이브러리 로드 실패: $e');
    }
  }

  // 1. 키 생성 (C++ 호출)
  Future<String> generateAndSaveKeys() async {
    if (!_isLoaded) throw Exception("라이브러리 로드 실패");

    final directory = await getApplicationDocumentsDirectory();
    final keysDir = Directory('${directory.path}/keys');

    // 기존 키 삭제 후 재생성 (깨끗한 상태 유지)
    if (await keysDir.exists()) {
      await keysDir.delete(recursive: true);
    }
    await keysDir.create(recursive: true);

    print("[KeyManager] 키 생성 시작... 저장 경로: ${keysDir.path}");

    final pathPtr = keysDir.path.toNativeUtf8();
    _generateKeys(pathPtr, 8192);
    calloc.free(pathPtr);

    print("[KeyManager] 키 생성 함수 종료. 파일 확인 중...");

    // [중요] 생성된 파일 목록 및 크기 확인 로그
    final files = keysDir.listSync();
    if (files.isEmpty) {
      print("[KeyManager] 경고: 생성된 파일이 없습니다!");
    } else {
      for (var entity in files) {
        if (entity is File) {
          int size = await entity.length();
          print("  - 파일: ${p.basename(entity.path)} (크기: $size bytes)");
        }
      }
    }

    return keysDir.path;
  }

  // 2. 공개키(PK) 읽어서 Base64 문자열로 반환
  Future<String> getPublicKey(String keysDir) async {
    final file = File('$keysDir/public_key.k');
    if (!await file.exists()) {
      throw Exception("Public Key file not found");
    }
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // 3. 비밀키(SK) 암호화 (Argon2 + AES)
  Future<String> encryptSecretKey(
    String keysDir,
    String password,
    String saltBase64,
  ) async {
    // A. Argon2로 비밀번호에서 AES 키 유도
    final salt = base64Decode(saltBase64);

    var parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 3,
      memoryPowerOf2: 16, // 65536KB
    );

    var argon2 = Argon2BytesGenerator();
    argon2.init(parameters);

    var passwordBytes = utf8.encode(password);
    var keyBytes = Uint8List(32); // AES-256 key
    argon2.generateBytes(passwordBytes, keyBytes, 0, keyBytes.length);

    // B. AES 암호화
    final skFile = File('$keysDir/secret_key.k');
    if (!await skFile.exists()) {
      throw Exception("Secret Key file not found");
    }
    final skBytes = await skFile.readAsBytes();

    final key = enc.Key(keyBytes);
    final iv = enc.IV.fromLength(16); // 랜덤 IV 생성
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(skBytes, iv: iv);

    // IV + 암호문을 합쳐서 반환 (나중에 복호화할 때 IV가 필요함)
    // 실제로는 IV를 따로 저장하거나 앞부분에 붙이는 방식 사용
    final combined = iv.bytes + encrypted.bytes;
    return base64Encode(combined);
  }

  Uint8List deriveKey(String password, String saltBase64) {
    final salt = base64Decode(saltBase64);
    var parameters = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 3,
      memoryPowerOf2: 16,
    );

    var argon2 = Argon2BytesGenerator();
    argon2.init(parameters);

    var passwordBytes = utf8.encode(password);
    var keyBytes = Uint8List(32);
    argon2.generateBytes(passwordBytes, keyBytes, 0, keyBytes.length);

    return keyBytes;
  }
}
