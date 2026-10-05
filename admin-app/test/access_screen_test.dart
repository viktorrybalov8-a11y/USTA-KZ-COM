import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usta_admin/main.dart';

void main() {
  testWidgets('shows clear access denial message', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AccessScreen(
        title: 'Нет доступа администратора',
        message: 'Нужно назначить серверное право.',
      ),
    ));

    expect(find.text('Нет доступа администратора'), findsOneWidget);
    expect(find.text('Нужно назначить серверное право.'), findsOneWidget);
  });
}
