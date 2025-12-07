import 'file_item.dart';
import 'folder_item.dart';

class FolderContent {
  final int folderId;
  final List<FolderItem> childFolders;
  final List<FileItem> files;

  FolderContent({
    required this.folderId,
    required this.childFolders,
    required this.files,
  });

  factory FolderContent.fromJson(Map<String, dynamic> json) {
    var childFoldersList = json['child_folders'] as List;
    var filesList = json['files'] as List;

    List<FolderItem> folders = childFoldersList.map((i) => FolderItem.fromJson(i)).toList();
    List<FileItem> files = filesList.map((i) => FileItem.fromJson(i)).toList();

    return FolderContent(
      folderId: json['folder_id'],
      childFolders: folders,
      files: files,
    );
  }
}
