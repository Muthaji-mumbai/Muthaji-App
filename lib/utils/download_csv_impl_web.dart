import 'package:web/web.dart' as web;

Future<void> downloadCsv(String content, String fileName) async {
  final href = 'data:text/csv;charset=utf-8,' + Uri.encodeComponent(content);
  final anchor = web.HTMLAnchorElement()
    ..href = href
    ..download = fileName;
  anchor.click();
}
