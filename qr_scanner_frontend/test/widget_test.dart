import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_scanner_frontend/main.dart';

void main() {
  // PUBLIC_INTERFACE
  testWidgets('Main screen shows correct app bar title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Wait for widget to build
    await tester.pumpAndSettle();

    expect(find.text('QR Scanner'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  // PUBLIC_INTERFACE
  testWidgets('Result area displays prompt before scan', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Scan a QR code to see the result here.'),
      findsOneWidget,
    );
  });

  // PUBLIC_INTERFACE
  testWidgets('Drawer shows "History" and "Clear History"', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Open drawer
    ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text("History"), findsOneWidget);
    expect(find.text("Clear History"), findsOneWidget);
    expect(find.text("About"), findsOneWidget);
  });
}
