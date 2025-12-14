import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadCsv(String content, String fileName) async {
  Directory? dir;
  
  // Try to get the Downloads directory first
  dir = await getDownloadsDirectory();
  
  // If that fails, try to get the external storage directory and create Downloads folder
  if (dir == null) {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir != null) {
      // Navigate to the parent directory (usually /storage/emulated/0)
      final parentPath = externalDir.parent.path;
      dir = Directory('$parentPath/Download');
      
      // Create the Downloads directory if it doesn't exist
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }
  }
  
  // Last resort: use application documents directory
  if (dir == null) {
    dir = await getApplicationDocumentsDirectory();
  }
  
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
}
