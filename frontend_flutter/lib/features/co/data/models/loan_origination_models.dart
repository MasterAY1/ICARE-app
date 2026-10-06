class ClientRegistrationPayload {
  final String name;
  final String? nickname;
  final String phone;
  final String? address;
  final String? maritalStatus;
  final String? businessType;
  final double averageMonthlyIncome;
  final String? businessAddress;
  final String? otherObligations;
  final String? idMeans;
  final String? idNumber;
  final String? groupId;
  final String? newGroupName;
  final String? newGroupNumber;
  final String? newGroupMeetingDay;
  final String? guarantorName;
  final String? guarantorPhone;
  final String? guarantorAddress;
  final String? guarantorRelationship;
  final String? guarantorOccupation;

  ClientRegistrationPayload({
    required this.name,
    this.nickname,
    required this.phone,
    this.address,
    this.maritalStatus,
    this.businessType,
    this.averageMonthlyIncome = 0.0,
    this.businessAddress,
    this.otherObligations,
    this.idMeans,
    this.idNumber,
    this.groupId,
    this.newGroupName,
    this.newGroupNumber,
    this.newGroupMeetingDay,
    this.guarantorName,
    this.guarantorPhone,
    this.guarantorAddress,
    this.guarantorRelationship,
    this.guarantorOccupation,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'nickname': nickname,
        'phone': phone,
        'address': address,
        'marital_status': maritalStatus,
        'business_type': businessType,
        'average_monthly_income': averageMonthlyIncome,
        'business_address': businessAddress,
        'other_obligations': otherObligations,
        'id_means': idMeans,
        'id_number': idNumber,
        'group_id': groupId,
        'new_group_name': newGroupName,
        'new_group_number': newGroupNumber,
        'new_group_meeting_day': newGroupMeetingDay,
        'guarantor_name': guarantorName,
        'guarantor_phone': guarantorPhone,
        'guarantor_address': guarantorAddress,
        'guarantor_relationship': guarantorRelationship,
        'guarantor_occupation': guarantorOccupation,
      };
}

class LoanProductSetup {
  final double principal;
  final double interestRate;
  final double totalInterest;
  final double totalPayable;
  final double installmentAmount;
  final int duration;
  final String frequency;
  final double adminFee;
  final double insuranceFee;
  final double legalFee;
  final double passbookFee;
  final double netDisbursement;

  LoanProductSetup({
    required this.principal,
    required this.interestRate,
    required this.totalInterest,
    required this.totalPayable,
    required this.installmentAmount,
    required this.duration,
    required this.frequency,
    required this.adminFee,
    required this.insuranceFee,
    required this.legalFee,
    required this.passbookFee,
    required this.netDisbursement,
  });

  factory LoanProductSetup.fromJson(Map<String, dynamic> json) {
    return LoanProductSetup(
      principal: (json['principal'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      totalInterest: (json['total_interest'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['total_payable'] as num?)?.toDouble() ?? 0.0,
      installmentAmount: (json['installment_amount'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 60,
      frequency: json['frequency']?.toString() ?? 'Daily',
      adminFee: (json['admin_fee'] as num?)?.toDouble() ?? 0.0,
      insuranceFee: (json['insurance_fee'] as num?)?.toDouble() ?? 0.0,
      legalFee: (json['legal_fee'] as num?)?.toDouble() ?? 0.0,
      passbookFee: (json['passbook_fee'] as num?)?.toDouble() ?? 0.0,
      netDisbursement: (json['net_disbursement'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
