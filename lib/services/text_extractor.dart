import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // [필수] compute 함수 사용
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class TextExtractor {
  // [수정] 외부에서 호출하는 함수 (compute 사용)
  static Future<String> extractFromFile(File file) async {
    // 파일의 경로와 확장자만 넘겨서 백그라운드에서 실행
    return await compute(_extractTask, file.path);
  }

  // [신규] 백그라운드 아이솔레이트에서 실행될 실제 작업 함수
  static Future<String> _extractTask(String filePath) async {
    final file = File(filePath);
    final String extension = file.path.split('.').last.toLowerCase();

    try {
      final Uint8List bytes = await file.readAsBytes();

      if (extension == 'pdf') {
        return _extractFromPdf(bytes);
      } else if (extension == 'docx') {
        return _extractFromDocx(bytes);
      } else if (extension == 'txt' || extension == 'md') {
        return utf8.decode(bytes, allowMalformed: true);
      } else {
        return "";
      }
    } catch (e) {
      print("텍스트 추출 실패: $e");
      return "";
    }
  }

  static String _extractFromPdf(Uint8List bytes) {
    try {
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      return text;
    } catch (e) {
      return "";
    }
  }

  static String _extractFromDocx(Uint8List bytes) {
    try {
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      final ArchiveFile? documentXml = archive.findFile('word/document.xml');
      if (documentXml == null) return "";

      final contentBytes = documentXml.content as List<int>;
      final String xmlContent = utf8.decode(contentBytes, allowMalformed: true);
      final XmlDocument xmlDoc = XmlDocument.parse(xmlContent);
      final Iterable<XmlElement> textNodes = xmlDoc.findAllElements('w:t');

      StringBuffer buffer = StringBuffer();
      for (var node in textNodes) {
        buffer.write(node.innerText);
        buffer.write(" ");
      }
      return buffer.toString();
    } catch (e) {
      return "";
    }
  }
}
