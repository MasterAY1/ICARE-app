import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/audit_api_service.dart';
import '../../data/models/audit_models.dart';
import 'audit_shared_widgets.dart';

class AuditExplorerTab extends ConsumerStatefulWidget {
  final String? scopedBranchId;

  const AuditExplorerTab({super.key, required this.scopedBranchId});

  @override
  ConsumerState<AuditExplorerTab> createState() => _AuditExplorerTabState();
}

class _AuditExplorerTabState extends ConsumerState<AuditExplorerTab> {
  final _searchCtrl = TextEditingController();
  UniversalExplorerResponseModel? _result;
  bool _loading = false;
  String? _searchError;

  String? _timelineLoanId;
  List<Map<String, dynamic>>? _timelineRows;
  bool _loadingTimeline = false;
  String? _timelineError;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: '360° Universal Search & Loan Lifecycle Timeline',
          subtitle: 'Cross-system forensic lookup by client code, member name, loan number, officer, or receipt reference.',
        ),
        const SizedBox(height: 12),
        IcareCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 680;
                  final input = TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _executeSearch(),
                    decoration: auditInputDecoration(
                      context,
                      label: 'Forensic Search Query',
                      hint: 'e.g. OGI-12-005, Adewale, REF-00382',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _result = null;
                                  _searchError = null;
                                });
                              },
                            )
                          : null,
                    ),
                  );
                  final btn = ElevatedButton.icon(
                    onPressed: _loading ? null : _executeSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.travel_explore, size: 18),
                    label: Text(
                      _loading ? 'Searching...' : 'Search Sub-Systems',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        input,
                        const SizedBox(height: 10),
                        btn,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 12),
                      btn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Examples:',
                    style: TextStyle(fontSize: 11.5, color: tokens.textMuted),
                  ),
                  for (final tag in const ['Disbursement', 'Withdrawal', 'Repayment'])
                    ActionChip(
                      label: Text(tag),
                      onPressed: () {
                        _searchCtrl.text = tag;
                        _executeSearch();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_searchError != null)
          buildAuditErrorCard(
            context,
            _searchError,
            onRetry: _executeSearch,
          )
        else if (_loading)
          const IcareTableSkeleton(rowCount: 6, hasFilterBar: false)
        else if (_result != null)
          _buildResults(tokens),
      ],
    );
  }

  Widget _buildResults(IcareSurfaceTokens tokens) {
    final res = _result!;
    if (!res.found) {
      return buildAuditEmptyCard(
        context,
        'No records matched "${res.query}" within your branch scope.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IcareCard(
          topAccentColor: tokens.successDot,
          backgroundColor: tokens.successBg,
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: tokens.successDot),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Matched records for "${res.query}" across core sub-systems.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tokens.successText,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (res.loans.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Loans'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.loans,
            columns: const [
              'Disbursement Date',
              'Loan Number',
              'Client Code',
              'Client Name',
              'Product',
              'Officer',
              'Branch',
              'Principal',
              'Status',
            ],
          ),
          const SizedBox(height: 10),
          _buildTimelineAccordion(res.loans, tokens),
          const SizedBox(height: 18),
        ],
        if (res.repayments.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Repayments'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.repayments,
            columns: const [
              'Repayment Date',
              'Loan Number',
              'Client Code',
              'Client Name',
              'Product',
              'Amount Paid',
              'Officer',
              'Branch',
              'Transaction Type',
              'Status',
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (res.savings.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Savings Ledger'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.savings,
            columns: const [
              'Date',
              'Client Code',
              'Client Name',
              'Ledger',
              'Deposit',
              'Withdrawal',
              'Available Balance',
              'Officer',
              'Branch',
              'Remarks',
              'Status',
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (res.fees.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Fee Ledger'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.fees,
            columns: const [
              'Date',
              'Client Code',
              'Client Name',
              'Fee Type',
              'Amount',
              'Officer',
              'Branch',
              'Reference',
              'Status',
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (res.treasuryTransactions.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Treasury Ledger'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.treasuryTransactions,
            columns: const [
              'Date',
              'Category',
              'Amount',
              'Officer',
              'Branch',
              'Reference',
              'Narration',
              'Status',
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (res.ledgerTransactions.isNotEmpty) ...[
          const IcareSectionHeader(title: 'Primary Vault & General Ledger'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.ledgerTransactions,
            columns: const [
              'Posting Date',
              'Journal Ref',
              'Narration',
              'Debit Account',
              'Credit Account',
              'Amount',
              'Branch',
              'Officer',
              'Status',
            ],
          ),
          const SizedBox(height: 18),
        ],
        if (res.auditLogs.isNotEmpty) ...[
          const IcareSectionHeader(title: 'System Activity Logs'),
          const SizedBox(height: 8),
          buildAuditDataDisplay(
            context,
            forceCardView: false,
            records: res.auditLogs,
            columns: res.auditLogs.first.keys.take(7).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineAccordion(
    List<Map<String, dynamic>> loans,
    IcareSurfaceTokens tokens,
  ) {
    return IcareCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(
          'Inspect Loan Lifecycle Audit Timelines',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
        children: loans.take(5).map((l) {
          final raw = l['_raw_record'] as Map<String, dynamic>? ?? {};
          final lid = (raw['loan_id'] ?? raw['id'] ?? '').toString();
          final label =
              '${l['Loan Number'] ?? 'Loan'} — ${l['Client Name'] ?? ''} (${l['Principal'] ?? ''})';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.timeline, size: 16),
                      label: const Text('Load Timeline'),
                      onPressed: lid.isEmpty ? null : () => _loadTimeline(lid),
                    ),
                  ],
                ),
                if (_timelineLoanId == lid) ...[
                  if (_loadingTimeline)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: IcareTableSkeleton(rowCount: 3, hasFilterBar: false),
                    )
                  else if (_timelineError != null)
                    buildAuditErrorCard(context, _timelineError)
                  else if (_timelineRows != null && _timelineRows!.isNotEmpty)
                    buildAuditDataDisplay(
                      context,
                      forceCardView: false,
                      records: _timelineRows!,
                      columns: _timelineRows!.first.keys.toList(),
                    )
                  else
                    Text(
                      'No lifecycle timeline events recorded.',
                      style: TextStyle(fontSize: 12, color: tokens.textMuted),
                    ),
                ],
                Divider(color: tokens.borderSubtle),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _executeSearch() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;
    setState(() {
      _loading = true;
      _searchError = null;
    });
    try {
      final res =
          await ref.read(auditApiServiceProvider).searchUniversalExplorer(
                query: term,
                branchId: widget.scopedBranchId,
              );
      if (mounted) {
        setState(() {
          _result = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = AppErrorDetails.from(e).message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadTimeline(String loanId) async {
    setState(() {
      _timelineLoanId = loanId;
      _loadingTimeline = true;
      _timelineError = null;
    });
    try {
      final res = await ref
          .read(auditApiServiceProvider)
          .getLoanTimeline(loanId: loanId);
      if (mounted) {
        setState(() {
          _timelineRows = res.timeline;
          _loadingTimeline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _timelineError = AppErrorDetails.from(e).message;
          _loadingTimeline = false;
        });
      }
    }
  }
}
