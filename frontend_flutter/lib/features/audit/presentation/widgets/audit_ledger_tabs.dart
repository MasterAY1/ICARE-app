import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/models/audit_models.dart';
import '../providers/audit_providers.dart';
import 'audit_shared_widgets.dart';

class AuditLedgerTabContext {
  final String defaultBranchId;
  final List<String> branchOptions;
  final List<String> officerOptions;
  final List<ProductOptionModel> products;
  final bool canSwitchBranch;
  final bool isOfficer;
  final String? Function(String branchName) resolveBranchId;
  final String? Function(String officerDisplay) resolveOfficerId;
  final String? Function(String productName) resolveProductId;

  const AuditLedgerTabContext({
    required this.defaultBranchId,
    required this.branchOptions,
    required this.officerOptions,
    required this.products,
    required this.canSwitchBranch,
    required this.isOfficer,
    required this.resolveBranchId,
    required this.resolveOfficerId,
    required this.resolveProductId,
  });
}

class AuditFeesTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditFeesTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditFeesTab> createState() => _AuditFeesTabState();
}

class _AuditFeesTabState extends ConsumerState<AuditFeesTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _feeType = 'ALL';
  String _branch = '';
  String _officer = 'All Officers';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _feeType,
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      officerId: widget.ctx.resolveOfficerId(_officer),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(feeLedgerProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Fees Audit Ledger',
          subtitle: 'Itemized trail of loan origination fees, passbook charges, and administrative levies.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 190,
                child: buildAuditDropdown(
                  context,
                  label: 'Fee Bucket',
                  value: _feeType,
                  items: const [
                    'ALL',
                    'PROCESSING_FEE',
                    'MARKUP_11',
                    'MARKUP_20',
                    'CONTINGENCY',
                    'PASSBOOK',
                    'CREDIT_FORM_DAMAGE',
                    'BONUS',
                  ],
                  onChanged: (v) => setState(() => _feeType = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Officer',
                  value: _officer,
                  items: widget.ctx.officerOptions,
                  enabled: !widget.ctx.isOfficer,
                  onChanged: (v) => setState(() => _officer = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Client, ref, code...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(feeLedgerProvider(query)),
          ),
          data: (data) {
            final m = data.metrics;
            const cols = [
              'Date',
              'Client Code',
              'Client Name',
              'Fee Type',
              'Amount',
              'Officer',
              'Branch',
              'Reference',
              'Status',
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Total Fees',
                    formatAuditNaira(m.totalAmount),
                    highlightEmerald: true,
                  ),
                  AuditKpiItem('Transactions', '${m.totalCount}'),
                  AuditKpiItem('Average Fee', formatAuditNaira(m.averageAmount)),
                  AuditKpiItem('Last Posting', m.lastTransactionDate),
                  AuditKpiItem(
                    'Highest Fee',
                    formatAuditNaira(m.highestAmount),
                    topBorderColor: tokens.brandPrimary,
                  ),
                ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: data.records,
                  columns: cols,
                  forceCardView: _forceCards,
                  emptyMessage: 'No fee entries match the selected criteria.',
                ),
                if (data.records.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => exportAuditCsv(
                        data.records,
                        'fees_${_feeType.toLowerCase()}',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text('Export $_feeType CSV'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditTreasuryTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditTreasuryTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditTreasuryTab> createState() => _AuditTreasuryTabState();
}

class _AuditTreasuryTabState extends ConsumerState<AuditTreasuryTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _category = 'ALL';
  String _branch = '';
  String _officer = 'All Officers';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _category,
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      officerId: widget.ctx.resolveOfficerId(_officer),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(treasuryLedgerProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Treasury & Inter-Branch Movements Audit',
          subtitle: 'Bank deposits, withdrawals, Head Office transfers, salaries, and branch expenses.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 210,
                child: buildAuditDropdown(
                  context,
                  label: 'Treasury Category',
                  value: _category,
                  items: const [
                    'ALL',
                    'BANK_DEPOSIT',
                    'BANK_WITHDRAWAL',
                    'OFFICE_EXPENSE',
                    'STAFF_SALARY',
                    'HO_TRANSFER_IN',
                    'HO_TRANSFER_OUT',
                    'BRANCH_TRANSFER_IN',
                    'BRANCH_TRANSFER_OUT',
                    'OTHER_AREA_TRANSFER',
                    'ASSET_PROGRAM',
                    'PRODUCT_FINANCE',
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Officer',
                  value: _officer,
                  items: widget.ctx.officerOptions,
                  enabled: !widget.ctx.isOfficer,
                  onChanged: (v) => setState(() => _officer = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Ref, narration, officer...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(treasuryLedgerProvider(query)),
          ),
          data: (data) {
            final m = data.metrics;
            const cols = [
              'Date',
              'Category',
              'Amount',
              'Officer',
              'Branch',
              'Reference',
              'Narration',
              'Status',
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Total Volume',
                    formatAuditNaira(m.totalAmount),
                    highlightEmerald: true,
                  ),
                  AuditKpiItem('Transactions', '${m.totalCount}'),
                  AuditKpiItem(
                      'Average Entry', formatAuditNaira(m.averageAmount)),
                  AuditKpiItem('Last Posting', m.lastTransactionDate),
                  AuditKpiItem(
                      'Largest Entry', formatAuditNaira(m.highestAmount)),
                ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: data.records,
                  columns: cols,
                  forceCardView: _forceCards,
                  emptyMessage: 'No treasury records match the selected filters.',
                ),
                if (data.records.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => exportAuditCsv(
                        data.records,
                        'treasury_${_category.toLowerCase()}',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text('Export $_category CSV'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditSavingsTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditSavingsTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditSavingsTab> createState() => _AuditSavingsTabState();
}

class _AuditSavingsTabState extends ConsumerState<AuditSavingsTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _subLedger = 'ALL';
  String _branch = '';
  String _officer = 'All Officers';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _subLedger,
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      officerId: widget.ctx.resolveOfficerId(_officer),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(savingsLedgerProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Savings Audit Ledgers',
          subtitle: 'Unified audit trail of individual savings, solidarity group collateral, miscellaneous reserves, and legacy LAPS balances.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 195,
                child: buildAuditDropdown(
                  context,
                  label: 'Savings Sub-Ledger',
                  value: _subLedger,
                  items: const [
                    'ALL',
                    'Individual Savings',
                    'Group Savings',
                    'Misc Savings',
                    'Laps Savings',
                  ],
                  onChanged: (v) => setState(() => _subLedger = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Officer',
                  value: _officer,
                  items: widget.ctx.officerOptions,
                  enabled: !widget.ctx.isOfficer,
                  onChanged: (v) => setState(() => _officer = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Client code or name...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(savingsLedgerProvider(query)),
          ),
          data: (data) {
            final m = data.metrics;
            const cols = [
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
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Total Deposits',
                    formatAuditNaira(m.totalDeposits),
                    highlightEmerald: true,
                  ),
                  AuditKpiItem(
                    'Withdrawals',
                    formatAuditNaira(m.totalWithdrawals),
                    topBorderColor: tokens.warningDot,
                  ),
                  AuditKpiItem(
                    'Net Movement',
                    formatAuditNaira(m.netSavingsMovement),
                    topBorderColor: tokens.brandPrimary,
                  ),
                  AuditKpiItem('Transactions', '${m.transactionsCount}'),
                  AuditKpiItem('Active Accounts', '${m.activeAccountsCount}'),
                ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: data.records,
                  columns: cols,
                  forceCardView: _forceCards,
                  emptyMessage:
                      'No savings movements match the selected criteria.',
                ),
                if (data.records.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => exportAuditCsv(
                        data.records,
                        'savings_${_subLedger.toLowerCase().replaceAll(' ', '_')}',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text('Export $_subLedger CSV'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditWithdrawalsTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditWithdrawalsTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditWithdrawalsTab> createState() =>
      _AuditWithdrawalsTabState();
}

class _AuditWithdrawalsTabState extends ConsumerState<AuditWithdrawalsTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _status = 'ALL';
  String _branch = '';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _status,
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(withdrawalAuditProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Withdrawal Requests & Authorization Lifecycle Audit',
          subtitle: 'End-to-end supervisory review of withdrawal requests, maker-checker approvals, rejections, and payout channels.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 175,
                child: buildAuditDropdown(
                  context,
                  label: 'Approval Status',
                  value: _status,
                  items: const ['ALL', 'PENDING', 'APPROVED', 'REJECTED'],
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Client, requester, ref...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 6, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(withdrawalAuditProvider(query)),
          ),
          data: (data) {
            final s = data.summary;
            final reqRows = data.requests.map((r) {
              return <String, dynamic>{
                'Date': r['operational_date'] ?? r['Date'] ?? '-',
                'Client / Group': r['client_name'] ?? r['Client'] ?? '-',
                'Bucket': r['savings_type'] ?? r['Savings Type'] ?? '-',
                'Operation': r['operation_type'] ?? r['Operation'] ?? '-',
                'Amount': (r['amount'] as num?)?.toDouble() ?? 0.0,
                'Payout': r['payout_method'] ?? r['Payout Method'] ?? '-',
                'Requested By':
                    r['requested_by'] ?? r['Requested By'] ?? '-',
                'Approved By': r['approved_by'] ?? r['Approved By'] ?? '-',
                'Branch': r['branch'] ?? '-',
                'Reference': r['reference'] ?? '-',
                'Status': r['status'] ?? 'PENDING',
              };
            }).toList();

            final evtRows = data.auditEvents.map((e) {
              return <String, dynamic>{
                'Timestamp': (e['created_at']?.toString() ?? '')
                    .replaceFirst('T', ' ')
                    .split('.')
                    .first,
                'Actor': e['username'] ?? '-',
                'Role': e['role'] ?? '-',
                'Action': e['action'] ?? '-',
                'Target': e['display_name'] ?? '-',
                'Branch': e['branch'] ?? '-',
                'Status': e['status'] ?? 'LOGGED',
              };
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Total Requests',
                    '${s.totalRequests}',
                    highlightEmerald: true,
                  ),
                  AuditKpiItem(
                    'Pending Approval',
                    '${s.pendingCount}',
                    delta: formatAuditNaira(s.pendingAmount),
                    topBorderColor: tokens.warningDot,
                  ),
                  AuditKpiItem(
                    'Approved Count',
                    '${s.approvedCount}',
                    topBorderColor: tokens.successDot,
                  ),
                  AuditKpiItem(
                    'Approved Volume',
                    formatAuditNaira(s.approvedAmount),
                    topBorderColor: tokens.brandPrimary,
                  ),
                  AuditKpiItem(
                    'Rejected',
                    '${s.rejectedCount}',
                    topBorderColor: tokens.dangerDot,
                    isInverseDelta: s.rejectedCount > 0,
                  ),
                ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: reqRows,
                  columns: const [
                    'Date',
                    'Client / Group',
                    'Bucket',
                    'Operation',
                    'Amount',
                    'Payout',
                    'Requested By',
                    'Approved By',
                    'Branch',
                    'Reference',
                    'Status',
                  ],
                  forceCardView: _forceCards,
                  emptyMessage:
                      'No withdrawal requests recorded for these filters.',
                ),
                if (evtRows.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const IcareSectionHeader(
                    title: 'Authorization Action Trail',
                    subtitle: 'Chronological audit events logged during withdrawal approval lifecycle.',
                  ),
                  const SizedBox(height: 10),
                  buildAuditDataDisplay(
                    context,
                    records: evtRows,
                    columns: const [
                      'Timestamp',
                      'Actor',
                      'Role',
                      'Action',
                      'Target',
                      'Branch',
                      'Status',
                    ],
                    forceCardView: _forceCards,
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditLoansTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditLoansTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditLoansTab> createState() => _AuditLoansTabState();
}

class _AuditLoansTabState extends ConsumerState<AuditLoansTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String _viewType = 'Loan Disbursements';
  String _productName = 'All Products';
  String _branch = '';
  String _officer = 'All Officers';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final productOptions = [
      'All Products',
      ...widget.ctx.products.map((p) => p.name),
    ];

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _viewType,
      productId: widget.ctx.resolveProductId(_productName),
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      officerId: widget.ctx.resolveOfficerId(_officer),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(loanLedgerProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Loan Portfolio Audit Ledgers',
          subtitle: 'Inspect disbursed principal facilities and scheduled loan repayments across branches.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 190,
                child: buildAuditDropdown(
                  context,
                  label: 'Audit View',
                  value: _viewType,
                  items: const ['Loan Disbursements', 'Repayments'],
                  onChanged: (v) => setState(() => _viewType = v),
                ),
              ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Loan Product',
                  value: _productName,
                  items: productOptions,
                  onChanged: (v) => setState(() => _productName = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Officer',
                  value: _officer,
                  items: widget.ctx.officerOptions,
                  enabled: !widget.ctx.isOfficer,
                  onChanged: (v) => setState(() => _officer = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Loan #, client, code...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(loanLedgerProvider(query)),
          ),
          data: (data) {
            final isDisb = _viewType == 'Loan Disbursements';
            final cols = isDisb
                ? const [
                    'Disbursement Date',
                    'Loan Number',
                    'Client Code',
                    'Client Name',
                    'Product',
                    'Officer',
                    'Branch',
                    'Principal',
                    'Status',
                  ]
                : const [
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
                  ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDisb && data.disbursementMetrics != null)
                  buildAuditKpiGrid([
                    AuditKpiItem(
                      'Principal Disbursed',
                      formatAuditNaira(
                          data.disbursementMetrics!.totalPrincipalDisbursed),
                      highlightEmerald: true,
                    ),
                    AuditKpiItem(
                      'Loans Disbursed',
                      '${data.disbursementMetrics!.loansDisbursed}',
                    ),
                    AuditKpiItem(
                      'Average Facility',
                      formatAuditNaira(
                          data.disbursementMetrics!.averagePrincipal),
                    ),
                    AuditKpiItem(
                      'Borrowers Count',
                      '${data.disbursementMetrics!.borrowersCount}',
                    ),
                    AuditKpiItem(
                      'Active Portfolio',
                      formatAuditNaira(
                          data.disbursementMetrics!.activePortfolio),
                    ),
                  ])
                else if (data.repaymentMetrics != null)
                  buildAuditKpiGrid([
                    AuditKpiItem(
                      'Repayments Collected',
                      formatAuditNaira(
                          data.repaymentMetrics!.totalRepaymentsCollected),
                      highlightEmerald: true,
                    ),
                    AuditKpiItem(
                      'Repayment Count',
                      '${data.repaymentMetrics!.repaymentCount}',
                    ),
                    AuditKpiItem(
                      'Average Payment',
                      formatAuditNaira(
                          data.repaymentMetrics!.averageRepayment),
                    ),
                    AuditKpiItem(
                      'Paying Clients',
                      '${data.repaymentMetrics!.activePayingClients}',
                    ),
                  ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: data.records,
                  columns: cols,
                  forceCardView: _forceCards,
                  emptyMessage: 'No loan records match the selected criteria.',
                ),
                if (data.records.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => exportAuditCsv(
                        data.records,
                        isDisb ? 'loan_disbursements' : 'loan_repayments',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: Text('Export $_viewType CSV'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class AuditCollectionsTab extends ConsumerStatefulWidget {
  final AuditLedgerTabContext ctx;
  const AuditCollectionsTab({super.key, required this.ctx});

  @override
  ConsumerState<AuditCollectionsTab> createState() =>
      _AuditCollectionsTabState();
}

class _AuditCollectionsTabState extends ConsumerState<AuditCollectionsTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String _compliance = 'ALL';
  String _branch = '';
  String _officer = 'All Officers';
  final _searchCtrl = TextEditingController();
  bool _forceCards = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    if (widget.ctx.branchOptions.isNotEmpty &&
        !widget.ctx.branchOptions.contains(_branch)) {
      _branch = widget.ctx.branchOptions.first;
    }

    final query = AuditLedgerFilterQuery(
      dateFrom: formatAuditDate(_from),
      dateTo: formatAuditDate(_to),
      filterType: _compliance,
      branchId: widget.ctx.resolveBranchId(_branch) ??
          (widget.ctx.canSwitchBranch ? null : widget.ctx.defaultBranchId),
      officerId: widget.ctx.resolveOfficerId(_officer),
      search: _searchCtrl.text.trim(),
    );
    final asyncData = ref.watch(collectionPerformanceProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IcareSectionHeader(
          title: 'Collection Performance Audit',
          subtitle: 'Schedule compliance audit comparing expected collections against actual verified inflows.',
        ),
        const SizedBox(height: 12),
        buildAuditFilterCard(
          context,
          onDateQuickSelect: (f, t) => setState(() {
            _from = f;
            _to = t;
          }),
          showCardView: _forceCards,
          onToggleView: (v) => setState(() => _forceCards = v),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date From',
                  value: _from,
                  onChanged: (d) => setState(() => _from = d),
                ),
              ),
              SizedBox(
                width: 150,
                child: buildAuditDatePicker(
                  context,
                  label: 'Date To',
                  value: _to,
                  onChanged: (d) => setState(() => _to = d),
                ),
              ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Compliance Status',
                  value: _compliance,
                  items: const ['ALL', 'PAID', 'PART_PAYMENT', 'NOT_PAID'],
                  onChanged: (v) => setState(() => _compliance = v),
                ),
              ),
              if (widget.ctx.branchOptions.isNotEmpty)
                SizedBox(
                  width: 185,
                  child: buildAuditDropdown(
                    context,
                    label: 'Branch',
                    value: _branch,
                    items: widget.ctx.branchOptions,
                    enabled: widget.ctx.canSwitchBranch,
                    onChanged: (v) => setState(() => _branch = v),
                  ),
                ),
              SizedBox(
                width: 185,
                child: buildAuditDropdown(
                  context,
                  label: 'Officer',
                  value: _officer,
                  items: widget.ctx.officerOptions,
                  enabled: !widget.ctx.isOfficer,
                  onChanged: (v) => setState(() => _officer = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: buildAuditSearchField(
                  context,
                  hint: 'Client, group, code...',
                  controller: _searchCtrl,
                  onChangedOrSubmitted: () => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        asyncData.when(
          loading: () =>
              const IcareTableSkeleton(rowCount: 7, hasFilterBar: false),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(collectionPerformanceProvider(query)),
          ),
          data: (data) {
            final m = data.metrics;
            const cols = [
              'Meeting Date',
              'Client Code',
              'Client Name',
              'Group',
              'Expected',
              'Paid',
              'Compliance %',
              'Officer',
              'Branch',
              'Status',
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildAuditKpiGrid([
                  AuditKpiItem(
                    'Expected Collections',
                    formatAuditNaira(m.expectedCollections),
                  ),
                  AuditKpiItem(
                    'Actual Collections',
                    formatAuditNaira(m.actualCollections),
                    highlightEmerald: true,
                  ),
                  AuditKpiItem(
                    'Variance',
                    formatAuditNaira(m.collectionVariance),
                    topBorderColor: m.collectionVariance > 0
                        ? tokens.dangerDot
                        : tokens.successDot,
                    isInverseDelta: m.collectionVariance > 0,
                  ),
                  AuditKpiItem(
                    'Compliance Rate',
                    '${m.meetingComplianceRatio.toStringAsFixed(1)}%',
                    topBorderColor: tokens.brandPrimary,
                  ),
                  AuditKpiItem(
                    'Meetings Audited',
                    '${m.meetingsAudited}',
                    delta: '${m.paidCount} paid full',
                  ),
                ]),
                const SizedBox(height: 14),
                buildAuditDataDisplay(
                  context,
                  records: data.records,
                  columns: cols,
                  forceCardView: _forceCards,
                  emptyMessage:
                      'No collection performance rows match the selected filters.',
                ),
                if (data.records.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => exportAuditCsv(
                        data.records,
                        'collection_performance',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 16),
                      label: const Text('Export Collection Performance CSV'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
