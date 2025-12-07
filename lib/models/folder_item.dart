class FolderItem {
  final int folderId;
  final String encName;
  final DateTime createdAt;
  String decodedName = "";

  FolderItem({
    required this.folderId,
    required this.encName,
    required this.createdAt,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      folderId: json['folder_id'],
      encName: json['enc_name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
