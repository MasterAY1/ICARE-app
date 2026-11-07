import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/reports_api_service.dart';
import '../../data/models/report_models.dart';

/// Reusable Bank & Treasury Reconciliation Form Widget
/// Provides an audited 5-section corporate banking reconciliation suite.
/// Used by both Reports & Export and the Global Administrator B/F Portal.
class BankReconciliationFormWidget extends ConsumerStatefulWidget {
  final MonthlyReconciliationData initialData;
  final String? branchName;
  final int year;
  final int month;
  final VoidCallback onSaved;
  final bool isReadOnly;

  const BankReconciliationFormWidget({
    super.key,
    required this.initialData,
    required this.branchName,
    required this.year,
    required this.month,
    required this.onSaved,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<BankReconciliationFormWidget> createState() => _BankReconciliationFormWidgetState();
}

class _BankReconciliationFormWidgetState extends ConsumerState<BankReconciliationFormWidget> {
  static final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  String _formatNgn(double value) => '₦${_currencyFormat.format(value)}';

  bool _isSaving = false;
  final Map<int, bool> _sectionExpanded = {
    1: false,
    2: false,
    3: false,
    4: false,
    5: false,
  };

  // Bank 1
  late TextEditingController _b1NameController;
  late TextEditingController _b1AccController;
  late TextEditingController _b1OpenController;
  late TextEditingController _b1ChgController;
  late TextEditingController _b1IntController;
  late TextEditingController _b1CloseController;

  // Bank 2
  late TextEditingController _b2NameController;
  late TextEditingController _b2AccController;
  late TextEditingController _b2OpenController;
  late TextEditingController _b2ChgController;
  late TextEditingController _b2IntController;
  late TextEditingController _b2CloseController;

  // Additional Treasury & Overdue
  late TextEditingController _cashBfController;
  late TextEditingController _overdueBfController;
  late TextEditingController _overdueCfController;
  late TextEditingController _profitController;
  late TextEditingController _ccController;
  late TextEditingController _lapseRetController;
  late TextEditingController _recOtherController;
  late TextEditingController _paidOtherController;
  late TextEditingController _retainedEarningsController;
  late TextEditingController _hoAssetAllocController;

  // Operational Table Overrides
  late TextEditingController _disbursedPrincipalController;
  late TextEditingController _upfrontFeesController;
  late TextEditingController _savingsDepositsController;
  late TextEditingController _collectionsController;

  // Remittances
  late TextEditingController _fRecHoAssetController;
  late TextEditingController _fRecHoMainController;
  late TextEditingController _fRecAreaController;
  late TextEditingController _fRecBrController;

  late TextEditingController _fPayHoAssetController;
  late TextEditingController _fPayHoMainController;
  late TextEditingController _fPayBrController;

  // Cumulative Trial Balance Expenses (Year-To-Date & Annex-1 Vouchers)
  late TextEditingController _tbSalaryController;
  late TextEditingController _tbRentController;
  late TextEditingController _tbElectricityController;
  late TextEditingController _tbStationeryController;
  late TextEditingController _tbEntertainmentController;
  late TextEditingController _tbTelephoneController;
  late TextEditingController _tbRepairOfficeController;
  late TextEditingController _tbTransportController;
  late TextEditingController _tbTrainingController;
  late TextEditingController _tbOtherExpensesController;

  // Cumulative Trial Balance Income & Reserves (Year-To-Date & Annex-1 Inflows)
  late TextEditingController _tbSalesProfitController;
  late TextEditingController _tbDamagesFineController;
  late TextEditingController _tbPassbookController;
  late TextEditingController _tbScrapsSalesController;
  late TextEditingController _tbApplicationFeeController;
  late TextEditingController _tbFundHoMainController;
  late TextEditingController _tbFundBranchController;
  late TextEditingController _tbFundOtherAreaController;
  late TextEditingController _tbFundInternalController;
  late TextEditingController _tbContingencyController;
  late TextEditingController _lapseDepositReserveController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final banks = widget.initialData.banks;
    final b1 = banks.isNotEmpty ? banks[0] : null;
    final b2 = banks.length > 1 ? banks[1] : null;

    _b1NameController = TextEditingController(text: b1?.bankName ?? '');
    _b1AccController = TextEditingController(text: b1?.accountNumber ?? '');
    _b1OpenController = TextEditingController(text: b1 != null && b1.openingBalance > 0 ? b1.openingBalance.toStringAsFixed(2) : '');
    _b1ChgController = TextEditingController(text: b1 != null && b1.bankCharges > 0 ? b1.bankCharges.toStringAsFixed(2) : '');
    _b1IntController = TextEditingController(text: b1 != null && b1.bankInterest > 0 ? b1.bankInterest.toStringAsFixed(2) : '');
    _b1CloseController = TextEditingController(text: b1 != null && b1.closingBalance > 0 ? b1.closingBalance.toStringAsFixed(2) : '');

    _b2NameController = TextEditingController(text: b2?.bankName ?? '');
    _b2AccController = TextEditingController(text: b2?.accountNumber ?? '');
    _b2OpenController = TextEditingController(text: b2 != null && b2.openingBalance > 0 ? b2.openingBalance.toStringAsFixed(2) : '');
    _b2ChgController = TextEditingController(text: b2 != null && b2.bankCharges > 0 ? b2.bankCharges.toStringAsFixed(2) : '');
    _b2IntController = TextEditingController(text: b2 != null && b2.bankInterest > 0 ? b2.bankInterest.toStringAsFixed(2) : '');
    _b2CloseController = TextEditingController(text: b2 != null && b2.closingBalance > 0 ? b2.closingBalance.toStringAsFixed(2) : '');

    final d = widget.initialData;
    _cashBfController = TextEditingController(text: d.cashInHandBf > 0 ? d.cashInHandBf.toStringAsFixed(2) : '');
    _overdueBfController = TextEditingController(text: d.overdueBf > 0 ? d.overdueBf.toStringAsFixed(2) : '');
    _overdueCfController = TextEditingController(text: d.overdueCf > 0 ? d.overdueCf.toStringAsFixed(2) : '');
    _profitController = TextEditingController(text: d.salesProfitMarkup > 0 ? d.salesProfitMarkup.toStringAsFixed(2) : '');
    _ccController = TextEditingController(text: d.salesCashAndCarry > 0 ? d.salesCashAndCarry.toStringAsFixed(2) : '');
    _lapseRetController = TextEditingController(text: d.lapseDepositReturn > 0 ? d.lapseDepositReturn.toStringAsFixed(2) : '');
    _recOtherController = TextEditingController(text: d.receivedFromOtherSources > 0 ? d.receivedFromOtherSources.toStringAsFixed(2) : '');
    _paidOtherController = TextEditingController(text: d.paidToOtherSources > 0 ? d.paidToOtherSources.toStringAsFixed(2) : '');
    _retainedEarningsController = TextEditingController(text: d.retainedEarnings > 0 ? d.retainedEarnings.toStringAsFixed(2) : '');
    _hoAssetAllocController = TextEditingController(text: d.headOfficeAssetAllocation > 0 ? d.headOfficeAssetAllocation.toStringAsFixed(2) : '');

    _disbursedPrincipalController = TextEditingController(text: d.disbursedPrincipal > 0 ? d.disbursedPrincipal.toStringAsFixed(2) : '');
    _upfrontFeesController = TextEditingController(text: d.upfrontFees > 0 ? d.upfrontFees.toStringAsFixed(2) : '');
    _savingsDepositsController = TextEditingController(text: d.savingsDeposits > 0 ? d.savingsDeposits.toStringAsFixed(2) : '');
    _collectionsController = TextEditingController(text: d.collections > 0 ? d.collections.toStringAsFixed(2) : '');

    _fRecHoAssetController = TextEditingController(text: d.fundCashHoAssetReceipt > 0 ? d.fundCashHoAssetReceipt.toStringAsFixed(2) : '');
    _fRecHoMainController = TextEditingController(text: d.fundCashHoMainReceipt > 0 ? d.fundCashHoMainReceipt.toStringAsFixed(2) : '');
    _fRecAreaController = TextEditingController(text: d.fundCashOtherAreaReceipt > 0 ? d.fundCashOtherAreaReceipt.toStringAsFixed(2) : '');
    _fRecBrController = TextEditingController(text: d.fundCashBranchReceipt > 0 ? d.fundCashBranchReceipt.toStringAsFixed(2) : '');

    _fPayHoAssetController = TextEditingController(text: d.fundCashHoAssetPayment > 0 ? d.fundCashHoAssetPayment.toStringAsFixed(2) : '');
    _fPayHoMainController = TextEditingController(text: d.fundCashHoMainPayment > 0 ? d.fundCashHoMainPayment.toStringAsFixed(2) : '');
    _fPayBrController = TextEditingController(text: d.fundCashBranchPayment > 0 ? d.fundCashBranchPayment.toStringAsFixed(2) : '');

    _tbSalaryController = TextEditingController(text: d.tbSalary > 0 ? d.tbSalary.toStringAsFixed(2) : '');
    _tbRentController = TextEditingController(text: d.tbRent > 0 ? d.tbRent.toStringAsFixed(2) : '');
    _tbElectricityController = TextEditingController(text: d.tbElectricity > 0 ? d.tbElectricity.toStringAsFixed(2) : '');
    _tbStationeryController = TextEditingController(text: d.tbStationery > 0 ? d.tbStationery.toStringAsFixed(2) : '');
    _tbEntertainmentController = TextEditingController(text: d.tbEntertainment > 0 ? d.tbEntertainment.toStringAsFixed(2) : '');
    _tbTelephoneController = TextEditingController(text: d.tbTelephone > 0 ? d.tbTelephone.toStringAsFixed(2) : '');
    _tbRepairOfficeController = TextEditingController(text: d.tbRepairOffice > 0 ? d.tbRepairOffice.toStringAsFixed(2) : '');
    _tbTransportController = TextEditingController(text: d.tbTransport > 0 ? d.tbTransport.toStringAsFixed(2) : '');
    _tbTrainingController = TextEditingController(text: d.tbTraining > 0 ? d.tbTraining.toStringAsFixed(2) : '');
    _tbOtherExpensesController = TextEditingController(text: d.tbOtherExpenses > 0 ? d.tbOtherExpenses.toStringAsFixed(2) : '');

    _tbSalesProfitController = TextEditingController(text: d.tbSalesProfit > 0 ? d.tbSalesProfit.toStringAsFixed(2) : '');
    _tbDamagesFineController = TextEditingController(text: d.tbDamagesFine > 0 ? d.tbDamagesFine.toStringAsFixed(2) : '');
    _tbPassbookController = TextEditingController(text: d.tbPassbook > 0 ? d.tbPassbook.toStringAsFixed(2) : '');
    _tbScrapsSalesController = TextEditingController(text: d.tbScrapsSales > 0 ? d.tbScrapsSales.toStringAsFixed(2) : '');
    _tbApplicationFeeController = TextEditingController(text: d.tbApplicationFee > 0 ? d.tbApplicationFee.toStringAsFixed(2) : '');
    _tbFundHoMainController = TextEditingController(text: d.tbFundHoMain > 0 ? d.tbFundHoMain.toStringAsFixed(2) : '');
    _tbFundBranchController = TextEditingController(text: d.tbFundBranch > 0 ? d.tbFundBranch.toStringAsFixed(2) : '');
    _tbFundOtherAreaController = TextEditingController(text: d.tbFundOtherArea > 0 ? d.tbFundOtherArea.toStringAsFixed(2) : '');
    _tbFundInternalController = TextEditingController(text: d.tbFundInternal > 0 ? d.tbFundInternal.toStringAsFixed(2) : '');
    _tbContingencyController = TextEditingController(text: d.tbContingency > 0 ? d.tbContingency.toStringAsFixed(2) : '');
    _lapseDepositReserveController = TextEditingController(text: d.lapseDepositReserve > 0 ? d.lapseDepositReserve.toStringAsFixed(2) : '');
  }

  @override
  void didUpdateWidget(BankReconciliationFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialData != widget.initialData ||
        oldWidget.branchName != widget.branchName ||
        oldWidget.year != widget.year ||
        oldWidget.month != widget.month) {
      _disposeControllers();
      _initControllers();
    }
  }

  void _disposeControllers() {
    _b1NameController.dispose();
    _b1AccController.dispose();
    _b1OpenController.dispose();
    _b1ChgController.dispose();
    _b1IntController.dispose();
    _b1CloseController.dispose();

    _b2NameController.dispose();
    _b2AccController.dispose();
    _b2OpenController.dispose();
    _b2ChgController.dispose();
    _b2IntController.dispose();
    _b2CloseController.dispose();

    _cashBfController.dispose();
    _overdueBfController.dispose();
    _overdueCfController.dispose();
    _profitController.dispose();
    _ccController.dispose();
    _lapseRetController.dispose();
    _recOtherController.dispose();
    _paidOtherController.dispose();
    _retainedEarningsController.dispose();
    _hoAssetAllocController.dispose();

    _disbursedPrincipalController.dispose();
    _upfrontFeesController.dispose();
    _savingsDepositsController.dispose();
    _collectionsController.dispose();

    _fRecHoAssetController.dispose();
    _fRecHoMainController.dispose();
    _fRecAreaController.dispose();
    _fRecBrController.dispose();

    _fPayHoAssetController.dispose();
    _fPayHoMainController.dispose();
    _fPayBrController.dispose();

    _tbSalaryController.dispose();
    _tbRentController.dispose();
    _tbElectricityController.dispose();
    _tbStationeryController.dispose();
    _tbEntertainmentController.dispose();
    _tbTelephoneController.dispose();
    _tbRepairOfficeController.dispose();
    _tbTransportController.dispose();
    _tbTrainingController.dispose();
    _tbOtherExpensesController.dispose();

    _tbSalesProfitController.dispose();
    _tbDamagesFineController.dispose();
    _tbPassbookController.dispose();
    _tbScrapsSalesController.dispose();
    _tbApplicationFeeController.dispose();
    _tbFundHoMainController.dispose();
    _tbFundBranchController.dispose();
    _tbFundOtherAreaController.dispose();
    _tbFundInternalController.dispose();
    _tbContingencyController.dispose();
    _lapseDepositReserveController.dispose();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  double _parseVal(TextEditingController c) {
    final text = c.text.replaceAll(',', '').trim();
    return double.tryParse(text) ?? 0.0;
  }

  Future<void> _handleSave() async {
    if (widget.isReadOnly) return;
    setState(() => _isSaving = true);
    try {
      final updatedData = MonthlyReconciliationData(
        banks: [
          BankStatementItem(
            bankName: _b1NameController.text.trim(),
            accountNumber: _b1AccController.text.trim(),
            openingBalance: _parseVal(_b1OpenController),
            bankCharges: _parseVal(_b1ChgController),
            bankInterest: _parseVal(_b1IntController),
            closingBalance: _parseVal(_b1CloseController),
          ),
          BankStatementItem(
            bankName: _b2NameController.text.trim(),
            accountNumber: _b2AccController.text.trim(),
            openingBalance: _parseVal(_b2OpenController),
            bankCharges: _parseVal(_b2ChgController),
            bankInterest: _parseVal(_b2IntController),
            closingBalance: _parseVal(_b2CloseController),
          ),
        ],
        cashInHandBf: _parseVal(_cashBfController),
        overdueBf: _parseVal(_overdueBfController),
        overdueCf: _parseVal(_overdueCfController),
        salesProfitMarkup: _parseVal(_profitController),
        salesCashAndCarry: _parseVal(_ccController),
        fundCashHoAssetReceipt: _parseVal(_fRecHoAssetController),
        fundCashHoMainReceipt: _parseVal(_fRecHoMainController),
        fundCashOtherAreaReceipt: _parseVal(_fRecAreaController),
        fundCashBranchReceipt: _parseVal(_fRecBrController),
        fundCashHoAssetPayment: _parseVal(_fPayHoAssetController),
        fundCashHoMainPayment: _parseVal(_fPayHoMainController),
        fundCashBranchPayment: _parseVal(_fPayBrController),
        depositWithdrawal: 0.0,
        lapseDepositReturn: _parseVal(_lapseRetController),
        paidToOtherSources: _parseVal(_paidOtherController),
        receivedFromOtherSources: _parseVal(_recOtherController),
        retainedEarnings: _parseVal(_retainedEarningsController),
        headOfficeAssetAllocation: _parseVal(_hoAssetAllocController),
        disbursedPrincipal: _parseVal(_disbursedPrincipalController),
        upfrontFees: _parseVal(_upfrontFeesController),
        savingsDeposits: _parseVal(_savingsDepositsController),
        collections: _parseVal(_collectionsController),
        tbSalary: _parseVal(_tbSalaryController),
        tbRent: _parseVal(_tbRentController),
        tbElectricity: _parseVal(_tbElectricityController),
        tbStationery: _parseVal(_tbStationeryController),
        tbEntertainment: _parseVal(_tbEntertainmentController),
        tbTelephone: _parseVal(_tbTelephoneController),
        tbRepairOffice: _parseVal(_tbRepairOfficeController),
        tbTransport: _parseVal(_tbTransportController),
        tbTraining: _parseVal(_tbTrainingController),
        tbOtherExpenses: _parseVal(_tbOtherExpensesController),
        tbSalesProfit: _parseVal(_tbSalesProfitController),
        tbDamagesFine: _parseVal(_tbDamagesFineController),
        tbPassbook: _parseVal(_tbPassbookController),
        tbScrapsSales: _parseVal(_tbScrapsSalesController),
        tbApplicationFee: _parseVal(_tbApplicationFeeController),
        tbFundHoMain: _parseVal(_tbFundHoMainController),
        tbFundBranch: _parseVal(_tbFundBranchController),
        tbFundOtherArea: _parseVal(_tbFundOtherAreaController),
        tbFundInternal: _parseVal(_tbFundInternalController),
        tbContingency: _parseVal(_tbContingencyController),
        lapseDepositReserve: _parseVal(_lapseDepositReserveController),
      );

      final api = ref.read(reportsApiServiceProvider);
      final effectiveBranch = (widget.branchName != null && !widget.branchName!.startsWith('All'))
          ? widget.branchName
          : null;

      await api.saveMonthlyReconciliation(
        branchName: effectiveBranch,
        year: widget.year,
        month: widget.month,
        data: updatedData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Monthly reconciliation saved successfully. Statements recalculated.'),
            backgroundColor: Color(0xFF166534),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to save reconciliation: $e';
        if (e is DioException && e.response?.data != null) {
          final d = e.response!.data;
          if (d is Map && d['detail'] != null) {
            errorMsg = 'Failed to save reconciliation: ${d["detail"]}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool isNumber = true,
    bool readOnly = false,
    String? badgeText,
  }) {
    final effectiveReadOnly = widget.isReadOnly || readOnly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
            if (badgeText != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: effectiveReadOnly ? const Color(0xFFF1F5F9) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: effectiveReadOnly ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: effectiveReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F766E),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: effectiveReadOnly,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(
            fontSize: 12,
            color: effectiveReadOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            fontWeight: effectiveReadOnly ? FontWeight.w600 : FontWeight.normal,
            fontFeatures: isNumber ? const [FontFeature.tabularFigures()] : null,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: effectiveReadOnly ? const Color(0xFFF1F5F9) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required int sectionIndex,
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    final isExpanded = _sectionExpanded[sectionIndex] ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _sectionExpanded[sectionIndex] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankCard(
    String title,
    TextEditingController nameC,
    TextEditingController accC,
    TextEditingController openC,
    TextEditingController chgC,
    TextEditingController intC,
    TextEditingController closeC,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildField('Bank Name', nameC, isNumber: false, badgeText: 'Commercial')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Account Number', accC, isNumber: false, badgeText: 'Account')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Opening Balance B/F (₦)', openC, readOnly: true, badgeText: 'Prior Month Rollover')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Closing Balance C/F (₦)', closeC, badgeText: 'Bank Statement')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildField('Bank Charges (₦)', chgC, badgeText: 'Monthly')),
              const SizedBox(width: 8),
              Expanded(child: _buildField('Bank Interest Earned (₦)', intC, badgeText: 'Monthly')),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic calculations for Annex-1 live feedback
    final annex1ExpenseSum = _parseVal(_tbSalaryController) +
        _parseVal(_tbElectricityController) +
        _parseVal(_tbStationeryController) +
        _parseVal(_tbEntertainmentController) +
        _parseVal(_tbTelephoneController) +
        _parseVal(_tbTransportController) +
        _parseVal(_tbTrainingController) +
        _parseVal(_tbRentController) +
        _parseVal(_tbRepairOfficeController) +
        _parseVal(_tbOtherExpensesController);

    final annex1InflowSum = _parseVal(_tbPassbookController) +
        _parseVal(_tbApplicationFeeController) +
        _parseVal(_tbScrapsSalesController) +
        _parseVal(_tbDamagesFineController);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 750;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Commercial Bank Accounts (Statements)
            _buildSectionCard(
              sectionIndex: 1,
              title: '1. Commercial Bank Accounts (Statements)',
              icon: Icons.account_balance,
              child: isNarrow
                  ? Column(
                      children: [
                        _buildBankCard('Bank Account 1', _b1NameController, _b1AccController, _b1OpenController, _b1ChgController, _b1IntController, _b1CloseController),
                        const SizedBox(height: 12),
                        _buildBankCard('Bank Account 2 (Optional)', _b2NameController, _b2AccController, _b2OpenController, _b2ChgController, _b2IntController, _b2CloseController),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildBankCard('Bank Account 1', _b1NameController, _b1AccController, _b1OpenController, _b1ChgController, _b1IntController, _b1CloseController),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildBankCard('Bank Account 2 (Optional)', _b2NameController, _b2AccController, _b2OpenController, _b2ChgController, _b2IntController, _b2CloseController),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Section 2: Monthly Operating Expenses (Annex-1 Vouchers)
            _buildSectionCard(
              sectionIndex: 2,
              title: '2. Monthly Operating Expenses (Annex-1 Vouchers)',
              icon: Icons.receipt_long,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, s2Constraints) {
                      final isMobile = s2Constraints.maxWidth < 600;
                      final isTablet = s2Constraints.maxWidth >= 600 && s2Constraints.maxWidth < 950;
                      final fieldW = isMobile
                          ? (s2Constraints.maxWidth - 8) / 2
                          : isTablet
                              ? (s2Constraints.maxWidth - 16) / 3
                              : (s2Constraints.maxWidth - 24) / 4;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldW, child: _buildField('Personnel Gross Salary (₦)', _tbSalaryController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Electricity/Gas/Water (₦)', _tbElectricityController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Stationery & Office Mgmt (₦)', _tbStationeryController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Entertainment & Refreshment (₦)', _tbEntertainmentController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Telephone & Postage (₦)', _tbTelephoneController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Transport Allowance (₦)', _tbTransportController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Training Expenses (₦)', _tbTrainingController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Office Rent (₦)', _tbRentController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Repair Cost Office (₦)', _tbRepairOfficeController, badgeText: 'Voucher')),
                          SizedBox(width: fieldW, child: _buildField('Other Operating Expenses (₦)', _tbOtherExpensesController, badgeText: 'Voucher')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Annex-1 Monthly Expenses: ${_formatNgn(annex1ExpenseSum)} (Linked to Operational Outflows & Trial Balance)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Monthly Sundry Receipts (Annex-1 Inflows)
            _buildSectionCard(
              sectionIndex: 3,
              title: '3. Monthly Sundry Receipts (Annex-1 Inflows)',
              icon: Icons.payments,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, s3Constraints) {
                      final isMobile = s3Constraints.maxWidth < 600;
                      final fieldW = isMobile
                          ? (s3Constraints.maxWidth - 8) / 2
                          : (s3Constraints.maxWidth - 24) / 4;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldW, child: _buildField('Passbook Fees (₦)', _tbPassbookController, readOnly: true, badgeText: 'Cashbook')),
                          SizedBox(width: fieldW, child: _buildField('Application Fees (₦)', _tbApplicationFeeController, readOnly: true, badgeText: 'Cashbook')),
                          SizedBox(width: fieldW, child: _buildField('Scrap Sales & Bonuses (₦)', _tbScrapsSalesController, readOnly: true, badgeText: 'Cashbook')),
                          SizedBox(width: fieldW, child: _buildField('Damages & Penalties (₦)', _tbDamagesFineController, readOnly: true, badgeText: 'Cashbook')),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Annex-1 Sundry Receipts: ${_formatNgn(annex1InflowSum)} (Linked to Auxiliary Cash Inflows)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Cashbook Remittances & Operational Collections
            _buildSectionCard(
              sectionIndex: 4,
              title: '4. Operational Collections & Cashbook Remittances',
              subtitle: 'Delinquent portfolio closing balance and automated central remittances',
              icon: Icons.sync_alt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dedicated Card for Overdue Portfolio (Actionable Input)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_late_outlined, size: 16, color: Color(0xFFB45309)),
                            SizedBox(width: 8),
                            Text('Overdue Delinquency Portfolio Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildField('Opening Overdue Portfolio (B/F) (₦)', _overdueBfController, readOnly: true, badgeText: 'Rollover')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildField('Month-End Overdue Portfolio (C/F) (₦)', _overdueCfController, badgeText: 'Required Input')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Information banner for automated feeds
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, size: 16, color: Color(0xFF0F766E)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Automated Ledger Feeds: The metrics below are synchronized dynamically from daily loan disbursements, repayments, savings, and master cashbook transfers.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, s4Constraints) {
                      final isMobile = s4Constraints.maxWidth < 600;
                      final isTablet = s4Constraints.maxWidth >= 600 && s4Constraints.maxWidth < 950;
                      final fieldW = isMobile
                          ? (s4Constraints.maxWidth - 8) / 2
                          : isTablet
                              ? (s4Constraints.maxWidth - 16) / 3
                              : (s4Constraints.maxWidth - 24) / 4;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          SizedBox(width: fieldW, child: _buildField('Contract Finance Margin (₦)', _profitController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Direct Cash & Carry Sales (₦)', _ccController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Loan Origination Fees (₦)', _upfrontFeesController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Loan Repayments Received (₦)', _collectionsController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Loan Principal Disbursed (₦)', _disbursedPrincipalController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Member Savings Deposits (₦)', _savingsDepositsController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Lapse Deposit Returns (₦)', _lapseRetController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('HO Asset Remittance Inflow (₦)', _fRecHoAssetController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('HO Main Remittance Inflow (₦)', _fRecHoMainController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Branch Transfer Inflow (₦)', _fRecBrController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Regional Area Inflow (₦)', _fRecAreaController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('HO Asset Remittance Outflow (₦)', _fPayHoAssetController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('HO Main Remittance Outflow (₦)', _fPayHoMainController, readOnly: true, badgeText: 'Automated')),
                          SizedBox(width: fieldW, child: _buildField('Branch Transfer Outflow (₦)', _fPayBrController, readOnly: true, badgeText: 'Automated')),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Capital Funds & Equity Adjustments (YTD)
            _buildSectionCard(
              sectionIndex: 5,
              title: '5. Capital Funds & Equity Adjustments (YTD)',
              subtitle: 'Central head office allocations and statutory capital reserves',
              icon: Icons.pie_chart,
              child: LayoutBuilder(
                builder: (context, s5Constraints) {
                  final isMobile = s5Constraints.maxWidth < 600;
                  final isTablet = s5Constraints.maxWidth >= 600 && s5Constraints.maxWidth < 950;
                  final fieldW = isMobile
                      ? (s5Constraints.maxWidth - 8) / 2
                      : isTablet
                          ? (s5Constraints.maxWidth - 16) / 3
                          : (s5Constraints.maxWidth - 24) / 4;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      SizedBox(width: fieldW, child: _buildField('Head Office Main Fund (₦)', _tbFundHoMainController, badgeText: 'Central Fund')),
                      SizedBox(width: fieldW, child: _buildField('Branch Office Fund (₦)', _tbFundBranchController, badgeText: 'Central Fund')),
                      SizedBox(width: fieldW, child: _buildField('Regional Area Fund (₦)', _tbFundOtherAreaController, badgeText: 'Central Fund')),
                      SizedBox(width: fieldW, child: _buildField('Internal Capital Fund (₦)', _tbFundInternalController, badgeText: 'Branch Equity')),
                      SizedBox(width: fieldW, child: _buildField('Retained Earnings (₦)', _retainedEarningsController, readOnly: true, badgeText: 'Rollover')),
                      SizedBox(width: fieldW, child: _buildField('Head Office Asset Allocation (₦)', _hoAssetAllocController, readOnly: true, badgeText: 'Central Asset')),
                      SizedBox(width: fieldW, child: _buildField('Lapse Deposit Reserve (₦)', _lapseDepositReserveController, badgeText: 'Statutory Reserve')),
                      SizedBox(width: fieldW, child: _buildField('Sales Profit Cumulative YTD (₦)', _tbSalesProfitController, badgeText: 'YTD Ledger')),
                      SizedBox(width: fieldW, child: _buildField('Contingency Reserve (₦)', _tbContingencyController, badgeText: 'Statutory Reserve')),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button or Read-Only Banner
            if (widget.isReadOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Color(0xFF64748B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Read-Only Mode: Area Managers have inspection and export privileges. Statements and ledger reconciliations can only be modified by the Branch Manager or Head Office.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 20, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Saving & Recalculating...' : 'Save & Recalculate Statements',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}
