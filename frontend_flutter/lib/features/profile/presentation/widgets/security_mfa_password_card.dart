import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';
import '../../../auth/presentation/widgets/auth_entry_components.dart';
import '../../../shared/utils/file_download_helper.dart';
import '../../data/models/profile_models.dart';

class SecurityMfaPasswordCard extends StatefulWidget {
  final bool mfaEnabled;
  final String? mfaEnrolledAt;
  final int remainingBackupCodes;
  final bool canSelfChangePassword;
  final bool isMfaBusy;
  final bool isPasswordBusy;
  final MfaSetupBundle? pendingMfaBundle;
  final VoidCallback onInitiateMfaSetup;
  final VoidCallback onCancelMfaSetup;
  final Future<void> Function(String code) onActivateMfa;
  final Future<void> Function(String password) onDisableMfa;
  final Future<bool> Function(String currentPassword, String newPassword)
      onChangePassword;

  const SecurityMfaPasswordCard({
    super.key,
    required this.mfaEnabled,
    this.mfaEnrolledAt,
    this.remainingBackupCodes = 0,
    required this.canSelfChangePassword,
    required this.isMfaBusy,
    required this.isPasswordBusy,
    this.pendingMfaBundle,
    required this.onInitiateMfaSetup,
    required this.onCancelMfaSetup,
    required this.onActivateMfa,
    required this.onDisableMfa,
    required this.onChangePassword,
  });

  @override
  State<SecurityMfaPasswordCard> createState() =>
      _SecurityMfaPasswordCardState();
}

class _SecurityMfaPasswordCardState extends State<SecurityMfaPasswordCard> {
  final _mfaActivateCtrl = TextEditingController();
  final _curPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();

  bool _obscureCur = true;
  bool _obscureNew = true;
  bool _obscureConf = true;
  String? _localPwError;

  @override
  void dispose() {
    _mfaActivateCtrl.dispose();
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyText(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard.')),
    );
  }

  Future<void> _downloadBackupCodes(List<String> codes) async {
    final text = StringBuffer()
      ..writeln('ICARE CORE BANKING - TWO-FACTOR RECOVERY BACKUP CODES')
      ..writeln('Keep these single-use backup codes in a secure offline location.')
      ..writeln('------------------------------------------------------------')
      ..writeAll(
          codes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}'), '\n');
    final saved = await downloadBlobFile(
      utf8.encode(text.toString()),
      'icare_2fa_backup_codes.txt',
      'text/plain',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved != null
            ? 'Backup recovery codes saved ($saved).'
            : 'Unable to save file on this device; use Copy All instead.'),
      ),
    );
  }

  Future<void> _promptDisableMfa() async {
    final ctrl = TextEditingController();
    bool obscure = true;
    final confirmedPassword = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final tokens = IcareSurfaceTokens.of(ctx);
          return AlertDialog(
            title: const Text('Disable Two-Factor Authentication'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter your account password to disable 2FA.',
                    softWrap: true,
                    style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Account Password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.dangerDot,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(ctrl.text),
                child: const Text('Disable 2FA'),
              ),
            ],
          );
        },
      ),
    );
    ctrl.dispose();

    if (confirmedPassword != null && confirmedPassword.trim().isNotEmpty) {
      await widget.onDisableMfa(confirmedPassword);
    }
  }

  Future<void> _handlePasswordSubmit() async {
    final cur = _curPwCtrl.text;
    final nw = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();

    if (cur.isEmpty) {
      setState(() => _localPwError = 'Enter your current password.');
      return;
    }
    if (nw.length < 8) {
      setState(() =>
          _localPwError = 'New password must be at least 8 characters long.');
      return;
    }
    if (nw == cur.trim()) {
      setState(() =>
          _localPwError = 'New password must differ from current password.');
      return;
    }
    if (nw != conf) {
      setState(
          () => _localPwError = 'New password and confirmation do not match.');
      return;
    }

    setState(() => _localPwError = null);
    final ok = await widget.onChangePassword(cur, nw);
    if (ok && mounted) {
      _curPwCtrl.clear();
      _newPwCtrl.clear();
      _confPwCtrl.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final bundle = widget.pendingMfaBundle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final twoColPasswords = constraints.maxWidth >= 460;

        return IcareCard(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tokens.brandSoftBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.brandSoftBorder),
                    ),
                    child: Icon(
                      Icons.security_outlined,
                      size: 17,
                      color: tokens.brandSoftText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Security & 2FA',
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Compact Two-Factor Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      widget.mfaEnabled ? tokens.successBg : tokens.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.mfaEnabled
                        ? tokens.successBorder
                        : tokens.borderSubtle,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.mfaEnabled
                              ? Icons.verified_user_outlined
                              : Icons.shield_outlined,
                          size: 19,
                          color: widget.mfaEnabled
                              ? tokens.successText
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.mfaEnabled
                                    ? 'Two-Factor Authentication: Enabled'
                                    : 'Two-Factor Authentication: Not Enrolled',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: widget.mfaEnabled
                                      ? tokens.successText
                                      : tokens.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.mfaEnabled
                                    ? '${widget.remainingBackupCodes} recovery backup codes remaining'
                                    : 'Authenticator TOTP protection',
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.mfaEnabled
                                      ? tokens.successText.withValues(alpha: 0.9)
                                      : tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.mfaEnabled)
                          OutlinedButton(
                            onPressed:
                                widget.isMfaBusy ? null : _promptDisableMfa,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: tokens.dangerText,
                              side: BorderSide(color: tokens.dangerBorder),
                              minimumSize: const Size(0, 38),
                            ),
                            child: const Text('Disable'),
                          )
                        else if (bundle == null)
                          ElevatedButton(
                            onPressed: widget.isMfaBusy
                                ? null
                                : widget.onInitiateMfaSetup,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 38),
                            ),
                            child: Text(widget.isMfaBusy
                                ? 'Generating...'
                                : 'Enable 2FA'),
                          ),
                      ],
                    ),

                    // Enrollment Wizard
                    if (!widget.mfaEnabled && bundle != null) ...[
                      const SizedBox(height: 12),
                      Divider(color: tokens.borderSubtle, height: 1),
                      const SizedBox(height: 12),
                      Text(
                        '1. Authenticator Secret Key',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                bundle.secret,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Copy Secret Key',
                              onPressed: () => _copyText(
                                  bundle.secret, 'Authenticator secret'),
                              icon: Icon(Icons.copy_outlined,
                                  size: 16, color: tokens.brandPrimary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '2. Recovery Backup Codes',
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: tokens.textPrimary,
                            ),
                          ),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () => _copyText(
                                    bundle.backupCodes.join('\n'),
                                    'Backup codes'),
                                icon: const Icon(Icons.copy_all_outlined,
                                    size: 14),
                                label: const Text('Copy All'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _downloadBackupCodes(bundle.backupCodes),
                                icon: const Icon(Icons.download_outlined,
                                    size: 14),
                                label: const Text('Save .txt'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: bundle.backupCodes.map((code) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.borderSubtle),
                              ),
                              child: Text(
                                code,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '3. Verify 6-Digit Code',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final stackVertically =
                              innerConstraints.maxWidth < 460;
                          final codeInput = TextField(
                            controller: _mfaActivateCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: '6-Digit TOTP Code',
                              hintText: '123456',
                              counterText: '',
                              prefixIcon:
                                  Icon(Icons.dialpad_outlined, size: 18),
                            ),
                          );
                          final activateBtn = ElevatedButton(
                            onPressed: widget.isMfaBusy
                                ? null
                                : () => widget
                                    .onActivateMfa(_mfaActivateCtrl.text),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(120, 44),
                            ),
                            child: Text(widget.isMfaBusy
                                ? 'Verifying...'
                                : 'Activate 2FA'),
                          );
                          final cancelBtn = OutlinedButton(
                            onPressed: widget.isMfaBusy
                                ? null
                                : widget.onCancelMfaSetup,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(76, 44),
                            ),
                            child: const Text('Cancel'),
                          );

                          if (stackVertically) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                codeInput,
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(child: activateBtn),
                                    const SizedBox(width: 8),
                                    cancelBtn,
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: codeInput),
                              const SizedBox(width: 10),
                              activateBtn,
                              const SizedBox(width: 6),
                              cancelBtn,
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),
              Divider(color: tokens.borderSubtle, height: 1),
              const SizedBox(height: 12),

              // 2. Password Management Section
              Text(
                'Password Policy',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              if (!widget.canSelfChangePassword)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.infoBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.infoBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 18, color: tokens.infoText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Supervisor-Managed Password Policy',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: tokens.infoText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Passwords are reset by your Branch or Area Manager.',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_localPwError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tokens.dangerBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tokens.dangerBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: tokens.dangerText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _localPwError!,
                            softWrap: true,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.dangerText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _curPwCtrl,
                  obscureText: _obscureCur,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCur
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscureCur = !_obscureCur),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (twoColPasswords)
                  Row(
                    children: [
                      Expanded(child: _buildNewPwField()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildConfirmPwField()),
                    ],
                  )
                else ...[
                  _buildNewPwField(),
                  const SizedBox(height: 10),
                  _buildConfirmPwField(),
                ],
                const SizedBox(height: 10),
                PasswordRequirementsChecklist(
                  currentPassword: _curPwCtrl.text,
                  newPassword: _newPwCtrl.text,
                  confirmPassword: _confPwCtrl.text,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: isCompact ? double.infinity : null,
                  child: Align(
                    alignment: isCompact
                        ? Alignment.center
                        : Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed:
                          widget.isPasswordBusy ? null : _handlePasswordSubmit,
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            Size(isCompact ? double.infinity : 180, 44),
                      ),
                      icon: const Icon(Icons.key_outlined, size: 17),
                      label: Text(widget.isPasswordBusy
                          ? 'Updating...'
                          : 'Update Password'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewPwField() {
    return TextField(
      controller: _newPwCtrl,
      obscureText: _obscureNew,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'New Password',
        prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureNew
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
          ),
          onPressed: () => setState(() => _obscureNew = !_obscureNew),
        ),
      ),
    );
  }

  Widget _buildConfirmPwField() {
    return TextField(
      controller: _confPwCtrl,
      obscureText: _obscureConf,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: 'Confirm New Password',
        prefixIcon: const Icon(Icons.verified_outlined, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConf
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
          ),
          onPressed: () => setState(() => _obscureConf = !_obscureConf),
        ),
      ),
    );
  }
}
