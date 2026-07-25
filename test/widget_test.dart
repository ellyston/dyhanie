import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyhanie/main.dart';

void main() {
  testWidgets('App renders title and message input', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Title is shown in the app bar
    expect(find.text('Дыхание'), findsOneWidget);

    // Message input field is present
    expect(find.byType(TextField), findsOneWidget);

    // Send button is present
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('Sending a message adds it to the chat', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Enter text in the input field
    await tester.enterText(find.byType(TextField), 'Привет');
    await tester.pump();

    // Tap the send button
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    // The message should appear in the list
    expect(find.text('Привет'), findsOneWidget);
  });
}
