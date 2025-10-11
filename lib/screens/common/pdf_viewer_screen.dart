import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_constants.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String? title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    print('PDF URL: ${widget.pdfUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(widget.title ?? 'PDF Viewer'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (!_isLoading && _errorMessage == null) ...[
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () {
                _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
              },
            ),
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: () {
                _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.pdfUrl,
            controller: _pdfViewerController,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            headers: const {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET',
            },
            onDocumentLoaded: (PdfDocumentLoadedDetails details) {
              setState(() {
                _totalPages = details.document.pages.count;
                _isLoading = false;
                _errorMessage = null;
              });
              print('PDF loaded successfully. Total pages: $_totalPages');
            },
            onPageChanged: (PdfPageChangedDetails details) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) async {
              print('PDF load failed: ${details.error}');
              print('Description: ${details.description}');
              
              // Automatically open in browser and close this screen
              try {
                final uri = Uri.parse(widget.pdfUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                  }
                } else {
                  // If can't launch, show error
                  setState(() {
                    _isLoading = false;
                    _errorMessage = 'Cannot open PDF. Please check the URL.';
                  });
                }
              } catch (e) {
                // If launching fails, show error
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Error opening PDF: $e';
                });
              }
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading PDF...',
                      style: AppConstants.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null)
            Container(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppConstants.errorColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load PDF',
                        style: AppConstants.headingSmall.copyWith(
                          color: AppConstants.errorColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: AppConstants.bodyMedium.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'URL: ${widget.pdfUrl}',
                        textAlign: TextAlign.center,
                        style: AppConstants.bodySmall.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _pdfViewerController.clearSelection();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppConstants.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final uri = Uri.parse(widget.pdfUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Cannot open PDF in browser'),
                                        backgroundColor: AppConstants.errorColor,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: AppConstants.errorColor,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Open in Browser'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _totalPages > 1 ? _buildNavigationBar() : null,
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: _currentPage > 1
                  ? () {
                      _pdfViewerController.previousPage();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
              iconSize: 32,
              color: _currentPage > 1
                  ? AppConstants.primaryColor
                  : Colors.grey,
            ),
            Text(
              'Page $_currentPage of $_totalPages',
              style: AppConstants.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages
                  ? () {
                      _pdfViewerController.nextPage();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
              iconSize: 32,
              color: _currentPage < _totalPages
                  ? AppConstants.primaryColor
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
