class UserSubscription {
  final String userId;
  final String planType; // "standard" | "max"
  final String productId;
  final bool isActive;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final int? dailyAiLimit; // null = unlimited

  const UserSubscription({
    required this.userId,
    required this.planType,
    required this.productId,
    required this.isActive,
    required this.purchasedAt,
    this.expiresAt,
    this.dailyAiLimit,
  });

  bool get isMax => planType == 'max';
  bool get isStandard => planType == 'standard';
  bool get isUnlimited => dailyAiLimit == null;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['userId'] as String? ?? '',
      planType: json['planType'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      dailyAiLimit: json['dailyAiLimit'] as int?,
    );
  }
}
