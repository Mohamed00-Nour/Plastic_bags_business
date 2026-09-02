import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_manager/core/widgets/common_widgets.dart';
import 'package:store_manager/core/widgets/stats_card.dart';

void main() {
  Widget testHost({required double width, required Widget child}) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets('responsive action bar stacks controls on a phone', (
    tester,
  ) async {
    const primaryKey = Key('primary');
    const actionsKey = Key('actions');

    await tester.pumpWidget(
      testHost(
        width: 320,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: ResponsiveActionBar(
            primary: SizedBox(key: primaryKey, height: 48, child: TextField()),
            actions: SizedBox(
              key: actionsKey,
              height: 48,
              child: ElevatedButton(
                onPressed: null,
                child: Text('Add a new record'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(actionsKey)).dy,
      greaterThan(tester.getTopLeft(find.byKey(primaryKey)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive action bar keeps controls inline on desktop', (
    tester,
  ) async {
    const primaryKey = Key('primary');
    const actionsKey = Key('actions');

    await tester.pumpWidget(
      testHost(
        width: 1200,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: ResponsiveActionBar(
            primary: SizedBox(key: primaryKey, height: 48, child: TextField()),
            actions: SizedBox(
              key: actionsKey,
              height: 48,
              child: ElevatedButton(onPressed: null, child: Text('Add record')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(actionsKey)).dy,
      tester.getTopLeft(find.byKey(primaryKey)).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats card scales long values without horizontal overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      testHost(
        width: 180,
        child: const StatsCard(
          title: 'Outstanding client balance with a long translated label',
          value: '\$123,456,789,012.99',
          icon: Icons.account_balance_wallet,
        ),
      ),
    );

    expect(find.text('\$123,456,789,012.99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
