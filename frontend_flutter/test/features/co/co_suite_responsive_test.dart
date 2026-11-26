import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter/core/auth/auth_controller.dart';
import 'package:frontend_flutter/core/auth/auth_state.dart';
import 'package:frontend_flutter/core/auth/session_storage_base.dart';
import 'package:frontend_flutter/core/network/api_client.dart';
import 'package:frontend_flutter/core/offline/connectivity_service.dart';
import 'package:frontend_flutter/core/offline/offline_database_service.dart';
import 'package:frontend_flutter/core/theme/icare_theme.dart';
import 'package:frontend_flutter/core/theme/theme_controller.dart';
import 'package:frontend_flutter/core/widgets/icare_data_table.dart';
import 'package:frontend_flutter/core/widgets/icare_status_badge.dart';
import 'package:frontend_flutter/features/co/data/datasources/co_api_service.dart';
import 'package:frontend_flutter/features/co/data/models/co_dashboard_models.dart';
import 'package:frontend_flutter/features/co/presentation/co_dashboard_screen.dart';
import 'package:frontend_flutter/features/co/presentation/daily_cashbook_screen.dart';
import 'package:frontend_flutter/features/co/presentation/daily_collections_screen.dart';
import 'package:frontend_flutter/features/co/presentation/loan_origination_screen.dart';
import 'package:frontend_flutter/features/co/presentation/portfolio_overview_screen.dart';
import 'package:frontend_flutter/features/co/presentation/widgets/asset_catalog_picker_card.dart';
import 'package:frontend_flutter/features/co/presentation/widgets/co_shared_widgets.dart';
import 'package:frontend_flutter/features/co/presentation/withdrawal_operations_screen.dart';
import 'package:frontend_flutter/features/shared/presentation/co_app_scaffold.dart';

class _MemSessionStorage implements SessionStorage {
  Map<String, String>? _stored;
  @override
  Future<void> saveSession(String token, String userJson) async =>
      _stored = {'token': token, 'user': userJson};
  @override
  Future<Map<String, String>?> getSession() async => _stored;
  @override
  Future<void> clearSession() async => _stored = null;
}

class _NoopHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode('{}')),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QuietConn implements ConnectivityService {
  final _ctrl = StreamController<bool>.broadcast();
  @override
  Stream<bool> get statusStream => _ctrl.stream;
  @override
  bool get isOnline => true;
  @override
  void reportOffline() {}
  @override
  void reportOnline() {}
  @override
  Future<bool> checkActualConnection({bool forceImmediateOffline = false}) async =>
      true;
  @override
  void dispose() => _ctrl.close();
}

class _StaticAuthController extends AuthController {
  _StaticAuthController(
    AuthUser user,
    ApiClient apiClient,
    OfflineDatabaseService db,
  ) : super(apiClient, db, _MemSessionStorage(), false) {
    state = AuthStateAuthenticated(user: user, token: 'test-token');
  }
}

class _FakeCoApiService extends CoApiService {
  final bool failClientFees;

  _FakeCoApiService(
    super.client, {
    this.failClientFees = false,
  });

  @override
  Future<CoDashboardData> getCoDashboardData([String? dateStr]) async {
    return CoDashboardData.fromJson({
      'welcome': {
        'officer_name': 'Ada Obi',
        'branch': 'Ikeja Branch',
        'branch_name': 'Ikeja Branch',
        'date_str': '2026-11-25',
        'meeting_day': 'Wednesday',
        'time_str': '09:30 AM',
      },
      'branch_closure': {
        'is_open': true,
        'is_closed': false,
        'reason': '',
        'open_reason': 'Working Day',
      },
      'repayment_summary': {
        'expected_today': 120000.0,
        'collected_today': 95000.0,
        'total_collected_today': 95000.0,
        'rep_12_weeks_amt': 55000.0,
        'rep_12_weeks_clients': 6,
        'rep_24_weeks_amt': 25000.0,
        'rep_24_weeks_clients': 2,
        'rep_120_days_amt': 15000.0,
        'rep_120_days_clients': 1,
        'rep_daily_amt': 0.0,
        'rep_daily_clients': 0,
        'rep_monthly_amt': 0.0,
        'rep_monthly_clients': 0,
        'compliance_pct': 79.2,
        'paid_count': 9,
        'not_paid_count': 2,
      },
      'meeting_portfolio': [
        {
          'group_name': 'Unity Group',
          'Group Name': 'Unity Group',
          'Meeting Day': 'Monday',
          'Clients Expected': 6,
          'Expected (₦)': 65000.0,
          'Collected (₦)': 55000.0,
          'expected_amount': 65000.0,
          'collected_amount': 55000.0,
          'clients_count': 6,
          'Status': 'In Progress',
        },
        {
          'group_name': 'Favour Group',
          'Group Name': 'Favour Group',
          'Meeting Day': 'Wednesday',
          'Clients Expected': 5,
          'Expected (₦)': 55000.0,
          'Collected (₦)': 40000.0,
          'expected_amount': 55000.0,
          'collected_amount': 40000.0,
          'clients_count': 5,
          'Status': 'In Progress',
        },
      ],
      'savings': {
        'deposits_today': 18000.0,
        'withdrawals_today': 4000.0,
        'net_savings_today': 14000.0,
        'net_savings': 14000.0,
        'deposited_clients': 5,
        'withdrawn_clients': 1,
      },
      'repayment_status': {
        'full_payment': {'amount': 35000.0, 'count': 1},
        'normal_payment': {'amount': 48000.0, 'count': 6},
        'excess_payment': {'amount': 5000.0, 'count': 1},
        'part_payment': {'amount': 7000.0, 'count': 1},
        'not_paid': {'amount': 24000.0, 'count': 2},
        'overdue_arrears': {'amount': 24000.0, 'count': 2},
      },
      'cash_position': {
        'opening_vault': 30000.0,
        'opening_balance': 30000.0,
        'cash_in': 113000.0,
        'cash_out': 54000.0,
        'closing_vault': 89000.0,
        'closing_balance': 89000.0,
        'difference': 0.0,
        'status': 'Balanced',
      },
      'attention_list': [
        {
          'client_name': 'Seyi Ade',
          'Client Name': 'Seyi Ade',
          'client_code': 'CL-002',
          'group_name': 'Unity Group',
          'Group': 'Unity Group',
          'expected_amount': 12000.0,
          'paid_amount': 0.0,
          'shortfall': 12000.0,
          'status': 'NOT PAID',
        },
      ],
      'overdue_portfolio': {
        'overdue_count': 2,
        'total_overdue_amount': 24000.0,
        'overdue_groups_count': 1,
      },
    });
  }

  @override
  Future<List<dynamic>> getOriginationGroups() async => [
        {'id': 'g-1', 'name': 'Unity Group', 'meeting_day': 'Monday'},
        {'id': 'g-2', 'name': 'Favour Group', 'meeting_day': 'Wednesday'},
      ];

  @override
  Future<Map<String, dynamic>> getOriginationBusinessDate() async => {
        'business_date': '2026-11-25',
        'is_open': true,
        'open_reason': 'Working Day',
      };

  @override
  Future<Map<String, dynamic>> getPendingDisbursements() async => {
        'is_open': true,
        'open_reason': 'Working Day',
        'can_authorize': false,
        'pending_loans': [
          {
            'loan_id': 'ln-pending-1',
            'client_name': 'Amina Bello',
            'client_code': 'CL-001',
            'group_name': 'Unity Group',
            'loan_product': '12-Week Cash',
            'loan_amount': 100000.0,
            'active_credit': 112000.0,
            'date': '2026-11-25',
            'credit_officer': 'Ada Obi',
            'asset_summary': '—',
            'is_asset': false,
          },
          {
            'loan_id': 'ln-pending-2',
            'client_name': 'Bisi Ade',
            'client_code': 'CL-003',
            'group_name': 'Favour Group',
            'loan_product': '60-Day Asset',
            'loan_amount': 200000.0,
            'active_credit': 224000.0,
            'date': '2026-11-25',
            'credit_officer': 'Ada Obi',
            'asset_summary': 'Bruhm 100L Freezer (x1)',
            'is_asset': true,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getBranchAssetCatalog({
    String? branchId,
    String? category,
    String? search,
    bool inStockOnly = false,
  }) async =>
      {
        'branch_name': 'Ikeja Branch',
        'summary': {
          'total_catalog_skus': 2,
          'branch_stocked_skus': 2,
          'total_units_available': 9,
        },
        'categories': [
          {
            'category': 'FREEZER',
            'catalog_skus': 1,
            'in_stock_skus': 1,
            'units_available': 5,
          },
          {
            'category': 'GAS COOKER AND CYLINDER',
            'catalog_skus': 1,
            'in_stock_skus': 1,
            'units_available': 4,
          },
        ],
        'items': [
          {
            'item_id': 'ast-1',
            'sku_code': 'FRZ-001',
            'category': 'FREEZER',
            'item_name': 'Bruhm 100L Freezer',
            'cash_and_carry_price': 200000.0,
            'easy_buy_60d_price': 224000.0,
            'easy_buy_120d_price': 242000.0,
            'quantity_available': 5,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getCollectionSheet({
    String? groupName,
    String? date,
  }) async =>
      {
        'date': '2026-11-25',
        'is_open': true,
        'open_reason': 'Working Day',
        'groups': ['Unity Group'],
        'group_name': 'Unity Group',
        'clients': [
          {
            'client_id': 'c-1',
            'client_code': 'CL-001',
            'client_name': 'Amina Bello',
            'loan_id': 'ln-1',
            'expected_repayment': 10000.0,
            'remaining_balance': 50000.0,
            'product': '12-Week Cash',
            'repayment_paid': 0.0,
            'savings_deposited': 0.0,
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getSingleClientOptions() async => {
        'clients': [
          {
            'client_id': 'c-1',
            'client_code': 'CL-001',
            'client_name': 'Amina Bello',
            'group_id': 'g-1',
            'group_name': 'Unity Group',
            'eligible_loans': [
              {
                'loan_id': 'ln-1',
                'product': '12-Week Cash',
                'expected_repayment': 10000.0,
                'remaining_balance': 50000.0,
              },
            ],
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> getCollectionsHistory({
    String? date,
    String? search,
    String? officer,
  }) async =>
      {
        'total_repayments': 80000.0,
        'paid_repayments_count': 8,
        'not_paid_repayments_count': 1,
        'total_savings': 18000.0,
        'savings_deposits_count': 8,
        'grand_total_cash': 98000.0,
        'groups': [
          {
            'group_name': 'Unity Group',
            'total_repayment': 50000.0,
            'member_savings': 10000.0,
            'group_savings': 2000.0,
            'total_savings': 12000.0,
            'grand_total': 62000.0,
            'paying_members_count': 5,
          },
          {
            'group_name': 'Favour Group',
            'total_repayment': 30000.0,
            'member_savings': 6000.0,
            'group_savings': 0.0,
            'total_savings': 6000.0,
            'grand_total': 36000.0,
            'paying_members_count': 3,
          },
        ],
        'repayments': [
          {
            'client_id': 'c-1',
            'client_code': 'CL-001',
            'client_name': 'Amina Bello',
            'group_name': 'Unity Group',
            'product': '12-Week Cash',
            'expected_repayment': 10000.0,
            'repayment_paid': 10000.0,
            'repayment_status': 'PAID',
            'savings_deposited': 2000.0,
            'officer': 'co_1',
            'time': '09:30',
          },
        ],
        'savings': [],
        'reversed_records': [],
        'eod_summary': <String, dynamic>{},
        'eod_log': [],
      };

  @override
  Future<Map<String, dynamic>> getReversalOptions({
    String? category,
    String? date,
    bool allRecent = false,
    String? search,
  }) async =>
      {'options': []};

  @override
  Future<Map<String, dynamic>> getReversalRequests() async => {'requests': []};

  @override
  Future<Map<String, dynamic>> getIndividualWithdrawalOptions() async => {
        'groups': ['All Groups', 'Unity Group'],
        'all_groups': [
          {'group_id': 'g-1', 'name': 'Unity Group'},
        ],
        'clients': [
          {
            'client_id': 'c-1',
            'client_code': 'CL-001',
            'name': 'Amina Bello',
            'group_name': 'Unity Group',
            'savings_balance': 25000.0,
            'eligible_loans': [],
          },
        ],
        'business_date': '2026-11-25',
      };

  @override
  Future<Map<String, dynamic>> getGroupWithdrawalOptions() async => {
        'groups': [
          {
            'group_id': 'g-1',
            'name': 'Unity Group',
            'savings_balance': 40000.0,
            'members': [],
          },
        ],
        'all_clients': [],
      };

  @override
  Future<Map<String, dynamic>> getMiscWithdrawalBalance() async =>
      {'balance': 12000.0};

  @override
  Future<Map<String, dynamic>> getLapsWithdrawalOptions() async => {
        'clients': [
          {'client_id': 'c-1', 'name': 'Amina Bello', 'laps_balance': 8000.0},
        ],
      };

  @override
  Future<Map<String, dynamic>> getWithdrawalRequests() async => {'requests': []};

  @override
  Future<Map<String, dynamic>> getDailyWithdrawals({
    String? date,
    bool showAll = false,
    String? category,
    String? search,
  }) async =>
      {
        'kpis': {
          'total_withdrawn': 45000.0,
          'loan_fees_deducted': 8000.0,
          'cash_bank_paid': 25000.0,
          'debt_fee_offsets': 7000.0,
          'laps_reserved': 5000.0,
          'waiting_for_approval_count': 1,
          'waiting_for_approval_amount': 10000.0,
        },
        'all_records': [
          {
            'date': '2026-11-25',
            'client_name': 'Amina Bello',
            'client_code': 'CL-001',
            'group': 'Unity Group',
            'category': 'Cash Withdrawal',
            'amount': 25000.0,
            'details': 'Member withdrawal request',
            'reference': 'WD-2026-001',
            'status': 'APPROVED',
          },
        ],
        'loan_fee_deductions': [
          {
            'date': '2026-11-25',
            'client_name': 'Bisi Ade',
            'client_code': 'CL-003',
            'loan_ref': 'LN-003',
            'interest_deducted': 6000.0,
            'gap_fee_deducted': 2000.0,
            'total_deducted': 8000.0,
            'status': 'ACTIVE',
          },
        ],
        'cash_bank_payouts': [
          {
            'date': '2026-11-25',
            'client_name': 'Amina Bello',
            'group': 'Unity Group',
            'payment_type': 'Cash',
            'amount': 25000.0,
            'approval_notes': 'Verified voucher',
            'reference': 'WD-2026-001',
          },
        ],
        'my_requests': [],
      };

  @override
  Future<Map<String, dynamic>> getPendingApprovals() async => {'requests': []};

  @override
  Future<Map<String, dynamic>> getPortfolioData({
    String? branch,
    String? officer,
    String? group,
    String? product,
    String? timePeriod,
    String? startDate,
    String? endDate,
  }) async =>
      {
        'summary': {
          'registered_clients': 12,
          'active_clients': 45,
          'completed_clients': 18,
          'pending_loan_clients': 3,
          'savings_only_clients': 5,
          'dormant_clients': 2,
          'suspended_clients': 0,
          'closed_clients': 1,
          'defaulters': 1,
          'total_savings_balance': 840000.0,
          'total_deposits': 95000.0,
          'total_withdrawals': 25000.0,
          'total_disbursed': 1400000.0,
          'total_active_credit': 1568000.0,
          'total_outstanding_balance': 920000.0,
          'total_actual_collection': 140000.0,
          'today_collection': 140000.0,
          'active_loans_count': 45,
          'par': '2.4%',
          'repayment_rate': '97.6%',
        },
        'category_summary': {
          '12_week': {
            'total_count': 25,
            'active_credit': 800000.0,
            'outstanding_balance': 480000.0,
            'cash_count': 20,
            'asset_count': 5,
          },
          '24_week': {
            'total_count': 10,
            'active_credit': 400000.0,
            'outstanding_balance': 260000.0,
            'cash_count': 8,
            'asset_count': 2,
          },
          'asset_all': {
            'total_count': 7,
            'active_credit': 200000.0,
            'outstanding_balance': 120000.0,
            'cash_count': 0,
            'asset_count': 7,
          },
          'daily': {
            'total_count': 2,
            'active_credit': 100000.0,
            'outstanding_balance': 35000.0,
            'cash_count': 2,
            'asset_count': 0,
          },
          'monthly': {
            'total_count': 1,
            'active_credit': 68000.0,
            'outstanding_balance': 25000.0,
            'cash_count': 1,
            'asset_count': 0,
          },
        },
        'group_matrix': [
          {
            'Group Name': 'Unity Group',
            'Meeting Day': 'Monday',
            '12W Cash': 10,
            '12W Asset': 2,
            '24W Cash': 4,
            '24W Asset': 1,
            'Daily': 1,
            'Monthly': 0,
            'Total Active Loans': 18,
            'Total Active Credit': 700000.0,
            'Total Outstanding Balance': 420000.0,
          },
        ],
        'client_table': [
          {
            'Client Code': 'CL-001',
            'Client Name': 'Amina Bello',
            'Group': 'Unity Group',
            'Loan Product': '12-Week Cash',
            'Savings Balance': 25000.0,
            'Principal Loan': 100000.0,
            'Active Loan': 112000.0,
            'Outstanding Balance': 62000.0,
            'Total Paid': 50000.0,
            'Period Excess Paid': 0.0,
            'Status': 'Active',
            'Lifecycle Status': 'On Loan',
          },
        ],
        'group_table': [
          {
            'Group Name': 'Unity Group',
            'Total Clients': 18,
            'Total Savings Balance': 180000.0,
            'Total Active Loan': 700000.0,
            'Total Outstanding Balance': 420000.0,
            'Total Fixed Repayment': 42000.0,
            'Total Paid': 280000.0,
          },
        ],
        'payoff_excess_table': [],
        'overdue_recovery_table': [],
        'filter_options': {
          'available_branches': ['All', 'Ikeja Branch'],
          'available_officers': ['All', 'co_1'],
          'available_groups': ['All', 'Unity Group'],
          'available_products': ['All', '12-Week Cash'],
        },
      };

  @override
  Future<List<dynamic>> getIncomingTransfers({String? branchId}) async => [];

  @override
  Future<Map<String, dynamic>> getCoCashbook({
    String? dateStr,
    String? officer,
  }) async =>
      {
        'is_open': true,
        'open_reason': 'Working Day',
        'can_select_officer': false,
        'officers': [],
        'officer': 'co_1',
        'branch': 'Ikeja Branch',
        'date': '2026-11-25',
        'inflows': {
          'opening_balance': 25000.0,
          'savings_deposit': 18000.0,
          'rep_12_weeks': 50000.0,
        },
        'outflows': {
          'active_loan_12w': 40000.0,
          'product_withdrawal': 10000.0,
          'office_expenses': 2500.0,
          'bank_deposit': 20000.0,
        },
        'total_inflows': 93000.0,
        'total_outflows': 72500.0,
        'closing_balance': 20500.0,
        'tally': {
          'not_paid_count': 1,
          'not_paid_list': [
            {
              'name': 'Seyi Ade',
              'code': 'CL-002',
              'expected': 5000.0,
              'shortfall': 5000.0,
              'is_partial': false,
            },
          ],
        },
        'reversal_options': [],
        'submitted_reversals': [],
      };

  @override
  Future<List<dynamic>> getClientFees({
    String? dateStr,
    String? officer,
  }) async {
    if (failClientFees) {
      throw DioException(
        requestOptions: RequestOptions(path: '/api/v1/co/cashbook/client-fees'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions:
              RequestOptions(path: '/api/v1/co/cashbook/client-fees'),
          statusCode: 500,
          data: {'detail': 'Fee registry service unavailable'},
        ),
      );
    }
    return [
      {
        'fee_type': 'Pass Book',
        'client_code': 'CL-001',
        'client_name': 'Amina Bello',
        'amount': 1000.0,
      },
    ];
  }
}

final List<String> _capturedDetails = [];

void _installErrorCapture() {
  _capturedDetails.clear();
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    _capturedDetails.add(details.toString());
    prev?.call(details);
  };
  addTearDown(() => FlutterError.onError = prev);
}

void _assertNoException(WidgetTester tester) {
  final err = tester.takeException();
  if (err != null) {
    final details = _capturedDetails.isNotEmpty
        ? _capturedDetails.join('\n---\n')
        : err.toString();
    fail('Unexpected layout/runtime error:\n$details');
  }
}

void _assertNoForbiddenText(WidgetTester tester) {
  final emojiPattern = RegExp(
    r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
    unicode: true,
  );
  final leakPattern = RegExp(
    r'\b(Account 1000|BR-[A-Z]+-\d+|FP-\d+|October 2026)\b|200MB|_buildStreamlit',
  );
  for (final w in tester.allWidgets) {
    if (w is Text && w.data != null) {
      expect(
        emojiPattern.hasMatch(w.data!),
        isFalse,
        reason: 'Forbidden emoji in UI: "${w.data}"',
      );
      expect(
        leakPattern.hasMatch(w.data!),
        isFalse,
        reason: 'Forbidden internal string in UI: "${w.data}"',
      );
    }
  }
}

List<Override> _buildOverrides({bool failClientFees = false}) {
  final conn = _QuietConn();
  final offlineDb = OfflineDatabaseService(useMemoryStore: true);
  final apiClient = ApiClient(
    connectivityService: conn,
    offlineDb: offlineDb,
    adapter: _NoopHttpAdapter(),
    isWebOverride: false,
  );
  final coApi = _FakeCoApiService(apiClient, failClientFees: failClientFees);
  final coUser = AuthUser(
    id: 'co-1',
    username: 'co_1',
    fullName: 'Ada Obi',
    role: 'Credit Officer',
    branch: 'Ikeja Branch',
    branchId: 'br-ikeja',
    assignedBranches: ['Ikeja Branch'],
    assignedBranchIds: ['br-ikeja'],
  );

  return [
    connectivityServiceProvider.overrideWithValue(conn),
    offlineDatabaseServiceProvider.overrideWithValue(offlineDb),
    apiClientProvider.overrideWithValue(apiClient),
    coApiServiceProvider.overrideWithValue(coApi),
    authControllerProvider.overrideWith(
      (_) => _StaticAuthController(coUser, apiClient, offlineDb),
    ),
    themeControllerProvider.overrideWith((_) => ThemeController(autoLoad: false)),
    activeCoPageProvider.overrideWith((_) => 'Dashboard'),
    selectedCollectionGroupProvider.overrideWith((_) => null),
  ];
}

Future<void> _pumpCoScreen(
  WidgetTester tester, {
  required Widget child,
  required double width,
  required ThemeMode themeMode,
  bool failClientFees = false,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _installErrorCapture();

  await tester.pumpWidget(
    ProviderScope(
      overrides: _buildOverrides(failClientFees: failClientFees),
      child: MaterialApp(
        theme: IcareTheme.lightTheme,
        darkTheme: IcareTheme.darkTheme,
        themeMode: themeMode,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  _assertNoException(tester);
  _assertNoForbiddenText(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3 Credit Officer Suite Responsive & Fluid UI Verification', () {
    for (final width in <double>[360, 800, 1280]) {
      testWidgets('CoDashboardScreen renders cleanly at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const CoDashboardScreen(),
          width: width,
          themeMode: width == 800 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);
        if (width >= 800) {
          expect(find.byType(BarChart), findsOneWidget);
          expect(find.byType(PieChart), findsOneWidget);
        }
      });

      testWidgets('LoanOriginationScreen renders all tabs cleanly at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const LoanOriginationScreen(),
          width: width,
          themeMode: width == 360 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);
        expect(find.textContaining('200MB'), findsNothing);

        // Advance Step 1 -> Step 4 (KYC & Uploads) to verify document upload zones
        await tester.enterText(find.byType(TextField).at(0), 'Aminat Adeleke');
        await tester.enterText(find.byType(TextField).at(2), '08012345678');
        await tester.ensureVisible(find.text('Continue to Business Profile'));
        await tester.tap(find.text('Continue to Business Profile'));
        await tester.pumpAndSettle();
        _assertNoException(tester);

        await tester.ensureVisible(find.text('Continue to Guarantor'));
        await tester.tap(find.text('Continue to Guarantor'));
        await tester.pumpAndSettle();
        _assertNoException(tester);

        await tester.ensureVisible(find.text('Continue to KYC Uploads'));
        await tester.tap(find.text('Continue to KYC Uploads'));
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.textContaining('200MB'), findsNothing);
        expect(find.textContaining('Limit 10 MB'), findsAtLeastNWidgets(1));

        // Switch to Pending Disbursements tab
        await tester.ensureVisible(find.textContaining('Pending Disbursements').first);
        await tester.tap(find.textContaining('Pending Disbursements').first);
        await tester.pumpAndSettle();
        _assertNoException(tester);
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        if (width >= 800) {
          expect(find.byType(IcareDataTable), findsOneWidget);
        }
      });

      testWidgets('DailyCollectionsScreen renders Record & History charts cleanly at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const DailyCollectionsScreen(),
          width: width,
          themeMode: width == 1280 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);

        // Tap Audit Stage (03 / Collection Audit) to switch to History Tab
        await tester.tap(find.text('Posted Ledger'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
        _assertNoForbiddenText(tester);
      });

      testWidgets('WithdrawalOperationsScreen renders cleanly at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const WithdrawalOperationsScreen(),
          width: width,
          themeMode: width == 800 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);

        await tester.ensureVisible(find.text('Daily Withdrawals').first);
        await tester.tap(find.text('Daily Withdrawals').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
        if (width >= 800) {
          expect(find.byType(IcareDataTable), findsOneWidget);
        }
      });

      testWidgets('PortfolioOverviewScreen renders dynamically without 22/23 pill at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const PortfolioOverviewScreen(),
          width: width,
          themeMode: width == 360 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);
        expect(find.text('22'), findsNothing);
        expect(find.text('23'), findsNothing);
        if (width < 900) {
          await tester.ensureVisible(find.text('Products').first);
          await tester.tap(find.text('Products').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.byType(BarChart), findsAtLeastNWidgets(1));
        expect(find.byType(PieChart), findsAtLeastNWidgets(1));
      });

      testWidgets('DailyCashbookScreen renders T-Ledger, Bridge Chart, and Record Client Fee cleanly at ${width.toInt()}px', (tester) async {
        await _pumpCoScreen(
          tester,
          child: const DailyCashbookScreen(),
          width: width,
          themeMode: width == 1280 ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.byType(CoOperationalFlowCard), findsOneWidget);
        expect(find.byType(BarChart), findsOneWidget);
        expect(find.byType(PieChart), findsOneWidget);
        if (width < 900) {
          await tester.ensureVisible(find.text('EOD Inputs').first);
          await tester.tap(find.text('EOD Inputs').first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Record Client Fee'), findsOneWidget);
        }
      });
    }

    testWidgets('DailyCashbookScreen surfaces visible Retry card when client fees fetch fails', (tester) async {
      await _pumpCoScreen(
        tester,
        child: const DailyCashbookScreen(),
        width: 1280,
        themeMode: ThemeMode.light,
        failClientFees: true,
      );
      await tester.ensureVisible(find.text('End of Day Outflows & Fees'));
      await tester.tap(find.text('End of Day Outflows & Fees'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(CoInlineErrorCard), findsOneWidget);
      expect(find.textContaining('Retry'), findsAtLeastNWidgets(1));
    });

    testWidgets('showBranchAssetCatalogDialog opens adaptive sheet on mobile and desktop', (tester) async {
      for (final width in <double>[360, 1280]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: IcareTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    showBranchAssetCatalogDialog(
                      context: context,
                      branchName: 'Ikeja Branch',
                      canManageInventory: false,
                      initialItems: const [
                        {
                          'item_id': 'ast-1',
                          'sku_code': 'FRZ-001',
                          'category': 'FREEZER',
                          'item_name': 'Bruhm 100L Freezer',
                          'cash_and_carry_price': 200000.0,
                          'easy_buy_60d_price': 224000.0,
                          'easy_buy_120d_price': 242000.0,
                          'quantity_available': 5,
                        },
                      ],
                      categories: const [
                        {
                          'category': 'FREEZER',
                          'catalog_skus': 1,
                          'in_stock_skus': 1,
                          'units_available': 5,
                        },
                      ],
                      summary: const {
                        'total_catalog_skus': 1,
                        'branch_stocked_skus': 1,
                        'total_units_available': 5,
                      },
                      onAdjustItem: (_, __, ___, ____, _____) async => {},
                    );
                  },
                  child: const Text('Open Catalog'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open Catalog'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Master Asset Price List & Branch Stock'), findsOneWidget);
        expect(find.byType(IcareStatusBadge), findsAtLeastNWidgets(1));
        expect(find.text('In Stock Only'), findsOneWidget);
        expect(find.text('5 in stock'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.text('Master Asset Price List & Branch Stock'), findsNothing);
      }
    });
  });
}
