// Professional Invoice PDF Viewer Screen
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../../utils/pdf_web.dart'
    if (dart.library.html) '../../utils/pdf_web_web.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soloshine/constants/app_constants.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart'; // For loading asset images
import '../../models/order.dart';

class PDFViewerScreen extends StatefulWidget {
  final Order order;

  const PDFViewerScreen({super.key, required this.order});

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> {
  File? _pdfFile;

  @override
  void initState() {
    super.initState();
    _generatePDF();
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/icons/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Add main invoice page
    pdf.addPage(_buildMainInvoicePage(logoImage));

    // Add per-ornament sections: details followed by images for each ornament
    if (widget.order.ornamentDetails.isNotEmpty) {
      await _addOrnamentSections(pdf);
    }

    // Save and display PDF
    try {
      if (kIsWeb) {
        try {
          await Printing.layoutPdf(onLayout: (format) async => pdf.save());
          return;
        } catch (_) {
          final bytes = await pdf.save();
          openPdfInNewTab(bytes);
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_${widget.order.id}.pdf');
      await file.writeAsBytes(await pdf.save());
      setState(() {
        _pdfFile = file;
      });
      await _displayPDF(file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  pw.Page _buildMainInvoicePage(pw.MemoryImage logoImage) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with logo and company info
            _buildHeader(logoImage),
            pw.SizedBox(height: 30),

            // Invoice title
            pw.Center(
              child: pw.Text(
                'INVOICE',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Order information section
            _buildOrderInfoSection(),
            pw.SizedBox(height: 25),

            // Order details table
            if (widget.order.ornamentDetails.isNotEmpty) ...[
              _buildOrderDetailsTable(),
              pw.SizedBox(height: 25),
            ],

            // Notes section
            if (widget.order.notes != null &&
                widget.order.notes!.isNotEmpty) ...[
              _buildNotesSection(),
              pw.SizedBox(height: 20),
            ],

            // Footer
            pw.Spacer(),
            _buildFooter(),
          ],
        );
      },
    );
  }

  pw.Widget _buildHeader(pw.MemoryImage logoImage) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Company logo and info
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logoImage, width: 80, height: 80),
            pw.SizedBox(height: 10),
            pw.Text(
              'MUTHAJI',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.Text(
              'MGRS. OF CZ GOLD JEWELRY ',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),

        // Invoice details
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Order #${widget.order.orderNo}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Date: ${_formatDateForInvoice(widget.order.createdAt)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
            if (widget.order.orderDate != null)
              pw.Text(
                'Order Date: ${_formatDateForInvoice(widget.order.orderDate!)}',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildOrderInfoSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Order Information',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Status:', widget.order.statusText),
                    pw.SizedBox(height: 5),
                    if (widget.order.orderType != null)
                      _buildInfoRow('Type:', widget.order.orderType!),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Created:',
                      _formatDateForInvoice(widget.order.createdAt),
                    ),
                    pw.SizedBox(height: 5),
                    if (widget.order.updatedAt != null)
                      _buildInfoRow(
                        'Updated:',
                        _formatDateForInvoice(widget.order.updatedAt!),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 60,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildOrderDetailsTable() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Order Details',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Item', isHeader: true),
                _buildTableCell('Material & Purity', isHeader: true),
                _buildTableCell('Weight (g)', isHeader: true),
                _buildTableCell('Quantity', isHeader: true),
              ],
            ),
            // Data rows
            ...widget.order.ornamentDetails.map(
              (detail) => pw.TableRow(
                children: [
                  _buildTableCell(detail.name),
                  _buildTableCell('${detail.material} ${detail.purity}'),
                  _buildTableCell(detail.weight.toString()),
                  _buildTableCell(detail.quantity.toString()),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 11,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey800 : PdfColors.grey700,
        ),
      ),
    );
  }

  pw.Widget _buildNotesSection() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes:',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            widget.order.notes!,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Thank you for choosing Muthaji!',
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            'Generated on ${_formatDateForInvoice(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  Future<void> _addOrnamentSections(pw.Document pdf) async {
    // Build sections per ornament: heading (category name), details box, then images grid
    // We will flow content across as many pages as needed.
    final sections = <pw.Widget>[];
    int itemIndex = 1;
    for (final d in widget.order.ornamentDetails) {
      // Heading with category name
      sections.add(
        pw.Text(
          'Ornament $itemIndex: ${d.name}',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      );
      sections.add(pw.SizedBox(height: 8));

      // Details box (without images)
      sections.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Material:', d.material.isNotEmpty ? d.material : '-'),
              pw.SizedBox(height: 4),
              _buildInfoRow('Purity:', d.purity),
              pw.SizedBox(height: 4),
              _buildInfoRow('Weight:', '${d.weight} g'),
              pw.SizedBox(height: 4),
              _buildInfoRow('Quantity:', d.quantity.toString()),
              if (d.remarks != null && d.remarks!.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                _buildInfoRow('Remarks:', d.remarks!),
              ],
            ],
          ),
        ),
      );

      // Images header
      sections.add(pw.SizedBox(height: 8));
      sections.add(
        pw.Text(
          'Images',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      );
      sections.add(pw.SizedBox(height: 6));

      // Download and display images for this ornament in a grid (2 per row)
      final itemImages = <pw.MemoryImage>[];
      for (final url in d.images) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            itemImages.add(pw.MemoryImage(response.bodyBytes));
          }
        } catch (_) {}
      }

      if (itemImages.isEmpty) {
        sections.add(
          pw.Text(
            'No images available',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
        );
      } else {
        // Grid 2 per row
        final rows = <pw.Widget>[];
        for (int i = 0; i < itemImages.length; i += 2) {
          rows.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10, right: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 5,
                    verticalRadius: 5,
                    child: pw.Image(itemImages[i], width: 230, height: 180, fit: pw.BoxFit.contain),
                  ),
                ),
                if (i + 1 < itemImages.length)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 5,
                      verticalRadius: 5,
                      child: pw.Image(itemImages[i + 1], width: 230, height: 180, fit: pw.BoxFit.contain),
                    ),
                  ),
              ],
            ),
          );
        }
        sections.addAll(rows);
      }

      // Separator between ornaments
      sections.add(pw.SizedBox(height: 18));
      sections.add(
        pw.Container(height: 1, color: PdfColors.grey300),
      );
      sections.add(pw.SizedBox(height: 18));

      itemIndex++;
    }

    // Lay out sections across multiple pages gracefully
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => sections,
      ),
    );
  }

  Future<void> _displayPDF(File file) async {
    await OpenFile.open(file.path);
  }

  // Removed unused _formatDate

  String _formatDateForInvoice(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${widget.order.orderNo ?? widget.order.id}'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_pdfFile != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () async {
                await Share.shareXFiles([
                  XFile(_pdfFile!.path),
                ], text: 'Sharing Pdf #${widget.order.id}');
              },
            ),
        ],
      ),
      body:
          _pdfFile == null
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Generating PDF...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.green.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Pdf Generated Successfully',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PDFView(
                      filePath: _pdfFile!.path,
                      enableSwipe: true,
                      swipeHorizontal: true,
                      autoSpacing: true,
                      pageFling: true,
                      pageSnap: true,
                      fitPolicy: FitPolicy.BOTH,
                      onError: (error) {
                        print('PDF View Error: $error');
                      },
                      onPageChanged: (page, total) {
                        print('Page $page of $total');
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
