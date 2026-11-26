import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_controller.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/auth/role_utils.dart';
import '../../../../core/errors/app_error_formatter.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../../core/widgets/icare_section_header.dart';
import '../../../../core/widgets/icare_skeleton_loader.dart';
import '../../data/datasources/user_management_api_service.dart';
import '../providers/user_management_providers.dart';
import 'um_shared_widgets.dart';

class UmCreateUserTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  final bool isBm;
  final bool isAm;
  final String callerBranchName;
  final UmFlashCallback onFlash;

  const UmCreateUserTab({
    super.key,
    required this.isAdmin,
    required this.isBm,
    required this.isAm,
    required this.callerBranchName,
    required this.onFlash,
  });

  @override
  ConsumerState<UmCreateUserTab> createState() => _UmCreateUserTabState();
}

class _UmCreateUserTabState extends ConsumerState<UmCreateUserTab> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _role = 'Credit Officer';
  String _branch = '';
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncUsers = ref.watch(userDirectoryProvider);

    return asyncUsers.when(
      loading: () => const IcareFormSkeleton(fieldCount: 5),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(userDirectoryProvider),
      ),
      data: (data) {
        final List<String> roleOptions;
        if (widget.isBm) {
          roleOptions = const ['Credit Officer'];
        } else if (widget.isAm) {
          roleOptions = const ['Credit Officer', 'Branch Manager'];
        } else {
          roleOptions = const [
            'Credit Officer',
            'Branch Manager',
            'Area Manager',
            'Account Manager',
            'Procurement Officer',
            'Admin',
            'Super Admin',
          ];
        }

        if (!roleOptions.contains(_role)) {
          _role = roleOptions.first;
        }

        final dynamicBranches = <String>{
          ...data.availableBranches
              .map((b) => b.name.trim())
              .where((b) => b.isNotEmpty),
          if (widget.callerBranchName.trim().isNotEmpty && !widget.isAdmin)
            widget.callerBranchName.trim(),
        }.toList()
          ..sort();

        final List<String> branchOptions;
        if (widget.isBm) {
          branchOptions = [
            widget.callerBranchName.trim().isNotEmpty
                ? widget.callerBranchName.trim()
                : (dynamicBranches.isNotEmpty ? dynamicBranches.first : ''),
          ].where((b) => b.isNotEmpty).toList();
        } else {
          branchOptions = dynamicBranches;
        }

        if (branchOptions.isNotEmpty && !branchOptions.contains(_branch)) {
          _branch = branchOptions.first;
        }

        final infoMsg = widget.isBm
            ? 'Register a new Credit Officer for ${widget.callerBranchName.isNotEmpty ? widget.callerBranchName : 'your branch'}.'
            : (widget.isAm
                ? 'Provision a Branch Manager or Credit Officer inside your supervised branches.'
                : 'Head Office administrators can provision accounts across all institutional roles.');

        return IcareCard(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IcareSectionHeader(
                  title: 'Provision New Staff Account',
                  subtitle: 'Creates an operational login profile scoped to role and branch governance.',
                ),
                const SizedBox(height: 12),
                buildUmInfoCard(context, infoMsg),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: umInputDecoration(
                    context,
                    label: 'Username',
                    hint: 'e.g. CO5 or BM_Ogijo',
                  ),
                  validator: (val) =>
                      (val == null || val.trim().length < 2)
                          ? 'Username must be at least 2 characters'
                          : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: umInputDecoration(
                    context,
                    label: 'Full Name',
                    hint: 'e.g. Mrs. Funmilayo Adeleke',
                  ),
                  validator: (val) =>
                      (val == null || val.trim().length < 2)
                          ? 'Full Name is required'
                          : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _role,
                  isExpanded: true,
                  dropdownColor: tokens.surfaceElevated,
                  decoration: umInputDecoration(context, label: 'Assigned Role'),
                  items: roleOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: widget.isBm
                      ? null
                      : (val) => setState(() => _role = val ?? roleOptions.first),
                ),
                const SizedBox(height: 14),
                if (branchOptions.isEmpty)
                  buildUmInfoCard(
                    context,
                    'No active branches returned for your scope. Confirm branch assignment before creating users.',
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _branch,
                    isExpanded: true,
                    dropdownColor: tokens.surfaceElevated,
                    decoration:
                        umInputDecoration(context, label: 'Assigned Branch'),
                    items: branchOptions
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: widget.isBm
                        ? null
                        : (val) => setState(
                              () => _branch = val ?? branchOptions.first,
                            ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: umInputDecoration(
                    context,
                    label: 'Initial Temporary Password',
                    hint: 'Minimum 4 characters',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) => (val == null || val.length < 4)
                      ? 'Password must be at least 4 characters'
                      : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_submitting || branchOptions.isEmpty)
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.brandPrimaryDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1, size: 18),
                    label: Text(
                      _submitting ? 'Creating Account...' : 'Create User Account',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final res =
          await ref.read(userManagementApiServiceProvider).createUser(
                username: _usernameCtrl.text.trim(),
                fullName: _fullNameCtrl.text.trim(),
                password: _passwordCtrl.text,
                role: _role,
                branchName: _branch.isNotEmpty ? _branch : null,
              );
      _usernameCtrl.clear();
      _fullNameCtrl.clear();
      _passwordCtrl.clear();
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to create user: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class UmPasswordResetTab extends ConsumerStatefulWidget {
  final bool isBm;
  final bool isAm;
  final UmFlashCallback onFlash;

  const UmPasswordResetTab({
    super.key,
    required this.isBm,
    required this.isAm,
    required this.onFlash,
  });

  @override
  ConsumerState<UmPasswordResetTab> createState() => _UmPasswordResetTabState();
}

class _UmPasswordResetTabState extends ConsumerState<UmPasswordResetTab> {
  final _pwCtrl = TextEditingController();
  String? _selectedUsername;
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncUsers = ref.watch(userDirectoryProvider);
    final authState = ref.watch(authControllerProvider);
    final currentUid =
        authState is AuthStateAuthenticated ? authState.user.id : null;

    return asyncUsers.when(
      loading: () => const IcareFormSkeleton(fieldCount: 3),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(userDirectoryProvider),
      ),
      data: (data) {
        final scoped = filterScopedUsers(
          data.users,
          isBm: widget.isBm,
          isAm: widget.isAm,
          currentUserId: currentUid,
        );

        if (scoped.isEmpty) {
          return buildUmInfoCard(
            context,
            'No eligible accounts available for password reset in your scope.',
          );
        }

        if (_selectedUsername == null ||
            !scoped.any((u) => u.username == _selectedUsername)) {
          _selectedUsername = scoped.first.username;
        }

        return IcareCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IcareSectionHeader(
                title: 'Administrative Password Reset',
                subtitle: 'Issue a new temporary password for a scoped staff account.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUsername,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                decoration: umInputDecoration(context, label: 'Select Staff Account'),
                items: scoped
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.username,
                        child: Text(
                          '${u.username} — ${u.fullName} (${IcareRoleUtils.displayLabel(u.role)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedUsername = val),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pwCtrl,
                obscureText: _obscure,
                decoration: umInputDecoration(
                  context,
                  label: 'New Temporary Password',
                  hint: 'Minimum 4 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: Text(
                    _submitting ? 'Resetting...' : 'Reset Account Password',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final uname = _selectedUsername;
    final pw = _pwCtrl.text;
    if (uname == null || pw.length < 4) {
      widget.onFlash(
        'Select a user and provide a password of at least 4 characters.',
        isError: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .resetPassword(username: uname, newPassword: pw);
      _pwCtrl.clear();
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to reset password: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class UmOfficerTurnoverTab extends ConsumerStatefulWidget {
  final UmFlashCallback onFlash;

  const UmOfficerTurnoverTab({super.key, required this.onFlash});

  @override
  ConsumerState<UmOfficerTurnoverTab> createState() =>
      _UmOfficerTurnoverTabState();
}

class _UmOfficerTurnoverTabState extends ConsumerState<UmOfficerTurnoverTab> {
  final _newNameCtrl = TextEditingController();
  String? _selectedUsername;
  bool _submitting = false;

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final asyncUsers = ref.watch(userDirectoryProvider);

    return asyncUsers.when(
      loading: () => const IcareFormSkeleton(fieldCount: 3),
      error: (err, _) => buildUmErrorCard(
        context,
        err,
        onRetry: () => ref.invalidate(userDirectoryProvider),
      ),
      data: (data) {
        final coUsers = data.users
            .where((u) => IcareRoleUtils.isCo(u.role))
            .toList();

        if (coUsers.isEmpty) {
          return buildUmInfoCard(
            context,
            'No Credit Officer accounts found for officer turnover.',
          );
        }

        if (_selectedUsername == null ||
            !coUsers.any((u) => u.username == _selectedUsername)) {
          _selectedUsername = coUsers.first.username;
        }

        final selectedCo = coUsers.firstWhere(
          (u) => u.username == _selectedUsername,
          orElse: () => coUsers.first,
        );

        return IcareCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IcareSectionHeader(
                title: 'Officer Handover & Name Update',
                subtitle: 'Update the officer full name linked to a standing generic desk username so historical ledgers remain intact.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUsername,
                isExpanded: true,
                dropdownColor: tokens.surfaceElevated,
                decoration:
                    umInputDecoration(context, label: 'Select Officer Desk'),
                items: coUsers
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.username,
                        child: Text(
                          '${u.username} — ${u.fullName} (${u.branchName ?? 'Unassigned'})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedUsername = val),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Row(
                  children: [
                    Text(
                      'Current Holder: ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        selectedCo.fullName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: tokens.brandPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newNameCtrl,
                decoration: umInputDecoration(
                  context,
                  label: 'New Incoming Officer Full Name',
                  hint: 'e.g. Mr. Emmanuel Ojo',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.brandPrimaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    _submitting ? 'Updating...' : 'Update Officer Identity',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final uname = _selectedUsername;
    final newName = _newNameCtrl.text.trim();
    if (uname == null || newName.length < 2) {
      widget.onFlash(
        'Select an officer and enter a new full name (min 2 characters).',
        isError: true,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ref
          .read(userManagementApiServiceProvider)
          .updateOfficerTurnover(username: uname, newName: newName);
      _newNameCtrl.clear();
      invalidateAllUserManagementProviders(ref);
      widget.onFlash(res.message, isError: false);
    } catch (e) {
      widget.onFlash(
        'Failed to update officer name: ${AppErrorDetails.from(e).message}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
