import 'download_csv_impl_stub.dart'
    if (dart.library.js_interop) 'download_csv_impl_web.dart'
    if (dart.library.io) 'download_csv_impl_io.dart' as impl;

Future<void> downloadCsv(String content, String fileName) => impl.downloadCsv(content, fileName);
