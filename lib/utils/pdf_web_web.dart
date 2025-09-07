import 'dart:typed_data';
import 'dart:html' as html;

// Web implementation using a data URL to open in a new tab
void openPdfInNewTab(Uint8List bytes) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  html.Url.revokeObjectUrl(url);
}
