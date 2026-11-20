import 'package:flutter/material.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../../core/widgets/icare_card.dart';

class ProfilePersonalDetailsCard extends StatelessWidget {
  final AuthUser user;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController emergencyController;
  final TextEditingController bioController;
  final GlobalKey<FormState> formKey;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final VoidCallback onSave;

  const ProfilePersonalDetailsCard({
    super.key,
    required this.user,
    required this.phoneController,
    required this.emailController,
    required this.emergencyController,
    required this.bioController,
    required this.formKey,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 520;
        final twoColFields = constraints.maxWidth >= 460;
        final twoColIdentity = constraints.maxWidth >= 260;

        final lockedFields = [
          _LockedField(
            label: 'Full Name',
            value: user.fullName.isNotEmpty ? user.fullName : user.username,
          ),
          _LockedField(
            label: 'Username',
            value: '@${user.username}',
          ),
          _LockedField(
            label: 'Role',
            value: user.role,
          ),
          _LockedField(
            label: 'Branch',
            value: user.branch.isNotEmpty ? user.branch : 'Head Office',
          ),
        ];

        final phoneField = TextFormField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            hintText: '+234 801 234 5678',
            prefixIcon: Icon(Icons.phone_outlined, size: 18),
          ),
          validator: (val) {
            final v = (val ?? '').trim();
            if (v.isEmpty) return null;
            if (!RegExp(r'^[0-9+\-\s()]{7,25}$').hasMatch(v)) {
              return 'Enter a valid 7-25 digit phone number.';
            }
            return null;
          },
        );

        final emailField = TextFormField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'staff.name@icare.ng',
            prefixIcon: Icon(Icons.mail_outline, size: 18),
          ),
          validator: (val) {
            final v = (val ?? '').trim();
            if (v.isEmpty) return null;
            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
              return 'Enter a valid email address.';
            }
            return null;
          },
        );

        return IcareCard(
          padding: EdgeInsets.all(isCompact ? 14 : 18),
          child: Form(
            key: formKey,
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
                        Icons.badge_outlined,
                        size: 17,
                        color: tokens.brandSoftText,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Profile & Contact',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                    if (hasUnsavedChanges)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tokens.warningBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: tokens.warningBorder),
                        ),
                        child: Text(
                          'Unsaved',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.warningText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Compact 2x2 Read-Only Identity Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: twoColIdentity
                      ? Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: lockedFields[0]),
                                const SizedBox(width: 10),
                                Expanded(child: lockedFields[1]),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: lockedFields[2]),
                                const SizedBox(width: 10),
                                Expanded(child: lockedFields[3]),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: lockedFields
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: f,
                                  ))
                              .toList(),
                        ),
                ),

                const SizedBox(height: 12),

                if (twoColFields)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: phoneField),
                      const SizedBox(width: 10),
                      Expanded(child: emailField),
                    ],
                  )
                else ...[
                  phoneField,
                  const SizedBox(height: 10),
                  emailField,
                ],
                const SizedBox(height: 10),

                TextFormField(
                  controller: emergencyController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact',
                    hintText: 'Next of kin name & phone',
                    prefixIcon: Icon(Icons.contact_emergency_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 10),

                TextFormField(
                  controller: bioController,
                  maxLines: 2,
                  maxLength: 280,
                  decoration: const InputDecoration(
                    labelText: 'Personal Bio & Desk Note',
                    hintText: 'Territory or handover note',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Icon(Icons.notes_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: isCompact ? double.infinity : null,
                  child: Align(
                    alignment: isCompact
                        ? Alignment.center
                        : Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : onSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(isCompact ? double.infinity : 180, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 17),
                      label: Text(
                          isSaving ? 'Saving...' : 'Save Personal Details'),
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
}

class _LockedField extends StatelessWidget {
  final String label;
  final String value;

  const _LockedField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}
