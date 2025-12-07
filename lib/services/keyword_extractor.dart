import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// C 함수 타입 정의
typedef InitFunc = ffi.Int32 Function(ffi.Pointer<Utf8> path);
typedef Init = int Function(ffi.Pointer<Utf8> path);

typedef ExtractFunc =
    ffi.Void Function(
      ffi.Pointer<Utf8> text,
      ffi.Pointer<Utf8> buffer,
      ffi.Int32 size,
    );
typedef Extract =
    void Function(ffi.Pointer<Utf8> text, ffi.Pointer<Utf8> buffer, int size);

class KeywordExtractor {
  static ffi.DynamicLibrary? _lib;
  static Init? _initFunc;
  static Extract? _extractFunc;
  static bool _isInitialized = false;

  static Future<String> _copyModelFiles() async {
    final dir = await getApplicationSupportDirectory();
    final modelDir = Directory(p.join(dir.path, 'kiwi_model'));

    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    const files = [
      'default.dict',
      'typo.dict',
      'multi.dict',
      'extract.mdl',
      'cong.mdl',
      'sj.morph',
      'combiningRule.txt',
      'dialect.dict',
    ];

    for (final f in files) {
      try {
        final fileData = await rootBundle.load('assets/model/$f');
        final bytes = fileData.buffer.asUint8List();
        await File(p.join(modelDir.path, f)).writeAsBytes(bytes);
      } catch (e) {
        print("모델 파일 복사 실패 ($f): $e");
      }
    }

    return modelDir.path;
  }

  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      String libPath = p.join(
        Directory.current.path,
        'assets',
        'libs',
        'libnative_analyzer.dylib',
      );
      if (Platform.isWindows) libPath = 'native_analyzer.dll';

      _lib = ffi.DynamicLibrary.open(libPath);

      _initFunc = _lib!
          .lookup<ffi.NativeFunction<InitFunc>>('init_kiwi')
          .asFunction();
      _extractFunc = _lib!
          .lookup<ffi.NativeFunction<ExtractFunc>>('extract_keywords')
          .asFunction();

      final modelPath = await _copyModelFiles();

      final pathPtr = modelPath.toNativeUtf8();
      final result = _initFunc!(pathPtr);
      calloc.free(pathPtr);

      if (result == 1) {
        _isInitialized = true;
        print("Kiwi 모델 초기화 성공: $modelPath");
      } else {
        print("Kiwi 모델 초기화 실패");
      }
    } catch (e) {
      print("Kiwi 로드/초기화 오류: $e");
    }
  }

  static Future<Set<String>> extract(String text) async {
    if (!_isInitialized) await init();

    if (_extractFunc == null) {
      print("형태소 분석기를 사용할 수 없습니다.");
      return {};
    }

    final textPtr = text.toNativeUtf8();
    // 결과 버퍼 (충분히 크게 설정)
    final bufferPtr = calloc<ffi.Uint8>(51200).cast<Utf8>();

    try {
      _extractFunc!(textPtr, bufferPtr, 51200);

      final resultStr = bufferPtr.toDartString();

      // [추가] 터미널에 추출된 단어 목록 출력
      print("[Kiwi 추출 결과]: $resultStr");

      if (resultStr.isEmpty) return {};

      return resultStr
          .split(',')
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim())
          .toSet();
    } catch (e) {
      print("분석 중 오류 발생: $e");
      return {};
    } finally {
      calloc.free(textPtr);
      calloc.free(bufferPtr);
    }
  }
}
