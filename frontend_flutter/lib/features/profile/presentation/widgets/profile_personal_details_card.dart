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
    final isMobile = MediaQuery.sizeOf(context).width < 640;

    return IcareCard(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.brandSoftBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.brandSoftBorder),
                  ),
                  child: Icon(
                    Icons.badge_outlined,
                    size: 18,
                    color: tokens.brandSoftText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Details & Contact Directory',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep your phone, email, and desk bio current across devices.',
                        softWrap: true,
                        style: TextStyle(fontSize: 12, color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
                if (hasUnsavedChanges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            const SizedBox(height: 16),

            // Institutional Read-Only Identity Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: tokens.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Official Account Identity (Administered by Management)',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tokens.textMuted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCol = constraints.maxWidth >= 500;
                      final fields = [
                        _LockedField(
                          label: 'Official Full Name',
                          value: user.fullName.isNotEmpty ? user.fullName : user.username,
                        ),
                        _LockedField(
                          label: 'Staff Username',
                          value: '@${user.username}',
                        ),
                        _LockedField(
                          label: 'Assigned Role',
                          value: user.role,
                        ),
                        _LockedField(
                          label: 'Primary Branch',
                          value: user.branch.isNotEmpty ? user.branch : 'Head Office',
                        ),
                      ];

                      if (!twoCol) {
                        return Column(
                          children: fields
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: f,
                                  ))
                              .toList(),
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: 12),
                              Expanded(child: fields[1]),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: fields[2]),
                              const SizedBox(width: 12),
                              Expanded(child: fields[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Editable Contact & Personal Bio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = constraints.maxWidth >= 520;
                final phoneField = TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. +234 801 234 5678',
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
                    hintText: 'e.g. staff.name@icare.ng',
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

                if (!twoCol) {
                  return Column(
                    children: [
                      phoneField,
                      const SizedBox(height: 12),
                      emailField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: phoneField),
                    const SizedBox(width: 12),
                    Expanded(child: emailField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: emergencyController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact',
                hintText: 'Next of kin name and phone number',
                prefixIcon: Icon(Icons.contact_emergency_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: bioController,
              maxLines: 3,
              maxLength: 280,
              decoration: const InputDecoration(
                labelText: 'Personal Bio & Desk Note',
                hintText: 'Brief bio, territory note, or operational handover summary',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.notes_outlined, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 44),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 17),
                label: Text(isSaving ? 'Saving Profile...' : 'Save Personal Details'),
              ),
            ),
          ],
        ),
      ),
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
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          softWrap: true,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tokens.textPrimary,
          ),
        ),
      ],
    );
  }
}
