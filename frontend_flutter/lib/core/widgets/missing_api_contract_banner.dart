import 'package:flutter/material.dart';

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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF92400E), fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'The Streamlit implementation executes this workflow directly against Python domain services and Supabase repositories. No mock or hardcoded data is permitted in Flutter. To activate live data, implement the following backend API contract:',
            style: TextStyle(fontSize: 12, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRow('Required Endpoint:', '$httpMethod $requiredEndpoint'),
                _buildRow('Streamlit Service:', pythonService),
                _buildRow('Database Tables:', targetTables),
                _buildRow('RBAC Scope:', rbacRequirement),
                _buildRow('Contract Payload:', payloadSummary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF451A03)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
