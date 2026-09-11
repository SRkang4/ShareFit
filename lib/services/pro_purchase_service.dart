import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'auth_service.dart';

const String proMonthlyProductId = 'com.sharefit.app.pro.monthly';
const String proYearlyProductId = 'com.sharefit.app.pro.yearly';
const Set<String> proProductIds = <String>{
  proMonthlyProductId,
  proYearlyProductId,
};

enum ProPurchaseNotice {
  purchaseSucceeded,
  restoreSucceeded,
  nothingToRestore,
  pending,
  failed,
  storeUnavailable,
  productsUnavailable,
  signInRequired,
}

abstract class ProPurchaseStore {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseStore implements ProPurchaseStore {
  InAppPurchaseStore({InAppPurchase? purchase})
    : _purchase = purchase ?? InAppPurchase.instance;

  final InAppPurchase _purchase;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchase.purchaseStream;

  @override
  Future<bool> isAvailable() => _purchase.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _purchase.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _purchase.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _purchase.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _purchase.completePurchase(purchase);
}

abstract class ProPurchaseVerifier {
  Future<bool> isActive(PurchaseDetails purchase);
}

/// Local StoreKit testing verifier.
///
/// StoreKit 2 only emits verified transactions through the Flutter plugin, but
/// this client-side decision is not a production receipt validation boundary.
/// Replace this implementation with server verification before release.
class LocalStoreKitPurchaseVerifier implements ProPurchaseVerifier {
  const LocalStoreKitPurchaseVerifier();

  @override
  Future<bool> isActive(PurchaseDetails purchase) async {
    return proProductIds.contains(purchase.productID) &&
        (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) &&
        purchase.verificationData.source == 'app_store' &&
        purchase.verificationData.serverVerificationData.isNotEmpty;
  }
}

abstract class ProEntitlementWriter {
  bool get hasSignedInUser;
  String? get userId;

  Future<void> activate(PurchaseDetails purchase);

  Future<void> deactivateIfAppleManaged();
}

class FirebaseProEntitlementWriter implements ProEntitlementWriter {
  FirebaseProEntitlementWriter({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  @override
  bool get hasSignedInUser => _authService.hasCurrentUser;

  @override
  String? get userId => _authService.currentUserId;

  @override
  Future<void> activate(PurchaseDetails purchase) {
    return _authService.updateCurrentUserAppleSubscription(
      active: true,
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      transactionDate: purchase.transactionDate,
      verificationSource: purchase.verificationData.source,
    );
  }

  @override
  Future<void> deactivateIfAppleManaged() {
    return _authService.deactivateExpiredAppleSubscription();
  }
}

class ProPurchaseService extends ChangeNotifier {
  ProPurchaseService({
    ProPurchaseStore? store,
    ProPurchaseVerifier? verifier,
    ProEntitlementWriter? entitlementWriter,
    bool Function()? isSupportedPlatform,
  }) : _store = store ?? InAppPurchaseStore(),
       _verifier = verifier ?? const LocalStoreKitPurchaseVerifier(),
       _entitlementWriter = entitlementWriter ?? FirebaseProEntitlementWriter(),
       _isSupportedPlatform =
           isSupportedPlatform ??
           (() => defaultTargetPlatform == TargetPlatform.iOS);

  static final ProPurchaseService instance = ProPurchaseService();

  final ProPurchaseStore _store;
  final ProPurchaseVerifier _verifier;
  final ProEntitlementWriter _entitlementWriter;
  final bool Function() _isSupportedPlatform;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};
  bool _initialized = false;
  String? _initializedUserId;
  bool _available = false;
  bool _loadingProducts = false;
  bool _purchasing = false;
  bool _restoring = false;
  bool _pending = false;
  bool _entitlementActive = false;
  bool _sawActiveEntitlementDuringRestore = false;
  bool _backgroundRestore = false;
  String? _productLoadError;
  ProPurchaseNotice? _notice;
  int _noticeVersion = 0;

  bool get isSupported => _isSupportedPlatform();
  bool get isAvailable => _available;
  bool get isLoadingProducts => _loadingProducts;
  bool get isPurchasing => _purchasing;
  bool get isRestoring => _restoring;
  bool get isPending => _pending;
  bool get isBusy => _loadingProducts || _purchasing || _restoring || _pending;
  bool get isEntitlementActive => _entitlementActive;
  String? get productLoadError => _productLoadError;
  ProPurchaseNotice? get notice => _notice;
  int get noticeVersion => _noticeVersion;
  ProductDetails? get monthlyProduct => _products[proMonthlyProductId];
  ProductDetails? get yearlyProduct => _products[proYearlyProductId];
  List<ProductDetails> get products => List.unmodifiable(_products.values);

  Future<void> initialize({bool syncEntitlement = false}) async {
    if (!isSupported || !_entitlementWriter.hasSignedInUser) return;
    final userId = _entitlementWriter.userId;
    if (_initializedUserId != userId) {
      _initializedUserId = userId;
      _entitlementActive = false;
      _pending = false;
      _purchasing = false;
      _restoring = false;
    }
    if (!_initialized) {
      _initialized = true;
      _purchaseSubscription = _store.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (_) => _emitNotice(ProPurchaseNotice.failed),
      );
    }
    if (syncEntitlement) {
      unawaited(restorePurchases(background: true));
    }
  }

  Future<void> loadProducts() async {
    await initialize();
    if (!isSupported) {
      _productLoadError = 'iOS에서만 Pro 구독을 구매할 수 있습니다.';
      notifyListeners();
      return;
    }
    if (!_entitlementWriter.hasSignedInUser) {
      _emitNotice(ProPurchaseNotice.signInRequired);
      return;
    }
    if (_loadingProducts) return;

    _loadingProducts = true;
    _productLoadError = null;
    notifyListeners();
    try {
      _available = await _store.isAvailable();
      if (!_available) {
        _productLoadError = 'App Store에 연결할 수 없습니다.';
        _emitNotice(ProPurchaseNotice.storeUnavailable);
        return;
      }
      final response = await _store.queryProductDetails(proProductIds);
      _products
        ..clear()
        ..addEntries(
          response.productDetails
              .where((product) => proProductIds.contains(product.id))
              .map((product) => MapEntry(product.id, product)),
        );
      if (response.error != null ||
          response.notFoundIDs.isNotEmpty ||
          _products.length != proProductIds.length) {
        _productLoadError = '구독 상품 정보를 불러오지 못했습니다.';
        _emitNotice(ProPurchaseNotice.productsUnavailable);
      }
    } catch (_) {
      _productLoadError = '구독 상품 정보를 불러오지 못했습니다.';
      _emitNotice(ProPurchaseNotice.productsUnavailable);
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  Future<void> purchase(ProductDetails product) async {
    if (isBusy) return;
    if (!_entitlementWriter.hasSignedInUser) {
      _emitNotice(ProPurchaseNotice.signInRequired);
      return;
    }
    if (!proProductIds.contains(product.id)) {
      _emitNotice(ProPurchaseNotice.productsUnavailable);
      return;
    }

    _purchasing = true;
    notifyListeners();
    try {
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _purchasing = false;
        _emitNotice(ProPurchaseNotice.failed);
      }
    } catch (_) {
      _purchasing = false;
      _emitNotice(ProPurchaseNotice.failed);
    }
  }

  Future<void> restorePurchases({bool background = false}) async {
    await initialize();
    if (!isSupported || _restoring) return;
    if (!_entitlementWriter.hasSignedInUser) {
      if (!background) _emitNotice(ProPurchaseNotice.signInRequired);
      return;
    }

    _restoring = true;
    _backgroundRestore = background;
    _sawActiveEntitlementDuringRestore = false;
    if (!background) notifyListeners();
    try {
      _available = await _store.isAvailable();
      if (!_available) {
        if (!background) _emitNotice(ProPurchaseNotice.storeUnavailable);
        return;
      }
      await _store.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!_sawActiveEntitlementDuringRestore) {
        _entitlementActive = false;
        await _syncDeactivatedEntitlement();
        if (!background) _emitNotice(ProPurchaseNotice.nothingToRestore);
      } else if (!background) {
        _emitNotice(ProPurchaseNotice.restoreSucceeded);
      }
    } catch (_) {
      if (!background) _emitNotice(ProPurchaseNotice.failed);
    } finally {
      _restoring = false;
      _backgroundRestore = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        switch (purchase.status) {
          case PurchaseStatus.pending:
            _pending = true;
            _purchasing = false;
            if (!_backgroundRestore) {
              _emitNotice(ProPurchaseNotice.pending);
            }
          case PurchaseStatus.canceled:
            _pending = false;
            _purchasing = false;
            notifyListeners();
          case PurchaseStatus.error:
            _pending = false;
            _purchasing = false;
            _emitNotice(ProPurchaseNotice.failed);
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            final active = await _verifier.isActive(purchase);
            if (active) {
              _sawActiveEntitlementDuringRestore = true;
              _entitlementActive = true;
              _pending = false;
              _purchasing = false;
              if (!_restoring && !_backgroundRestore) {
                _emitNotice(ProPurchaseNotice.purchaseSucceeded);
              }
              await _syncActivatedEntitlement(purchase);
            } else {
              _pending = false;
              _purchasing = false;
              _debugSyncError(
                'StoreKit transaction verification did not activate entitlement',
              );
              notifyListeners();
            }
        }
      } catch (error) {
        _pending = false;
        _purchasing = false;
        if (purchase.status == PurchaseStatus.error) {
          _emitNotice(ProPurchaseNotice.failed);
        } else {
          _debugSyncError('Post-purchase entitlement handling failed', error);
          notifyListeners();
        }
      } finally {
        if (purchase.pendingCompletePurchase) {
          try {
            await _store.completePurchase(purchase);
          } catch (error) {
            _debugSyncError('StoreKit completePurchase failed', error);
          }
        }
      }
    }
    notifyListeners();
  }

  Future<void> _syncActivatedEntitlement(PurchaseDetails purchase) async {
    try {
      await _entitlementWriter.activate(purchase);
    } catch (error) {
      _debugSyncError('Firebase Pro entitlement activation sync failed', error);
    }
  }

  Future<void> _syncDeactivatedEntitlement() async {
    try {
      await _entitlementWriter.deactivateIfAppleManaged();
    } catch (error) {
      _debugSyncError(
        'Firebase Pro entitlement deactivation sync failed',
        error,
      );
    }
  }

  void _debugSyncError(String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint('[ProIAP] $message${error == null ? '' : ': $error'}');
  }

  void _emitNotice(ProPurchaseNotice notice) {
    _notice = notice;
    _noticeVersion += 1;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}
