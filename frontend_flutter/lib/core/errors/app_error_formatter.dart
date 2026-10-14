import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Structured error model representing enterprise ICARE core errors.
class AppErrorDetails {
  final String errorCode;
  final String title;
  final String message;
  final String action;
  final dynamic rawDetails;

  const AppErrorDetails({
    required this.errorCode,
    required this.title,
    required this.message,
    required this.action,
    this.rawDetails,
  });

  /// Factory to extract structured ICARE error details from any error object.
  factory AppErrorDetails.from(dynamic error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        return AppErrorDetails(
          errorCode: responseData['error_code']?.toString() ?? 'API_ERROR',
          title: responseData['title']?.toString() ?? 'Operation Notice',
          message: responseData['message']?.toString() ??
              (responseData['detail']?.toString() ?? 'An error occurred while processing this request.'),
          action: responseData['action']?.toString() ?? 'Please verify your details and try again.',
          rawDetails: responseData['details'],
        );
      } else if (responseData is String) {
        try {
          final decoded = jsonDecode(responseData);
          if (decoded is Map<String, dynamic>) {
            return AppErrorDetails(
              errorCode: decoded['error_code']?.toString() ?? 'API_ERROR',
              title: decoded['title']?.toString() ?? 'Operation Notice',
              message: decoded['message']?.toString() ??
                  (decoded['detail']?.toString() ?? responseData),
              action: decoded['action']?.toString() ?? 'Please check your input and try again.',
              rawDetails: decoded['details'],
            );
          }
        } catch (_) {}
      }

      // Dio connection errors
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return const AppErrorDetails(
          errorCode: 'NETWORK_CONNECTION_TIMEOUT',
          title: 'Connection Delay',
          message: 'Unable to reach the ICARE core banking server.',
          action: 'Please check your internet connection and retry in a moment.',
        );
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return const AppErrorDetails(
          errorCode: 'ACCESS_RESTRICTED',
          title: 'Access Restricted',
          message: 'You do not have administrative permission to complete this action.',
          action: 'Please log in with appropriate role credentials or contact your supervisor.',
        );
      }

      return AppErrorDetails(
        errorCode: 'HTTP_${statusCode ?? 500}',
        title: 'Request Failed',
        message: error.message ?? 'The server responded with an error.',
        action: 'Please verify the transaction details and retry.',
      );
    }

    if (error is String) {
      return AppErrorDetails(
        errorCode: 'OPERATION_ERROR',
        title: 'Notice',
        message: error,
        action: 'Please verify your input and try again.',
      );
    }

    return AppErrorDetails(
      errorCode: 'UNEXPECTED_ERROR',
      title: 'Action Could Not Complete',
      message: error?.toString() ?? 'An unexpected system error occurred.',
      action: 'Please try again. If the issue persists, contact technical support.',
    );
  }
}

/// Centralized UI Presenter for corporate error dialogs and notifications.
/// Enforces Zero-Emoji Governance (Clean corporate typography and SVG/Material icons).
class AppErrorFormatter {
  /// Displays a modal corporate alert dialog explaining the error and next steps.
  static Future<void> showErrorDialog(BuildContext context, dynamic error) {
    final details = AppErrorDetails.from(error);

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        final theme = Theme.of(ctx);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          actionsPadding: const EdgeInsets.all(16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  details.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                details.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.help_outline_rounded,
                      size: 18,
                      color: Colors.blue.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        details.action,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (details.errorCode.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Code: ${details.errorCode}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Dismiss'),
            ),
          ],
        );
      },
    );
  }

  /// Displays an informational toast / SnackBar for quick notifications.
  static void showSnackBar(BuildContext context, dynamic error) {
    final details = AppErrorDetails.from(error);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.grey.shade900,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details.title,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              details.message,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.blue.shade200,
          onPressed: () {},
        ),
      ),
    );
  }
}
