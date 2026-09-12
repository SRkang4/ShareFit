import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/pro_purchase_service.dart';
import '../config/feature_flags.dart';
import '../widgets/sharefit_sliding_segmented_control.dart';
import '../widgets/sharefit_ui.dart';

class ProPurchaseScreen extends StatefulWidget {
  const ProPurchaseScreen({super.key, required this.currentlyPro});

  final bool currentlyPro;

  @override
  State<ProPurchaseScreen> createState() => _ProPurchaseScreenState();
}

class _ProPurchaseScreenState extends State<ProPurchaseScreen> {
  ProPurchaseService get _purchaseService => ProPurchaseService.instance;
  int _selectedIndex = 1;
  int _handledNoticeVersion = 0;

  @override
  void initState() {
    super.initState();
    if (!proSubscriptionEnabled) return;
    _purchaseService.addListener(_handleServiceUpdate);
    _handledNoticeVersion = _purchaseService.noticeVersion;
    _purchaseService.loadProducts();
  }

  @override
  void dispose() {
    if (proSubscriptionEnabled) {
      _purchaseService.removeListener(_handleServiceUpdate);
    }
    super.dispose();
  }

  void _handleServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    if (_handledNoticeVersion == _purchaseService.noticeVersion) return;
    _handledNoticeVersion = _purchaseService.noticeVersion;
    final notice = _purchaseService.notice;
    final message = switch (notice) {
      ProPurchaseNotice.purchaseSucceeded => 'ShareFit Pro 구독이 시작되었습니다.',
      ProPurchaseNotice.restoreSucceeded => '구매 내역을 복원했습니다.',
      ProPurchaseNotice.nothingToRestore => '복원할 활성 구독이 없습니다.',
      ProPurchaseNotice.pending => '결제를 확인하고 있습니다.',
      ProPurchaseNotice.failed => '결제를 완료하지 못했습니다. 잠시 후 다시 시도해주세요.',
      ProPurchaseNotice.storeUnavailable =>
        'App Store에 연결할 수 없습니다. 잠시 후 다시 시도해주세요.',
      ProPurchaseNotice.productsUnavailable => '구독 상품 정보를 불러오지 못했습니다.',
      ProPurchaseNotice.signInRequired => '로그인 후 Pro 구독을 이용해주세요.',
      null => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _isPro =>
      widget.currentlyPro || _purchaseService.isEntitlementActive;

  ProductDetails? get _selectedProduct => _selectedIndex == 0
      ? _purchaseService.monthlyProduct
      : _purchaseService.yearlyProduct;

  @override
  Widget build(BuildContext context) {
    // Defensive guard for any future route that bypasses the hidden entry point.
    if (!proSubscriptionEnabled) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
            children: [
              ShareFitPageHeader(
                title: 'ShareFit Pro',
                subtitle: _isPro
                    ? '현재 Pro 기능을 이용하고 있습니다.'
                    : '운동 경험을 제한 없이 확장해보세요.',
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context, _isPro),
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ),
              const SizedBox(height: 28),
              ShareFitCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: colors.primary,
                      size: 38,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isPro ? 'ShareFit Pro 이용 중' : 'Pro에 포함된 기능',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 14),
                    const _BenefitRow(label: '친구 수 제한 없이 함께 운동'),
                    const _BenefitRow(label: '운동 인증 사진 무제한'),
                    const _BenefitRow(label: '고급 운동 통계'),
                    const _BenefitRow(label: '고급 랭킹 비교'),
                    const _BenefitRow(label: 'Pro 프로필 꾸미기'),
                  ],
                ),
              ),
              if (!_isPro) ...[
                const SizedBox(height: 18),
                ShareFitCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '구독 선택',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 16),
                      ShareFitSlidingSegmentedControl(
                        labels: const ['월간', '연간'],
                        selectedIndex: _selectedIndex,
                        backgroundColor: colors.surfaceContainerHigh,
                        borderColor: colors.outlineVariant,
                        unselectedForegroundColor: colors.onSurfaceVariant,
                        onChanged: _purchaseService.isBusy
                            ? (_) {}
                            : (index) => setState(() {
                                _selectedIndex = index;
                              }),
                      ),
                      const SizedBox(height: 18),
                      _ProductSummary(
                        product: _selectedProduct,
                        periodLabel: _selectedIndex == 0 ? '월' : '년',
                        loading: _purchaseService.isLoadingProducts,
                        error: _purchaseService.productLoadError,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        _selectedProduct == null || _purchaseService.isBusy
                        ? null
                        : () => _purchaseService.purchase(_selectedProduct!),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child:
                        _purchaseService.isPurchasing ||
                            _purchaseService.isPending
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _purchaseService.isPending
                                    ? '결제 확인 중'
                                    : '결제 준비 중',
                              ),
                            ],
                          )
                        : const Text(
                            'Pro 시작하기',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      '완료',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: _purchaseService.isBusy
                    ? null
                    : () => _purchaseService.restorePurchases(),
                child: _purchaseService.isRestoring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('구매 복원'),
              ),
              const SizedBox(height: 8),
              Text(
                '구독은 Apple ID에 청구되며 App Store 구독 설정에서 관리할 수 있습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSummary extends StatelessWidget {
  const _ProductSummary({
    required this.product,
    required this.periodLabel,
    required this.loading,
    required this.error,
  });

  final ProductDetails? product;
  final String periodLabel;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 68,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (product == null) {
      return SizedBox(
        height: 68,
        child: Center(
          child: Text(
            error ?? '상품 정보를 확인할 수 없습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product!.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: product!.price,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' / $periodLabel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          product!.currencyCode,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
