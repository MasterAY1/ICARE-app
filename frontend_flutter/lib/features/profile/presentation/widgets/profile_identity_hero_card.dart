import 'package:flutter/material.dart';
import '../../../../core/auth/auth_state.dart';
import '../../../../core/theme/icare_theme_tokens.dart';
import '../../../shared/presentation/widgets/user_avatar_circle.dart';

class ProfileIdentityHeroCard extends StatelessWidget {
  final AuthUser user;
  final bool isUploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onRemoveAvatar;
  final bool isOnline;

  const ProfileIdentityHeroCard({
    super.key,
    required this.user,
    required this.isUploadingAvatar,
    required this.onPickAvatar,
    required this.onRemoveAvatar,
    required this.isOnline,
  });

  String _formatDateLabel(String? iso) {
    if (iso == null || iso.trim().isEmpty || iso == 'None' || iso == 'Never') {
      return 'Not recorded';
    }
    final clean = iso.trim();
    if (clean.length >= 10) {
      return clean.substring(0, 10);
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    final hasAvatar = user.avatarUrl.trim().isNotEmpty;

    final heroAvatar = Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatarCircle(
          fullName: user.fullName.isNotEmpty ? user.fullName : user.username,
          avatarUrl: user.avatarUrl,
          size: isMobile ? 84 : 96,
          backgroundColor: Colors.white.withValues(alpha: 0.16),
          borderColor: tokens.brandAccent,
          borderWidth: 2.5,
          isUploading: isUploadingAvatar,
          showOnlineDot: true,
          isOnline: isOnline,
          onTap: isUploadingAvatar ? null : onPickAvatar,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Semantics(
            button: true,
            label: 'Change profile picture',
            child: Material(
              color: tokens.surface,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: isUploadingAvatar ? null : onPickAvatar,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 16,
                    color: tokens.brandPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final identityDetails = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              user.fullName.isNotEmpty ? user.fullName : user.username,
              textAlign: isMobile ? TextAlign.center : TextAlign.start,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                user.role,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (user.mfaEnabled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 12, color: Color(0xFFA7F3D0)),
                    SizedBox(width: 4),
                    Text(
                      '2FA Active',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '@${user.username}  |  ${user.branch.isNotEmpty ? user.branch : "Head Office"}',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (user.bio.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            user.bio.trim(),
            textAlign: isMobile ? TextAlign.center : TextAlign.start,
            softWrap: true,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeroMetaPill(
              icon: Icons.calendar_today_outlined,
              label: 'Member Since: ${_formatDateLabel(user.createdAt)}',
            ),
            _HeroMetaPill(
              icon: Icons.login_outlined,
              label: 'Last Sign-In: ${_formatDateLabel(user.lastLogin)}',
            ),
            if (user.isMiscSavingsManager)
              const _HeroMetaPill(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Designated Misc Manager',
              ),
          ],
        ),
      ],
    );

    final photoActions = Wrap(
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: isUploadingAvatar ? null : onPickAvatar,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF064E3B),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.upload_outlined, size: 16),
          label: Text(hasAvatar ? 'Change Photo' : 'Upload Photo'),
        ),
        if (hasAvatar)
          OutlinedButton.icon(
            onPressed: isUploadingAvatar ? null : onRemoveAvatar,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Remove'),
          ),
      ],
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.isDark
              ? [
                  tokens.brandPrimaryDark,
                  const Color(0xFF072B24),
                  const Color(0xFF0F172A),
                ]
              : [
                  tokens.brandPrimaryDark,
                  tokens.brandPrimary,
                  tokens.brandPrimaryLight,
                ],
        ),
        border: Border.all(
          color: tokens.isDark
              ? tokens.brandSoftBorder
              : tokens.brandPrimary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.brandPrimary.withValues(alpha: tokens.isDark ? 0.16 : 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Column(
                children: [
                  heroAvatar,
                  const SizedBox(height: 14),
                  identityDetails,
                  const SizedBox(height: 16),
                  photoActions,
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  heroAvatar,
                  const SizedBox(width: 20),
                  Expanded(child: identityDetails),
                  const SizedBox(width: 16),
                  photoActions,
                ],
              ),
            if (user.assignedBranches.isNotEmpty ||
                user.allowedProducts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
              const SizedBox(height: 12),
              if (user.assignedBranches.isNotEmpty) ...[
                Text(
                  'SUPERVISED BRANCHES (${user.assignedBranches.length})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.assignedBranches
                      .map((b) => _HeroScopeChip(label: b))
                      .toList(),
                ),
                if (user.allowedProducts.isNotEmpty) const SizedBox(height: 10),
              ],
              if (user.allowedProducts.isNotEmpty) ...[
                Text(
                  'ASSIGNED LOAN PRODUCTS (${user.allowedProducts.length})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: user.allowedProducts
                      .map((p) => _HeroScopeChip(label: p))
                      .toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroScopeChip extends StatelessWidget {
  final String label;

  const _HeroScopeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
