/// Core Transaction States and Invariants for ICARE Mobile & Web Clients.
/// Enforces safe financial submission lifecycle under unstable network conditions.
/// Complies with Strict Zero-Emoji Governance.
library;

enum TransactionState {
  /// Transaction registered locally with pre-assigned stable idempotency key.
  pending,

  /// Request transmitted to server; awaiting backend response or in-flight processing.
  processing,

  /// Server committed transaction to ledger; confirmed receipt received.
  confirmed,

  /// Permanent validation error or business rejection (HTTP 400, 401, 403, 422).
  /// Strictly forbidden to retry automatically or enqueue offline.
  failed,

  /// Network dropout, socket timeout, or 504 Gateway Timeout mid-flight.
  /// Outcome is unknown; client MUST verify against backend before allowing resubmission.
  outcomeUnknown,
}

class TransactionRecord {
  final String idempotencyKey;
  final String scope;
  final TransactionState state;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int? responseCode;
  final Map<String, dynamic>? receipt;
  final String? errorMessage;
  final bool isPermanentError;

  const TransactionRecord({
    required this.idempotencyKey,
    required this.scope,
    required this.state,
    required this.payload,
    required this.createdAt,
    this.responseCode,
    this.receipt,
    this.errorMessage,
    this.isPermanentError = false,
  });

  TransactionRecord copyWith({
    TransactionState? state,
    int? responseCode,
    Map<String, dynamic>? receipt,
    String? errorMessage,
    bool? isPermanentError,
  }) {
    return TransactionRecord(
      idempotencyKey: idempotencyKey,
      scope: scope,
      state: state ?? this.state,
      payload: payload,
      createdAt: createdAt,
      responseCode: responseCode ?? this.responseCode,
      receipt: receipt ?? this.receipt,
      errorMessage: errorMessage ?? this.errorMessage,
      isPermanentError: isPermanentError ?? this.isPermanentError,
    );
  }

  bool get isConfirmed => state == TransactionState.confirmed;
  bool get isProcessing => state == TransactionState.processing;
  bool get isPending => state == TransactionState.pending;
  bool get isVerificationRequired => state == TransactionState.outcomeUnknown;
  bool get isFailed => state == TransactionState.failed;

  String get stateDisplayName {
    switch (state) {
      case TransactionState.pending:
        return 'Pending Transmission';
      case TransactionState.processing:
        return 'Processing';
      case TransactionState.confirmed:
        return 'Confirmed';
      case TransactionState.failed:
        return 'Transaction Rejected';
      case TransactionState.outcomeUnknown:
        return 'Outcome Unknown - Verification Required';
    }
  }
}
