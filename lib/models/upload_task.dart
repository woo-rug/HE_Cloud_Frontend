import 'dart:io';

enum UploadStatus {
  analyzing, // [신규] 분석 중
  pendingReview, // 검토 대기 (분석 실패 시 등)
  ready, // 준비 완료 (자동 분석 완료 시)
  uploading,
  success,
  error,
}

extension UploadStatusExtension on UploadStatus {
  String get label {
    switch (this) {
      case UploadStatus.analyzing:
        return '분석 중...';
      case UploadStatus.pendingReview:
        return '검토 필요';
      case UploadStatus.ready:
        return '준비 완료';
      case UploadStatus.uploading:
        return '업로드 중';
      case UploadStatus.success:
        return '완료';
      case UploadStatus.error:
        return '오류';
    }
  }

  // 상태별 색상 정의 (배경색, 글자색)
  ({int backgroundColor, int textColor}) get colorScheme {
    switch (this) {
      case UploadStatus.analyzing:
        return (backgroundColor: 0xFFE3F2FD, textColor: 0xFF1565C0); // 파란색
      case UploadStatus.pendingReview:
        return (backgroundColor: 0xFFFFF3E0, textColor: 0xFFEF6C00); // 주황색
      case UploadStatus.ready:
        return (backgroundColor: 0xFFE8F5E9, textColor: 0xFF2E7D32); // 초록색
      case UploadStatus.uploading:
        return (backgroundColor: 0xFFE1F5FE, textColor: 0xFF0277BD); // 하늘색
      case UploadStatus.success:
        return (backgroundColor: 0xFFE0F2F1, textColor: 0xFF00695C); // 틸(Teal)
      case UploadStatus.error:
        return (backgroundColor: 0xFFFFEBEE, textColor: 0xFFC62828); // 빨간색
    }
  }
}

class UploadTask {
  final File file;
  UploadStatus status;
  List<String> keywords;
  String? errorMessage;

  UploadTask({
    required this.file,
    this.status = UploadStatus.analyzing, // [수정] 기본값을 '분석 중'으로 변경
    this.keywords = const [],
    this.errorMessage,
  });

  String get fileName =>
      file.path.split('/').last; // 혹은 Platform.pathSeparator 사용

  void setKeywords(List<String> newKeywords) {
    keywords = newKeywords;
  }

  void markStatus(UploadStatus newStatus, {String? error}) {
    status = newStatus;
    errorMessage = error;
  }
}
