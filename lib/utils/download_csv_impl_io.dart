import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadCsv(String content, String fileName) async {
  final dir = await getDownloadsDirectory();
  if (dir == null) {
    throw Exception('Downloads directory not found');
  }
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
}
