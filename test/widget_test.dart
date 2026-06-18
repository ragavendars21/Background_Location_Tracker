// Smoke test — verifies the app widget tree can be built without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:background_location_tracker/app.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    // Just verifies the widget tree is constructable — no counter logic here.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
