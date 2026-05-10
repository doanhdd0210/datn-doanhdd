class SubscriptionPlan {
  final String id; // "standard" | "max"
  final String productId; // Google Play product ID
  final String title;
  final String icon;
  final String displayPrice; // e.g. "29.000đ / tháng"
  final int? dailyAiLimit; // null = unlimited
  final bool isUnlimited;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.productId,
    required this.title,
    required this.icon,
    required this.displayPrice,
    this.dailyAiLimit,
    required this.isUnlimited,
    required this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      displayPrice: json['displayPrice'] as String? ?? '',
      dailyAiLimit: json['dailyAiLimit'] as int?,
      isUnlimited: json['isUnlimited'] as bool? ?? false,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class SubscriptionPlansConfig {
  final String packageName;
  final List<SubscriptionPlan> plans;

  const SubscriptionPlansConfig({
    required this.packageName,
    required this.plans,
  });

  factory SubscriptionPlansConfig.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlansConfig(
      packageName: json['packageName'] as String? ?? '',
      plans: (json['plans'] as List<dynamic>?)
              ?.map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
