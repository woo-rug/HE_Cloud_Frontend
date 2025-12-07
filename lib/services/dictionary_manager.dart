import 'dart:convert';
import '../services/api_service.dart';
import '../services/crypto_manager.dart';

class DictionaryData {
  int version;
  List<String> words;
  bool isModified;

  DictionaryData(this.version, this.words, {this.isModified = false});
}

class DictionaryManager {
  final List<DictionaryData> _dictionaries = [];
  static const int MAX_SLOT_COUNT = 8192;

  // 1. 서버에서 사전 로드 (인자로 서비스 받음)
  Future<void> loadDictionaries(ApiService api, CryptoManager crypto) async {
    _dictionaries.clear();
    // 전달받은 api 사용
    final serverDicts = await api.fetchMyDictionaries();

    if (serverDicts == null || serverDicts.isEmpty) {
      _dictionaries.add(DictionaryData(1, [], isModified: true));
      print("사전 없음");
      return;
    }

    for (var d in serverDicts) {
      String encVocab = d['enc_vocab'];
      // 전달받은 crypto 사용
      String jsonStr = crypto.decryptString(encVocab);
      List<String> words = [];
      if (jsonStr.isNotEmpty) {
        try {
          words = List<String>.from(jsonDecode(jsonStr));
        } catch (_) {}
      }
      _dictionaries.add(DictionaryData(d['version'], words));
    }
  }

  // 2. 키워드 등록 및 벡터 생성
  Future<Map<int, List<int>>> processKeywords(
    List<String> keywords,
    ApiService api,
    CryptoManager crypto,
  ) async {
    // (1) 없는 단어 사전에 추가
    for (String k in keywords) {
      bool exists = false;
      for (var dict in _dictionaries) {
        if (dict.words.contains(k)) {
          exists = true;
          break;
        }
      }
      if (!exists) _addToDictionary(k);
    }

    // (2) 변경된 사전 서버 동기화 (서비스 전달)
    await _syncDictionaries(api, crypto);

    // (3) 벡터 생성
    Map<int, List<int>> resultVectors = {};
    for (var dict in _dictionaries) {
      List<int> vector = List.filled(MAX_SLOT_COUNT, 0);
      bool hasKeyword = false;

      for (int i = 0; i < dict.words.length; i++) {
        if (keywords.contains(dict.words[i])) {
          vector[i] = 1;
          hasKeyword = true;
        }
      }

      if (hasKeyword) {
        resultVectors[dict.version] = vector;
      }
    }
    return resultVectors;
  }

  void _addToDictionary(String word) {
    var lastDict = _dictionaries.last;
    if (lastDict.words.length < MAX_SLOT_COUNT) {
      lastDict.words.add(word);
      lastDict.isModified = true;
    } else {
      int newVer = lastDict.version + 1;
      _dictionaries.add(DictionaryData(newVer, [word], isModified: true));
    }
  }

  Future<void> _syncDictionaries(ApiService api, CryptoManager crypto) async {
    for (var dict in _dictionaries) {
      if (dict.isModified) {
        String jsonStr = jsonEncode(dict.words);

        // 암호화 시도
        String? encVocab = crypto.encryptString(jsonStr);

        if (encVocab == null) {
          print("사전 암호화 실패: Master Key 없음");
          continue; // 암호화 못하면 업로드 불가
        }

        final success = await api.updateDictionary(
          version: dict.version,
          encVocabBase64: encVocab,
        );

        if (success) {
          dict.isModified = false;
          print("사전(v${dict.version}) 동기화 완료");
        }
      }
    }
  }

  Map<int, List<int>> generateSearchVectors(List<String> keywords) {
    Map<int, List<int>> resultVectors = {};

    for (var dict in _dictionaries) {
      List<int> vector = List.filled(MAX_SLOT_COUNT, 0);
      bool hasKeyword = false;

      // [디버그] 현재 사전의 단어 몇 개만 찍어보기 (마지막 5개)
      if (dict.words.isNotEmpty) {
        final lastWords = dict.words.length > 5
            ? dict.words.sublist(dict.words.length - 5)
            : dict.words;
        print("사전(v${dict.version}) 마지막 단어들: $lastWords");
      }

      for (int i = 0; i < dict.words.length; i++) {
        // [핵심] 정확히 어떤 단어와 비교하는지 확인
        for (var k in keywords) {
          if (dict.words[i] == k) {
            print("매칭 성공 ; 단어: '$k' (인덱스: $i)");
            vector[i] = 1;
            hasKeyword = true;
          } else if (dict.words[i].contains(k) || k.contains(dict.words[i])) {
            // 비슷해 보이는데 매칭 안 되는 경우 잡기 위해 (debug)
            // print("⚠️ 유사하지만 불일치: 사전='${dict.words[i]}' vs 검색어='$k'");
            // print("   -> 사전 코드: ${dict.words[i].runes}");
            // print("   -> 검색 코드: ${k.runes}");
          }
        }
      }

      if (hasKeyword) {
        // [추가 디버그] 1이 들어간 위치만 출력해서 확인
        List<int> onesIndices = [];
        for (int j = 0; j < vector.length; j++) {
          if (vector[j] == 1) onesIndices.add(j);
        }
        print("생성된 벡터에서 1인 위치: $onesIndices");

        resultVectors[dict.version] = vector;
      }
    }
    print("------------------------------------------");
    return resultVectors;
  }
}
