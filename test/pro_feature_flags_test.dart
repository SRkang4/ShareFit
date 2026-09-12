import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharefit/config/feature_flags.dart';
import 'package:sharefit/screens/pro_purchase_screen.dart';

void main() {
  test('classroom mode grants client features without a paid entitlement', () {
    expect(proSubscriptionEnabled, isFalse);
    expect(hasClientProAccess(false), isTrue);
    expect(hasClientProAccess(true), isTrue);
  });

  testWidgets(
    'disabled purchase route shows no subscription UI or plugin calls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ProPurchaseScreen(currentlyPro: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro 시작하기'), findsNothing);
      expect(find.textContaining('구매'), findsNothing);
      expect(find.textContaining('구독'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
