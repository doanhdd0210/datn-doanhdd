class UserSubscription {
  final String userId;
  final String planType; // "standard" | "max"
  final String productId;
  final String purchaseToken;
  final bool isActive;
  final bool isTrial;
  final bool willRenew;
  final DateTime purchasedAt;
  final DateTime? expiresAt;
  final int? dailyAiLimit; // null = unlimited

  const UserSubscription({
    required this.userId,
    required this.planType,
    required this.productId,
    this.purchaseToken = '',
    required this.isActive,
    this.isTrial = false,
    this.willRenew = true,
    required this.purchasedAt,
    this.expiresAt,
    this.dailyAiLimit,
  });

  bool get isMax => planType == 'max';
  bool get isStandard => planType == 'standard';
  bool get isUnlimited => dailyAiLimit == null;
  bool get isExpiring => !willRenew && expiresAt != null;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      userId: json['userId'] as String? ?? '',
      planType: json['planType'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      purchaseToken: json['purchaseToken'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      willRenew: json['willRenew'] as bool? ?? true,
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      dailyAiLimit: json['dailyAiLimit'] as int?,
    );
  }
}
