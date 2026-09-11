import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sharefit/services/pro_purchase_service.dart';

void main() {
  late _FakePurchaseStore store;
  late _FakeEntitlementWriter writer;
  late ProPurchaseService service;

  setUp(() {
    store = _FakePurchaseStore();
    writer = _FakeEntitlementWriter();
    service = ProPurchaseService(
      store: store,
      entitlementWriter: writer,
      isSupportedPlatform: () => true,
    );
  });

  tearDown(() async {
    service.dispose();
    await store.close();
  });

  test(
    'loads both StoreKit products and keeps their localized prices',
    () async {
      await service.loadProducts();

      expect(service.monthlyProduct?.price, '₩1,900');
      expect(service.yearlyProduct?.price, '₩19,000');
      expect(store.queriedIds, proProductIds);
    },
  );

  test(
    'successful purchase activates entitlement and completes transaction',
    () async {
      await service.initialize();
      final purchase = _CompletablePurchaseDetails(
        productID: proMonthlyProductId,
        status: PurchaseStatus.purchased,
      );

      store.emit(<PurchaseDetails>[purchase]);
      await pumpEventQueue(times: 4);

      expect(service.isEntitlementActive, isTrue);
      expect(service.notice, ProPurchaseNotice.purchaseSucceeded);
      expect(writer.activatedProductId, proMonthlyProductId);
      expect(store.completedPurchases, <PurchaseDetails>[purchase]);
    },
  );

  test(
    'Firebase sync failure does not turn StoreKit success into purchase failure',
    () async {
      writer.activationError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'Missing or insufficient permissions.',
      );
      final notices = <ProPurchaseNotice?>[];
      service.addListener(() => notices.add(service.notice));
      await service.initialize();
      final purchase = _CompletablePurchaseDetails(
        productID: proMonthlyProductId,
        status: PurchaseStatus.purchased,
      );

      store.emit(<PurchaseDetails>[purchase]);
      await pumpEventQueue(times: 4);

      expect(service.isEntitlementActive, isTrue);
      expect(service.notice, ProPurchaseNotice.purchaseSucceeded);
      expect(store.completedPurchases, <PurchaseDetails>[purchase]);
      expect(notices, isNot(contains(ProPurchaseNotice.failed)));
      expect(service.isBusy, isFalse);
    },
  );

  test(
    'completePurchase failure does not turn StoreKit success into purchase failure',
    () async {
      store.completePurchaseError = Exception('complete failed');
      await service.initialize();
      final purchase = _CompletablePurchaseDetails(
        productID: proYearlyProductId,
        status: PurchaseStatus.purchased,
      );

      store.emit(<PurchaseDetails>[purchase]);
      await pumpEventQueue(times: 4);

      expect(service.isEntitlementActive, isTrue);
      expect(service.notice, ProPurchaseNotice.purchaseSucceeded);
    },
  );

  test('StoreKit purchase error still reports purchase failure', () async {
    await service.initialize();

    store.emit(<PurchaseDetails>[
      _CompletablePurchaseDetails(
        productID: proMonthlyProductId,
        status: PurchaseStatus.error,
        completable: false,
      ),
    ]);
    await pumpEventQueue(times: 3);

    expect(service.isEntitlementActive, isFalse);
    expect(service.notice, ProPurchaseNotice.failed);
  });

  test(
    'canceled purchase does not activate entitlement or show an error',
    () async {
      await service.initialize();
      store.emit(<PurchaseDetails>[
        _CompletablePurchaseDetails(
          productID: proYearlyProductId,
          status: PurchaseStatus.canceled,
          completable: false,
        ),
      ]);
      await pumpEventQueue(times: 3);

      expect(service.isEntitlementActive, isFalse);
      expect(service.notice, isNull);
      expect(writer.activatedProductId, isNull);
    },
  );

  test('empty restore removes only Apple-managed entitlement', () async {
    await service.restorePurchases();

    expect(writer.deactivateCalls, 1);
    expect(service.notice, ProPurchaseNotice.nothingToRestore);
  });
}

class _FakePurchaseStore implements ProPurchaseStore {
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();

  Set<String>? queriedIds;
  final List<PurchaseDetails> completedPurchases = <PurchaseDetails>[];
  Object? completePurchaseError;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queriedIds = identifiers;
    return ProductDetailsResponse(
      productDetails: <ProductDetails>[
        _product(proMonthlyProductId, 'ShareFit Pro 월간', '₩1,900', 1900),
        _product(proYearlyProductId, 'ShareFit Pro 연간', '₩19,000', 19000),
      ],
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (completePurchaseError case final error?) throw error;
    completedPurchases.add(purchase);
  }

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  Future<void> close() => _controller.close();
}

class _FakeEntitlementWriter implements ProEntitlementWriter {
  String? activatedProductId;
  int deactivateCalls = 0;
  Object? activationError;

  @override
  bool get hasSignedInUser => true;

  @override
  String? get userId => 'test-user';

  @override
  Future<void> activate(PurchaseDetails purchase) async {
    if (activationError case final error?) throw error;
    activatedProductId = purchase.productID;
  }

  @override
  Future<void> deactivateIfAppleManaged() async {
    deactivateCalls += 1;
  }
}

class _CompletablePurchaseDetails extends PurchaseDetails {
  _CompletablePurchaseDetails({
    required super.productID,
    required super.status,
    bool completable = true,
  }) : _completable = completable,
       super(
         purchaseID: 'purchase-id',
         transactionDate: '1700000000000',
         verificationData: PurchaseVerificationData(
           localVerificationData: 'local-jws',
           serverVerificationData: 'server-jws',
           source: 'app_store',
         ),
       );

  final bool _completable;

  @override
  bool get pendingCompletePurchase => _completable;
}

ProductDetails _product(
  String id,
  String title,
  String price,
  double rawPrice,
) {
  return ProductDetails(
    id: id,
    title: title,
    description: '',
    price: price,
    rawPrice: rawPrice,
    currencyCode: 'KRW',
    currencySymbol: '₩',
  );
}
