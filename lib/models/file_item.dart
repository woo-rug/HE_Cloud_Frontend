class FileItem {
  final int fileId;
  final String cipherTitle; // 서버에서 받은 암호화된 파일명
  final String mime;
  final DateTime uploadedAt;

  String decodedName = "";

  FileItem({
    required this.fileId,
    required this.cipherTitle,
    required this.mime,
    required this.uploadedAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      fileId: json['file_id'],
      cipherTitle: json['cipher_title'],
      mime: json['mime'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}
