class CoDashboardData {
  final Map<String, dynamic> welcome;
  final Map<String, dynamic> branchClosure;
  final Map<String, dynamic> repaymentSummary;
  final List<Map<String, dynamic>> meetingPortfolio;
  final Map<String, dynamic> savings;
  final Map<String, dynamic> repaymentStatus;
  final Map<String, dynamic> cashPosition;
  final List<Map<String, dynamic>> attentionList;

  CoDashboardData({
    required this.welcome,
    required this.branchClosure,
    required this.repaymentSummary,
    required this.meetingPortfolio,
    required this.savings,
    required this.repaymentStatus,
    required this.cashPosition,
    required this.attentionList,
  });

  factory CoDashboardData.fromJson(Map<String, dynamic> json) {
    return CoDashboardData(
      welcome: json['welcome'] is Map ? Map<String, dynamic>.from(json['welcome']) : {},
      branchClosure: json['branch_closure'] is Map ? Map<String, dynamic>.from(json['branch_closure']) : {},
      repaymentSummary: json['repayment_summary'] is Map ? Map<String, dynamic>.from(json['repayment_summary']) : {},
      meetingPortfolio: (json['meeting_portfolio'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      savings: json['savings'] is Map ? Map<String, dynamic>.from(json['savings']) : {},
      repaymentStatus: json['repayment_status'] is Map ? Map<String, dynamic>.from(json['repayment_status']) : {},
      cashPosition: json['cash_position'] is Map ? Map<String, dynamic>.from(json['cash_position']) : {},
      attentionList: (json['attention_list'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'welcome': welcome,
      'branch_closure': branchClosure,
      'repayment_summary': repaymentSummary,
      'meeting_portfolio': meetingPortfolio,
      'savings': savings,
      'repayment_status': repaymentStatus,
      'cash_position': cashPosition,
      'attention_list': attentionList,
    };
  }
}
