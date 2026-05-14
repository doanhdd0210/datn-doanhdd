import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/subscription_plan.dart';
import '../../models/user_subscription.dart';
import '../../providers/ai_usage_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';

class VipSubscriptionScreen extends StatefulWidget {
  const VipSubscriptionScreen({super.key});

  @override
  State<VipSubscriptionScreen> createState() => _VipSubscriptionScreenState();
}

class _VipSubscriptionScreenState extends State<VipSubscriptionScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // Dữ liệu từ BE
  SubscriptionPlansConfig? _config;
  bool _loadingConfig = true;

  // Dữ liệu từ Google Play
  List<ProductDetails> _playProducts = [];
  bool _iapAvailable = false;

  String? _purchasingId;
  bool _verifying = false;
  // Dùng cho upgrade flow: sản phẩm mới đang chờ upgrade
  ProductDetails? _pendingUpgradeProduct;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    // Load song song: config từ BE + IAP availability
    await Future.wait([
      _loadConfig(),
      _initIap(),
    ]);
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiService().getSubscriptionPlans();
      if (data != null && mounted) {
        setState(() {
          _config = SubscriptionPlansConfig.fromJson(data);
          _loadingConfig = false;
        });
        // Sau khi có product IDs từ BE, query Google Play
        _queryPlayProducts();
      } else {
        if (mounted) setState(() => _loadingConfig = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConfig = false);
    }
  }

  Future<void> _initIap() async {
    _iapAvailable = await _iap.isAvailable();
    if (!_iapAvailable) return;

    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => _showError('Lỗi IAP: $e'),
    );
  }

  Future<void> _queryPlayProducts() async {
    if (!_iapAvailable || _config == null) return;

    final productIds = _config!.plans
        .map((p) => p.productId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (productIds.isEmpty) return;

    final resp = await _iap.queryProductDetails(productIds);
    if (mounted) {
      setState(() => _playProducts = resp.productDetails);
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        setState(() { _purchasingId = null; _pendingUpgradeProduct = null; });
        _showError(purchase.error?.message ?? 'Thanh toán thất bại');
        await _iap.completePurchase(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        setState(() { _purchasingId = null; _pendingUpgradeProduct = null; });
        await _iap.completePurchase(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.restored) {
        // Nếu đang trong upgrade flow → dùng purchase cũ này làm oldPurchaseDetails
        if (_pendingUpgradeProduct != null &&
            Platform.isAndroid &&
            purchase is GooglePlayPurchaseDetails) {
          final newProduct = _pendingUpgradeProduct!;
          setState(() => _pendingUpgradeProduct = null);
          await _iap.completePurchase(purchase); // acknowledge purchase cũ
          if (newProduct is GooglePlayProductDetails) {
            final param = GooglePlayPurchaseParam(
              productDetails: newProduct,
              offerToken: newProduct.offerToken,
              changeSubscriptionParam: ChangeSubscriptionParam(
                oldPurchaseDetails: purchase,
              ),
            );
            await _iap.buyNonConsumable(purchaseParam: param);
          }
          return; // Chờ purchased event từ Google Play
        }
        // Restore thường — không cần xác minh lại
        await _iap.completePurchase(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased) {
        await _verifyWithBackend(purchase);
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    setState(() => _verifying = true);
    try {
      final token = purchase.verificationData.serverVerificationData;
      final data = await ApiService().verifySubscription(
        purchaseToken: token,
        productId: purchase.productID,
        orderId: purchase.purchaseID ?? '',
        productType: 'subscription',
      );

      final inner = data['data'];
      if (inner != null) {
        final sub = UserSubscription.fromJson(inner as Map<String, dynamic>);
        if (mounted) {
          context.read<SubscriptionProvider>().setSubscription(sub);
          context.read<AiUsageProvider>().load();
          AppSnackBar.success(context, '🎉 Kích hoạt VIP thành công!');
        }
      }
    } catch (e) {
      _showError('Không thể xác minh giao dịch: $e');
    } finally {
      if (mounted)
        setState(() {
          _verifying = false;
          _purchasingId = null;
        });
    }
  }

  Future<void> _buy(ProductDetails product) async {
    if (_purchasingId != null || _verifying) return;
    setState(() => _purchasingId = product.id);

    PurchaseParam param;
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
    } else {
      param = PurchaseParam(productDetails: product);
    }

    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Upgrade/downgrade giữa các gói dùng ChangeSubscriptionParam (prorate).
  /// restorePurchases() lấy old purchase từ Google Play, stream handler sẽ
  /// dùng nó làm oldPurchaseDetails rồi trigger mua gói mới.
  Future<void> _upgrade(ProductDetails newProduct) async {
    if (_purchasingId != null || _verifying) return;
    setState(() {
      _purchasingId = newProduct.id;
      _pendingUpgradeProduct = newProduct;
    });
    await _iap.restorePurchases();
  }

  Future<void> _cancelSubscription() async {
    final sub = context.read<SubscriptionProvider>().subscription;
    if (sub == null) return;

    final packageName = _config?.packageName ?? 'doanhdd.javaup.mobile';
    final url = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?sku=${sub.productId}&package=$packageName',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showError(String msg) {
    if (mounted) AppSnackBar.error(context, msg);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Nâng cấp VIP', style: AppTextStyles.heading3),
      ),
      body: _verifying
          ? _buildVerifying()
          : _loadingConfig
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      // _buildCurrentStatus(),
                      // const SizedBox(height: 20),
                      _buildPlans(),
                      const SizedBox(height: 24),
                      _buildFeatureList(),
                      const SizedBox(height: 16),
                      _buildFooter(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVerifying() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Đang xác minh giao dịch...'),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 42),
        ),
        const SizedBox(height: 16),
        Text('Mở khoá toàn bộ tính năng AI',
            style: AppTextStyles.heading2.copyWith(fontSize: 20),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Tăng giới hạn AI và học hiệu quả hơn',
            style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildCurrentStatus() {
    final sub = context.watch<SubscriptionProvider>().subscription;
    if (sub == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            sub.isTrial
                ? Icons.hourglass_top_rounded
                : Icons.check_circle_rounded,
            color: sub.isTrial ? Colors.orange : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.isTrial
                      ? 'Đang dùng thử gói ${sub.isMax ? "Max 👑" : "Standard ⭐"}'
                      : 'Bạn đang dùng gói ${sub.isMax ? "Max 👑" : "Standard ⭐"}',
                  style: AppTextStyles.labelBold,
                ),
                if (sub.expiresAt != null)
                  Text(
                    sub.isTrial
                        ? 'Dùng thử đến: ${_formatDate(sub.expiresAt!)}'
                        : 'Hết hạn: ${_formatDate(sub.expiresAt!)}',
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlans() {
    if (_config == null || _config!.plans.isEmpty) {
      return _buildConfigNote(
          'Chưa cấu hình gói VIP.\nAdmin cần thiết lập trên trang quản trị.');
    }

    return Column(
      children: [
        for (int i = 0; i < _config!.plans.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          _buildPlanCard(_config!.plans[i]),
        ],
      ],
    );
  }

  Widget _buildConfigNote(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: Colors.orange.shade800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isMax = plan.id == 'max';
    final color = isMax ? const Color(0xFFFFC107) : AppColors.secondary;

    final playProduct =
        _playProducts.where((p) => p.id == plan.productId).firstOrNull;
    final priceText = playProduct?.price ??
        (plan.displayPrice.isNotEmpty
            ? plan.displayPrice
            : (plan.productId.isEmpty ? 'Chưa cấu hình' : '---'));

    final currentSub = context.watch<SubscriptionProvider>().subscription;
    final hasActiveSub = currentSub != null && currentSub.isActive;
    final isCurrent = currentSub?.productId == plan.productId && hasActiveSub;
    final isOtherPlan = hasActiveSub && !isCurrent; // có sub nhưng là gói khác
    final isPurchasing = _purchasingId == plan.productId;
    // Mua mới (chưa có sub)
    final canBuy = playProduct != null && _iapAvailable && !hasActiveSub && !isPurchasing && !_verifying;
    // Upgrade/downgrade sang gói khác (đã có sub, không phải gói hiện tại)
    final canUpgrade = playProduct != null && _iapAvailable && isOtherPlan && !isPurchasing && !_verifying;
    // Play Store loaded but product missing — show informative note
    final playLoadedButMissing = _iapAvailable &&
        _playProducts.isNotEmpty &&
        plan.productId.isNotEmpty &&
        playProduct == null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !isCurrent
                  ? context.borderColor
                  : color.withValues(alpha: 0.6),
              width: isMax ? 2 : 1,
            ),
            boxShadow: isCurrent && isMax
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2)
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.icon, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(plan.title,
                              style: AppTextStyles.heading3
                                  .copyWith(color: color)),
                        ],
                      ),
                      if (plan.trialDays > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF16A34A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Thử miễn phí ${plan.trialDays} ngày',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(priceText,
                          style: AppTextStyles.heading3
                              .copyWith(color: color, fontSize: 18)),
                      Text('/ tháng',
                          style:
                              AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 15, color: color),
                        const SizedBox(width: 8),
                        Text(f,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontSize: 13)),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              if (playLoadedButMissing) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sản phẩm chưa có trên Google Play Console',
                          style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canBuy
                        ? () => _buy(playProduct!)
                        : canUpgrade
                            ? () => _upgrade(playProduct!)
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCurrent
                          ? Colors.grey.shade800
                          : color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: isCurrent
                          ? Colors.grey.shade800
                          : color.withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            isCurrent
                                ? '✓ Đang sử dụng'
                                : isOtherPlan
                                    ? (isMax ? '👑 Nâng cấp lên Max' : '⭐ Chuyển xuống Standard')
                                    : 'Đăng ký ngay',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _cancelSubscription,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Huỷ đăng ký',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (isMax)
          Positioned(
            top: -10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('PHỔ BIẾN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _buildFeatureList() {
    final items = [
      (Icons.smart_toy_rounded, 'AI giải thích code', 'Hiểu lỗi nhanh hơn'),
      (Icons.lightbulb_rounded, 'Gợi ý quiz thông minh', 'Học hiệu quả hơn'),
      (Icons.forum_rounded, 'Trợ lý QA cộng đồng', 'Câu trả lời tức thì'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tính năng VIP', style: AppTextStyles.labelBold),
          const SizedBox(height: 14),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.$1, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2,
                            style:
                                AppTextStyles.labelBold.copyWith(fontSize: 13)),
                        Text(item.$3, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'Thanh toán qua Google Play. Có thể huỷ bất cứ lúc nào trong Google Play > Đăng ký.',
      style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
      textAlign: TextAlign.center,
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
