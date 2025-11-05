import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke test builds a minimal widget tree', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Signolia smoke test')),
      ),
    ));

    expect(find.text('Signolia smoke test'), findsOneWidget);
  });
}
