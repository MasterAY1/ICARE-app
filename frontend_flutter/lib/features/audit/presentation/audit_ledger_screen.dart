import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/role_utils.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../shared/presentation/co_app_scaffold.dart';
import '../data/models/audit_models.dart';
import 'providers/audit_providers.dart';
import 'widgets/audit_explorer_tab.dart';
import 'widgets/audit_integrity_and_insights_tabs.dart';
import 'widgets/audit_ledger_tabs.dart';
import 'widgets/audit_shared_widgets.dart';

class AuditLedgerScreen extends ConsumerStatefulWidget {
  const AuditLedgerScreen({super.key});

  @override
  ConsumerState<AuditLedgerScreen> createState() => _AuditLedgerScreenState();
}

class _AuditLedgerScreenState extends ConsumerState<AuditLedgerScreen> {
  String _activeTab = '';

  IconData _tabIcon(String tab) {
    switch (tab) {
      case '6-Way Integrity Match':
        return Icons.verified_outlined;
      case 'Fees Audit':
        return Icons.receipt_long_outlined;
      case 'Treasury Audit':
        return Icons.account_balance_outlined;
      case 'Savings Ledger':
        return Icons.savings_outlined;
      case 'Withdrawals Audit':
        return Icons.currency_exchange_outlined;
      case 'Loan Portfolio':
        return Icons.payments_outlined;
      case 'Collection Performance':
        return Icons.trending_up_outlined;
      case 'Exception Reports':
        return Icons.warning_amber_rounded;
      case '360° Explorer & Timeline':
        return Icons.travel_explore;
      case 'Performance Insights':
        return Icons.insights_outlined;
      case 'Reconciliation Wizard':
        return Icons.auto_fix_high;
      default:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthStateAuthenticated ? authState.user : null;

    ref.listen<int>(globalRefreshSignalProvider, (prev, next) {
      if (next != prev) {
        invalidateAllAuditProviders(ref);
      }
    });

    if (user == null) {
      return Center(
        child: Text(
          'Session expired. Please sign in again.',
          style: TextStyle(color: tokens.textMuted),
        ),
      );
    }

    final isCo = IcareRoleUtils.isCo(user.role);
    final isBm = IcareRoleUtils.isBm(user.role);
    final isAm = IcareRoleUtils.isAm(user.role);
    final isDirector = IcareRoleUtils.isDirector(user.role);
    final isAdmin = IcareRoleUtils.isAdmin(user.role);

    if (!isCo && !isBm && !isAm && !isDirector && !isAdmin) {
      return IcareCard(
        topAccentColor: tokens.dangerDot,
        child: Row(
          children: [
            Icon(Icons.gpp_bad_outlined, color: tokens.dangerDot, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You do not have permission to access the Audit Ledger.',
                style: TextStyle(
                  color: tokens.dangerText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final List<String> availableTabs;
    final String pageTitle;
    final String pageCaption;

    if (isCo) {
      pageTitle = 'Credit Officer Audit Ledger';
      pageCaption =
          'Scoped audit view of your savings entries, loan facilities, and schedule collections.';
      availableTabs = const [
        'Savings Ledger',
        'Loan Portfolio',
        'Collection Performance',
      ];
    } else if (isAm) {
      pageTitle = 'Area Supervisory Audit Ledger';
      pageCaption =
          'Multi-branch 6-way integrity verification, virtual audit ledgers, and 360° search across assigned branches.';
      availableTabs = const [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Withdrawals Audit',
        'Loan Portfolio',
        'Collection Performance',
        '360° Explorer & Timeline',
      ];
    } else if (isBm) {
      pageTitle = 'Branch Audit Ledger';
      pageCaption =
          'Branch audit trail, 6-way verification, and transaction explorer for ${user.branch}.';
      availableTabs = const [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Withdrawals Audit',
        'Loan Portfolio',
        'Collection Performance',
        '360° Explorer & Timeline',
      ];
    } else if (isDirector) {
      pageTitle = 'Executive Audit Oversight Center';
      pageCaption =
          'Read-only institutional ledgers, 6-way integrity checks, 15 automated exception controls, and 5-tier portfolio insights.';
      availableTabs = const [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Withdrawals Audit',
        'Loan Portfolio',
        'Collection Performance',
        'Exception Reports',
        '360° Explorer & Timeline',
        'Performance Insights',
      ];
    } else {
      pageTitle = 'Enterprise Audit & Reconciliation Center';
      pageCaption =
          'Institution-wide ledgers, 6-way integrity verification, exception controls, 360° explorer, and projection repair.';
      availableTabs = const [
        '6-Way Integrity Match',
        'Fees Audit',
        'Treasury Audit',
        'Savings Ledger',
        'Withdrawals Audit',
        'Loan Portfolio',
        'Collection Performance',
        'Exception Reports',
        '360° Explorer & Timeline',
        'Performance Insights',
        'Reconciliation Wizard',
      ];
    }

    if (!availableTabs.contains(_activeTab)) {
      _activeTab = availableTabs.first;
    }

    final metaScopeBranch = (isAdmin || isDirector || isAm) ? null : user.branchId;
    final asyncMeta = ref.watch(auditMetaProvider(metaScopeBranch));
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 740;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pageTitle,
          style: TextStyle(
            fontSize: isMobile ? 20 : 25,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          pageCaption,
          style: TextStyle(fontSize: 13, color: tokens.textMuted),
        ),
        if (isDirector) ...[
          const SizedBox(height: 12),
          IcareCard(
            topAccentColor: tokens.infoDot,
            backgroundColor: tokens.infoBg,
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: tokens.infoDot, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Read-Only Executive Oversight Mode: Projection repair and mutating utilities are locked for Director accounts.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.infoText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: availableTabs.map((tab) {
              final selected = _activeTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _activeTab = tab),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected ? tokens.brandPrimaryDark : tokens.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? tokens.brandPrimaryDark
                            : tokens.borderSubtle,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabIcon(tab),
                          size: 15,
                          color: selected ? Colors.white : tokens.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        asyncMeta.when(
          loading: () => _buildTabBody(
            meta: null,
            user: user,
            isCo: isCo,
            isAm: isAm,
            isAdmin: isAdmin,
            isDirector: isDirector,
          ),
          error: (err, _) => buildAuditErrorCard(
            context,
            err,
            onRetry: () => ref.invalidate(auditMetaProvider(metaScopeBranch)),
          ),
          data: (meta) => _buildTabBody(
            meta: meta,
            user: user,
            isCo: isCo,
            isAm: isAm,
            isAdmin: isAdmin,
            isDirector: isDirector,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody({
    required AuditMetaModel? meta,
    required AuthUser user,
    required bool isCo,
    required bool isAm,
    required bool isAdmin,
    required bool isDirector,
  }) {
    final canSwitchBranch = isAdmin || isDirector || isAm;
    final metaBranches = meta?.branches ?? const <BranchOptionModel>[];

    List<String> buildBranchOptions({required bool includeAll}) {
      final names = metaBranches
          .map((b) => b.name)
          .where((n) => n.trim().isNotEmpty && n != 'All Branches')
          .toList();
      if (isAm) {
        return includeAll
            ? ['All Assigned Branches', ...names]
            : (names.isNotEmpty
                ? names
                : (user.branch.isNotEmpty ? [user.branch] : <String>[]));
      }
      if (!isAdmin && !isDirector) {
        if (user.branch.isNotEmpty) return [user.branch];
        return names.isNotEmpty ? [names.first] : <String>[];
      }
      return includeAll ? ['All Branches', ...names] : names;
    }

    String? resolveBranchId(String selectedName) {
      if (selectedName.isEmpty ||
          selectedName == 'All Branches' ||
          selectedName == 'All Assigned Branches') {
        return null;
      }
      for (final b in metaBranches) {
        if (b.name == selectedName) {
          return (b.branchId.isEmpty || b.branchId.toUpperCase() == 'ALL')
              ? null
              : b.branchId;
        }
      }
      return (user.branchId ?? '').isNotEmpty ? user.branchId : null;
    }

    String? resolveOfficerId(String display) {
      if (display == 'All Officers' || display.isEmpty || meta == null) {
        return null;
      }
      for (final o in meta.officers) {
        if (o.displayName == display || o.username == display) return o.id;
      }
      return null;
    }

    String? resolveProductId(String name) {
      if (name == 'All Products' || name.isEmpty || meta == null) return null;
      for (final p in meta.products) {
        if (p.name == name) return p.productId;
      }
      return null;
    }

    final tabCtx = AuditLedgerTabContext(
      defaultBranchId: user.branchId ?? '',
      branchOptions: buildBranchOptions(includeAll: canSwitchBranch),
      officerOptions: [
        'All Officers',
        ...(meta?.officers.map((o) => o.displayName) ?? const <String>[]),
      ],
      products: meta?.products ?? const <ProductOptionModel>[],
      canSwitchBranch: canSwitchBranch,
      isOfficer: isCo,
      resolveBranchId: resolveBranchId,
      resolveOfficerId: resolveOfficerId,
      resolveProductId: resolveProductId,
    );

    final scopedBranchOrNull = canSwitchBranch ? null : user.branchId;

    switch (_activeTab) {
      case '6-Way Integrity Match':
        return AuditIntegrityTab(
          fallbackBranchId: user.branchId ?? '',
          branchOptions: buildBranchOptions(includeAll: false),
          resolveBranchId: resolveBranchId,
          canSwitchBranch: canSwitchBranch,
        );
      case 'Fees Audit':
        return AuditFeesTab(ctx: tabCtx);
      case 'Treasury Audit':
        return AuditTreasuryTab(ctx: tabCtx);
      case 'Savings Ledger':
        return AuditSavingsTab(ctx: tabCtx);
      case 'Withdrawals Audit':
        return AuditWithdrawalsTab(ctx: tabCtx);
      case 'Loan Portfolio':
        return AuditLoansTab(ctx: tabCtx);
      case 'Collection Performance':
        return AuditCollectionsTab(ctx: tabCtx);
      case 'Exception Reports':
        return AuditExceptionsTab(branchId: scopedBranchOrNull);
      case '360° Explorer & Timeline':
        return AuditExplorerTab(scopedBranchId: scopedBranchOrNull);
      case 'Performance Insights':
        return AuditInsightsTab(branchId: scopedBranchOrNull);
      case 'Reconciliation Wizard':
        return AuditWizardTab(
          isAdmin: isAdmin,
          isDirector: isDirector,
          fallbackBranchId: user.branchId ?? '',
          branchOptions: buildBranchOptions(includeAll: false),
          resolveBranchId: resolveBranchId,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
