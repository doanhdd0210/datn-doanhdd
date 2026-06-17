import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../constants/app_theme.dart';
import '../../models/subscription_plan.dart';
import '../../providers/ai_usage_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import 'subscription_success_screen.dart';

class VipSubscriptionScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const VipSubscriptionScreen({super.key, this.onSuccess});

  @override
  State<VipSubscriptionScreen> createState() => _VipSubscriptionScreenState();
}

class _VipSubscriptionScreenState extends State<VipSubscriptionScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  SubscriptionPlansConfig? _config;
  bool _loadingConfig = true;

  List<ProductDetails> _playProducts = [];
  bool _iapAvailable = false;

  String? _selectedPlanId;
  String? _purchasingId;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await Future.wait([_loadConfig(), _initIap()]);
  }

  Future<void> _loadConfig() async {
    try {
      final data = await ApiService().getSubscriptionPlans();
      if (data != null && mounted) {
        setState(() {
          _config = SubscriptionPlansConfig.fromJson(data);
          _loadingConfig = false;
          // Pre-select plan "max"; fallback về plan đầu tiên nếu không có
          _selectedPlanId = _config!.plans
              .firstWhere(
                (p) => p.id == 'max',
                orElse: () => _config!.plans.first,
              )
              .id;
        });
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
    _purchaseSub = _iap.purchaseStream.listen(_onPurchaseUpdate,
        onError: (e) => _showError('Lỗi IAP: $e'));
  }

  Future<void> _queryPlayProducts() async {
    if (!_iapAvailable || _config == null) return;
    final ids = _config!.plans
        .map((p) => p.productId)
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    final resp = await _iap.queryProductDetails(ids);
    if (mounted) setState(() => _playProducts = resp.productDetails);
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        setState(() => _purchasingId = null);
        _showError(purchase.error?.message ?? 'Thanh toán thất bại');
        await _iap.completePurchase(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.canceled) {
        setState(() => _purchasingId = null);
        await _iap.completePurchase(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased) {
        await _verifyWithBackend(purchase);
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.restored) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    setState(() => _verifying = true);
    final subProvider = context.read<SubscriptionProvider>();
    final aiProvider = context.read<AiUsageProvider>();
    try {
      final token = purchase.verificationData.serverVerificationData;
      await ApiService().verifySubscription(
        purchaseToken: token,
        productId: purchase.productID,
        orderId: purchase.purchaseID ?? '',
        productType: 'subscription',
      );

      if (!mounted) return;
      await subProvider.load();
      await aiProvider.load();

      if (!mounted) return;
      if (subProvider.isPremium) {
        final selectedPlan = _config?.plans.firstWhere(
          (p) => p.productId == purchase.productID,
          orElse: () => _config!.plans.first,
        );
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionSuccessScreen(
              planName: selectedPlan?.title ?? 'VIP',
              planIcon: selectedPlan?.icon ?? '👑',
              expiresAt: subProvider.subscription?.expiresAt,
              isTrial: subProvider.subscription?.isTrial ?? false,
              onDone: widget.onSuccess,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Không thể xác minh giao dịch. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() {
        _verifying = false;
        _purchasingId = null;
      });
    }
  }

  Future<void> _buySelected() async {
    if (_selectedPlanId == null || _purchasingId != null || _verifying) return;

    final plan = _config?.plans.firstWhere((p) => p.id == _selectedPlanId);
    if (plan == null) return;

    final product =
        _playProducts.where((p) => p.id == plan.productId).firstOrNull;
    if (product == null) return;

    setState(() => _purchasingId = product.id);

    PurchaseParam param;
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(
          productDetails: product, offerToken: product.offerToken);
    } else {
      param = PurchaseParam(productDetails: product);
    }

    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void _showError(String msg) {
    if (mounted) AppSnackBar.error(context, msg);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  SubscriptionPlan? get _selectedPlan =>
      _config?.plans.firstWhere((p) => p.id == _selectedPlanId,
          orElse: () => _config!.plans.first);

  ProductDetails? _productFor(SubscriptionPlan plan) =>
      _playProducts.where((p) => p.id == plan.productId).firstOrNull;

  String _priceFor(SubscriptionPlan plan) {
    final product = _productFor(plan);

    // Ưu tiên lấy giá recurring (sau trial) từ subscriptionOfferDetails
    // vì product.price có thể trả về "Free" khi sub có free trial
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null && offers.isNotEmpty) {
        final phases = offers.first.pricingPhases;
        if (phases.isNotEmpty) {
          // Phase cuối = giá recurring thực (sau khi hết trial/intro)
          final recurringPhase = phases.lastWhere(
            (p) => p.priceAmountMicros > 0,
            orElse: () => phases.last,
          );
          final formatted = recurringPhase.formattedPrice;
          if (formatted.isNotEmpty) return formatted;
        }
      }
    }

    // Fallback: lọc "Free" / "$0" từ IAP rồi về displayPrice từ admin config
    final iapPrice = product?.price;
    final iapPriceIsReal = iapPrice != null &&
        iapPrice.isNotEmpty &&
        !iapPrice.toLowerCase().contains('free') &&
        iapPrice != r'$0.00' &&
        iapPrice != '0';
    if (iapPriceIsReal) return iapPrice!;
    return plan.displayPrice.isNotEmpty ? plan.displayPrice : '---';
  }

  Color _colorFor(SubscriptionPlan plan) =>
      plan.id == 'max' ? const Color(0xFFFFC107) : AppColors.secondary;

  /// Kiểm tra xem user có đủ điều kiện dùng thử miễn phí không.
  /// Ưu tiên lấy từ Google Play offer thực tế (tránh show "free" với user đã dùng trial).
  /// Fallback về config trialDays khi chưa load được product từ Play Store.
  bool _hasTrial(SubscriptionPlan plan) {
    final product = _productFor(plan);
    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers != null && offers.isNotEmpty) {
        final phases = offers.first.pricingPhases;
        if (phases.isNotEmpty) {
          // Free trial = phase đầu tiên có giá 0
          return phases.first.priceAmountMicros == 0;
        }
      }
      return false; // product load được nhưng không có trial offer
    }
    // Product chưa load từ Play Store → fallback config
    return plan.trialDays > 0;
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_verifying) return _buildVerifying();

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(),
            // Nút X close overlay góc trên trái
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: Icon(Icons.close_rounded, color: context.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingConfig) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final sub = context.watch<SubscriptionProvider>().subscription;
    final hasActiveSub = sub != null && sub.isActive;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (hasActiveSub) ...[
                  _buildActiveSubBanner(sub),
                  const SizedBox(height: 20),
                ],
                if (_config == null || _config!.plans.isEmpty)
                  _buildConfigNote(
                      'Chưa cấu hình gói VIP.\nAdmin cần thiết lập trên trang quản trị.')
                else ...[
                  _buildPlanSelector(hasActiveSub),
                  const SizedBox(height: 20),
                  if (!hasActiveSub && _selectedPlan != null && _hasTrial(_selectedPlan!)) _buildTrialCallout(),
                ],
                const SizedBox(height: 24),
                _buildFeatureList(),
              ],
            ),
          ),
        ),
        if (!hasActiveSub) _buildBottomCta(),
      ],
    );
  }

  Widget _buildVerifying() {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Đang xác minh giao dịch...'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
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
              color: Colors.white, size: 38),
        ),
        const SizedBox(height: 14),
        Text('Mở khoá toàn bộ tính năng AI',
            style: AppTextStyles.heading2.copyWith(fontSize: 20),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Tăng giới hạn AI và học hiệu quả hơn',
            style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildActiveSubBanner(sub) {
    final s = sub as dynamic;
    final isExpiring = s.isExpiring as bool;
    final expiresAt = s.expiresAt as DateTime?;
    final isTrial = s.isTrial as bool;
    final isMax = s.isMax as bool;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            isExpiring
                ? Icons.warning_amber_rounded
                : isTrial
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_rounded,
            color: isExpiring
                ? Colors.orange
                : isTrial
                    ? Colors.orange
                    : AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTrial
                      ? 'Đang dùng thử gói ${isMax ? "Max 👑" : "Standard ⭐"}'
                      : 'Bạn đang dùng gói ${isMax ? "Max 👑" : "Standard ⭐"}',
                  style: AppTextStyles.labelBold,
                ),
                if (expiresAt != null)
                  Text(
                    isExpiring
                        ? 'Hết hạn ${_formatDate(expiresAt)} · Sẽ không gia hạn'
                        : isTrial
                            ? 'Dùng thử đến ${_formatDate(expiresAt)}'
                            : 'Tự động gia hạn ${_formatDate(expiresAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isExpiring ? Colors.orange.shade700 : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(bool hasActiveSub) {
    return Column(
      children: [
        for (int i = 0; i < _config!.plans.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildPlanCard(_config!.plans[i], hasActiveSub),
        ],
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, bool hasActiveSub) {
    final isSelected = !hasActiveSub && _selectedPlanId == plan.id;
    final color = _colorFor(plan);
    final priceText = _priceFor(plan);
    final sub = context.watch<SubscriptionProvider>().subscription;
    final isCurrent = sub != null && sub.isActive && sub.productId == plan.productId;
    final highlight = isSelected || isCurrent;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: hasActiveSub ? null : () => setState(() => _selectedPlanId = plan.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? color
                    : isSelected
                        ? color
                        : context.borderColor,
                width: highlight ? 2 : 1,
              ),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: 0.12),
                          blurRadius: 12,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: highlight ? color : context.borderColor,
                      width: 2,
                    ),
                    color: highlight ? color : Colors.transparent,
                  ),
                  child: highlight
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                // Plan info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.icon, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(plan.title,
                              style: AppTextStyles.labelBold
                                  .copyWith(color: color)),
                          if (_hasTrial(plan)) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${plan.trialDays} ngày miễn phí',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.features.take(2).join(' · '),
                        style: AppTextStyles.bodySmall
                            .copyWith(fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _playProducts.isEmpty && _iapAvailable
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : Text(priceText,
                            style: AppTextStyles.labelBold
                                .copyWith(color: color, fontSize: 15)),
                    Text('/tháng',
                        style:
                            AppTextStyles.bodySmall.copyWith(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (plan.id == 'max')
          Positioned(
            top: -9,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('PHỔ BIẾN',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5)),
            ),
          ),
      ],
    );
  }

  Widget _buildTrialCallout() {
    final plan = _selectedPlan;
    if (plan == null || plan.trialDays <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF16A34A).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF15803D)),
          const SizedBox(width: 6),
          Text(
            '${plan.trialDays} ngày dùng thử miễn phí với gói ${plan.title} ${plan.icon}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D)),
          ),
        ],
      ),
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
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(item.$1, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2,
                            style: AppTextStyles.labelBold
                                .copyWith(fontSize: 13)),
                        Text(item.$3,
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    final plan = _selectedPlan;
    final product = plan != null ? _productFor(plan) : null;
    final hasTrial = plan != null && _hasTrial(plan);
    final isLoading = _purchasingId != null || _verifying;
    final canBuy = product != null && _iapAvailable && !isLoading;
    final priceText = plan != null ? _priceFor(plan) : '---';
    final color = plan != null ? _colorFor(plan) : AppColors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CTA button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canBuy ? _buySelected : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      hasTrial
                          ? 'Bắt đầu dùng thử miễn phí'
                          : 'Đăng ký ${plan?.title ?? ""} — $priceText',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          if (hasTrial && plan != null) ...[
            const SizedBox(height: 6),
            Text(
              'Sau đó $priceText/tháng · Tự động gia hạn · Huỷ bất cứ lúc nào',
              style:
                  AppTextStyles.bodySmall.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
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
}
