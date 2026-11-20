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
      return '—';
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
    final hasAvatar = user.avatarUrl.trim().isNotEmpty;
    final displayName =
        user.fullName.isNotEmpty ? user.fullName : user.username;
    final branchLabel = user.branch.isNotEmpty ? user.branch : 'Head Office';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 580;
        final avatarSize = isCompact ? 62.0 : 80.0;

        final heroAvatar = Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatarCircle(
              fullName: displayName,
              avatarUrl: user.avatarUrl,
              size: avatarSize,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              borderColor: tokens.brandAccent,
              borderWidth: 2,
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
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.borderSubtle),
                      ),
                      child: Icon(
                        Icons.photo_camera_outlined,
                        size: 14,
                        color: tokens.brandPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        final badges = Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (user.mfaEnabled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF065F46).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 11, color: Color(0xFFA7F3D0)),
                    SizedBox(width: 4),
                    Text(
                      '2FA Active',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (user.isMiscSavingsManager)
              const _HeroMetaPill(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Designated Misc Manager',
              ),
          ],
        );

        final photoActions = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: isUploadingAvatar ? null : onPickAvatar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF064E3B),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.upload_outlined, size: 15),
                label: Text(
                  hasAvatar ? 'Change Photo' : 'Upload Photo',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            if (hasAvatar)
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: isUploadingAvatar ? null : onRemoveAvatar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text(
                    'Remove',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        );

        final metaChips = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _HeroMetaPill(
              icon: Icons.calendar_today_outlined,
              label: 'Joined ${_formatDateLabel(user.createdAt)}',
            ),
            _HeroMetaPill(
              icon: Icons.login_outlined,
              label: 'Last active ${_formatDateLabel(user.lastLogin)}',
            ),
          ],
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 14 : 20),
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
                color: tokens.brandPrimary
                    .withValues(alpha: tokens.isDark ? 0.14 : 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  heroAvatar,
                  SizedBox(width: isCompact ? 12 : 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          softWrap: true,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 17 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user.username}  ·  $branchLabel',
                          softWrap: true,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        badges,
                        if (!isCompact) ...[
                          if (user.bio.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              user.bio.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          metaChips,
                        ],
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 12),
                    photoActions,
                  ],
                ],
              ),
              if (isCompact) ...[
                if (user.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.bio.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Divider(
                    color: Colors.white.withValues(alpha: 0.14), height: 1),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    photoActions,
                    metaChips,
                  ],
                ),
              ],
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
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
