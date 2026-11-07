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

  static String _cleanHumanMessage(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'The system could not complete this request right now. Please tap Retry to try again.';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('dioexception') ||
        lower.contains('requestoptions') ||
        lower.contains('status code of') ||
        lower.contains('developer.mozilla.org') ||
        lower.contains('validatestatus') ||
        lower.contains('bad syntax') ||
        lower.contains('client error')) {
      return 'The system could not load the latest branch numbers right now. Please tap Retry to try again.';
    }
    return raw.trim();
  }

  static String _cleanHumanTitle(String? raw, int? statusCode) {
    if (raw != null && raw.trim().isNotEmpty && !raw.toLowerCase().contains('dioexception')) {
      return raw.trim();
    }
    if (statusCode == 400) return 'Unable to Load Latest Branch Numbers';
    if (statusCode == 401 || statusCode == 403) return 'Access Not Allowed';
    if (statusCode == 404) return 'Record Not Found';
    if (statusCode != null && statusCode >= 500) return 'Server Connection Delay';
    return 'Notice';
  }

  /// Factory to extract structured ICARE error details from any error object.
  factory AppErrorDetails.from(dynamic error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final rawMsg = responseData['message']?.toString() ?? responseData['detail']?.toString();
        return AppErrorDetails(
          errorCode: responseData['error_code']?.toString() ?? 'API_ERROR',
          title: _cleanHumanTitle(responseData['title']?.toString(), statusCode),
          message: _cleanHumanMessage(rawMsg),
          action: responseData['action']?.toString() ?? 'Please tap Retry to try again.',
          rawDetails: responseData['details'],
        );
      } else if (responseData is String) {
        try {
          final decoded = jsonDecode(responseData);
          if (decoded is Map<String, dynamic>) {
            final rawMsg = decoded['message']?.toString() ?? decoded['detail']?.toString();
            return AppErrorDetails(
              errorCode: decoded['error_code']?.toString() ?? 'API_ERROR',
              title: _cleanHumanTitle(decoded['title']?.toString(), statusCode),
              message: _cleanHumanMessage(rawMsg),
              action: decoded['action']?.toString() ?? 'Please tap Retry to try again.',
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
          message: 'Unable to reach the ICARE banking server right now.',
          action: 'Please check your internet connection and tap Retry.',
        );
      }

      if (statusCode == 401 || statusCode == 403) {
        return const AppErrorDetails(
          errorCode: 'ACCESS_RESTRICTED',
          title: 'Access Restricted',
          message: 'You do not have administrative permission to view this section.',
          action: 'Please log in with an administrator account.',
        );
      }

      if (statusCode == 400) {
        return const AppErrorDetails(
          errorCode: 'BAD_REQUEST',
          title: 'Unable to Load Latest Branch Numbers',
          message: 'The system could not load the latest branch numbers right now. Please tap Retry to try again.',
          action: 'If this continues, please wait a moment and tap Retry.',
        );
      }

      return AppErrorDetails(
        errorCode: 'HTTP_${statusCode ?? 500}',
        title: _cleanHumanTitle(null, statusCode),
        message: _cleanHumanMessage(error.message),
        action: 'Please tap Retry to try again.',
      );
    }

    if (error is String) {
      return AppErrorDetails(
        errorCode: 'OPERATION_ERROR',
        title: 'Notice',
        message: _cleanHumanMessage(error),
        action: 'Please tap Retry to try again.',
      );
    }

    return AppErrorDetails(
      errorCode: 'UNEXPECTED_ERROR',
      title: 'Action Could Not Complete',
      message: _cleanHumanMessage(error?.toString()),
      action: 'Please tap Retry. If the issue persists, refresh the page.',
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
                  color: Colors.blue.shade50.withValues(alpha: 0.5),
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
