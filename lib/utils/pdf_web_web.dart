import 'dart:typed_data';
import 'dart:convert' show base64Encode;
import 'package:web/web.dart' as web;

// Web implementation using a data URL to open in a new tab
void openPdfInNewTab(Uint8List bytes) {
  final dataUrl = 'data:application/pdf;base64,' + base64Encode(bytes);
  web.window.open(dataUrl, '_blank');
}
