import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_motion.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../shared/utils/file_download_helper.dart';

/// Cross-platform export, native share, direct print, and in-app PDF preview helper
/// backed by `printing` and `share_plus`.
class ReportExportActionHelper {
  ReportExportActionHelper._();

  static Rect? _computeShareOrigin(BuildContext context) {
    final RenderObject? renderObj = context.findRenderObject();
    if (renderObj is RenderBox && renderObj.hasSize) {
      return renderObj.localToGlobal(Offset.zero) & renderObj.size;
    }
    return null;
  }

  /// Shares binary export bytes via the native OS share sheet (`share_plus`),
  /// preserving filename display via `fileNameOverrides`.
  static Future<ShareResultStatus?> shareBytes(
    BuildContext context, {
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
    String? text,
  }) async {
    final Uint8List u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final Rect? origin = _computeShareOrigin(context);
    final ShareResult result = await SharePlus.instance.share(
      ShareParams(
        text: text ?? 'ICARE Core Banking — $fileName',
        subject: subject ?? fileName,
        files: [
          XFile.fromData(
            u8,
            mimeType: mimeType,
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ),
    );
    return result.status;
  }

  /// Saves binary export bytes to device Downloads / Browser storage cleanly.
  static Future<String?> saveBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
  }) {
    return downloadBlobFile(bytes, fileName, mimeType);
  }

  /// Sends a fetched PDF document directly to the OS/browser print dialog.
  static Future<bool> printPdfBytes({
    required List<int> bytes,
    required String fileName,
  }) async {
    final Uint8List u8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    return Printing.layoutPdf(
      name: fileName,
      onLayout: (_) async => u8,
    );
  }
}

/// Interactive adaptive modal sheet displaying an AM-signed PDF financial statement
/// with native preview, pagination, print, share, and local download controls.
class ReportPdfPreviewSheet extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? signerSummary;
  final String fileName;
  final Future<List<int>> Function() loadPdfBytes;

  const ReportPdfPreviewSheet({
    super.key,
    required this.title,
    required this.subtitle,
    this.signerSummary,
    required this.fileName,
    required this.loadPdfBytes,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? signerSummary,
    required String fileName,
    required Future<List<int>> Function() loadPdfBytes,
  }) {
    return showIcareAdaptiveSheet<void>(
      context: context,
      mobileHeightFactor: 0.94,
      enablePeekSnap: false,
      desktopConstraints: const BoxConstraints(maxWidth: 920, maxHeight: 820),
      desktopInsetPadding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 20,
      ),
      builder: (_, __) => ReportPdfPreviewSheet(
        title: title,
        subtitle: subtitle,
        signerSummary: signerSummary,
        fileName: fileName,
        loadPdfBytes: loadPdfBytes,
      ),
    );
  }

  @override
  State<ReportPdfPreviewSheet> createState() => _ReportPdfPreviewSheetState();
}

class _ReportPdfPreviewSheetState extends State<ReportPdfPreviewSheet> {
  Uint8List? _pdfBytes;
  Object? _loadError;
  bool _isLoading = true;
  bool _isBusyAction = false;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final List<int> raw = await widget.loadPdfBytes();
      if (!mounted) return;
      setState(() {
        _pdfBytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDownload() async {
    final Uint8List? bytes = _pdfBytes;
    if (bytes == null || _isBusyAction) return;
    setState(() => _isBusyAction = true);
    try {
      final String? saved = await ReportExportActionHelper.saveBytes(
        bytes: bytes,
        fileName: widget.fileName,
        mimeType: 'application/pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF saved${saved != null ? ' ($saved)' : ''}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PDF download failed: ${AppErrorDetails.from(e).message}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusyAction = false);
    }
  }

  Future<void> _handleShare() async {
    final Uint8List? bytes = _pdfBytes;
    if (bytes == null || _isBusyAction) return;
    setState(() => _isBusyAction = true);
    try {
      await ReportExportActionHelper.shareBytes(
        context,
        bytes: bytes,
        fileName: widget.fileName,
        mimeType: 'application/pdf',
        subject: widget.title,
        text: '${widget.title} (${widget.subtitle})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Share failed: ${AppErrorDetails.from(e).message}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusyAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bool isMobile = MediaQuery.sizeOf(context).width < 768;

    return Material(
      color: tokens.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header Bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(bottom: BorderSide(color: tokens.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tokens.successBorder),
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_outlined,
                        color: tokens.successText,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: tokens.textPrimary,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.textMuted,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      icon: Icon(Icons.close, color: tokens.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                if (widget.signerSummary != null &&
                    widget.signerSummary!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.successBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: tokens.successBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 14,
                          color: tokens.successText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.signerSummary!,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.successText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: (_pdfBytes != null && !_isBusyAction)
                          ? _handleDownload
                          : null,
                      icon: const Icon(Icons.download_outlined, size: 15),
                      label: const Text(
                        'Save PDF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tokens.brandPrimaryDark,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: (_pdfBytes != null && !_isBusyAction)
                          ? _handleShare
                          : null,
                      icon: Icon(
                        Icons.share_outlined,
                        size: 15,
                        color: tokens.brandPrimary,
                      ),
                      label: Text(
                        'Share Statement',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: tokens.brandPrimary),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Preview Body
          Expanded(
            child: _buildPreviewContent(tokens),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(IcareSurfaceTokens tokens) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: tokens.brandPrimary),
              const SizedBox(height: 14),
              Text(
                'Preparing signed executive PDF statement...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadError != null || _pdfBytes == null) {
      final err = AppErrorDetails.from(
        _loadError ?? Exception('PDF document unavailable.'),
      );
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: tokens.dangerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.dangerBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: tokens.dangerDot, size: 28),
                const SizedBox(height: 10),
                Text(
                  err.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: tokens.dangerText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: tokens.dangerText),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _fetchPdf,
                  icon: Icon(Icons.refresh, size: 15, color: tokens.dangerText),
                  label: Text(
                    'Retry Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: tokens.dangerText,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: tokens.dangerBorder),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Uint8List bytes = _pdfBytes!;
    return PdfPreview(
      build: (_) async => bytes,
      allowPrinting: true,
      allowSharing: true,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      pdfFileName: widget.fileName,
      scrollViewDecoration: BoxDecoration(color: tokens.canvas),
      loadingWidget: Center(
        child: CircularProgressIndicator(color: tokens.brandPrimary),
      ),
      onError: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Unable to render PDF preview on this host. Use Save PDF or Share Statement above.\n(${AppErrorDetails.from(error).message})',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tokens.textSecondary),
          ),
        ),
      ),
    );
  }
}
