import 'package:flutter/material.dart';
import '../theme/icare_theme_tokens.dart';

/// Standard governance widget to declare a missing backend HTTP API contract
/// per MIGRATION_AUTHORITY.md and ZERO_REDESIGN_CONSTITUTION.md.
/// Prevents creating fake responses, mock arrays, or fabricated client-side calculations.
class MissingApiContractBanner extends StatelessWidget {
  final String pageTitle;
  final String requiredEndpoint;
  final String httpMethod;
  final String pythonService;
  final String targetTables;
  final String rbacRequirement;
  final String payloadSummary;

  const MissingApiContractBanner({
    super.key,
    required this.pageTitle,
    required this.requiredEndpoint,
    required this.httpMethod,
    required this.pythonService,
    required this.targetTables,
    required this.rbacRequirement,
    required this.payloadSummary,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = IcareSurfaceTokens.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.warningBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.warningBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tokens.warningDot,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'MISSING API CONTRACT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pageTitle — Backend HTTP Endpoint Required',
                  style: TextStyle(fontWeight: FontWeight.w700, color: tokens.warningText, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The Streamlit implementation executes this workflow directly against Python domain services and Supabase repositories. No mock or hardcoded data is permitted in Flutter. To activate live data, implement the following backend API contract:',
            style: TextStyle(fontSize: 12, color: tokens.warningText),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tokens.warningBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow(tokens, 'Required Endpoint:', '$httpMethod $requiredEndpoint'),
                _buildRow(tokens, 'Streamlit Service:', pythonService),
                _buildRow(tokens, 'Database Tables:', targetTables),
                _buildRow(tokens, 'RBAC Scope:', rbacRequirement),
                _buildRow(tokens, 'Contract Payload:', payloadSummary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(IcareSurfaceTokens tokens, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: tokens.warningText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: tokens.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
