import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usta_kz/widgets/city_selector.dart';

void main() {
  testWidgets('supports a settlement outside the suggested city list', (tester) async {
    var selectedCity = '';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: ListView(
            children: [
              CitySelector(
                initialCity: 'Астана',
                onChanged: (city) => selectedCity = city,
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Другой населённый пункт'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Другой населённый пункт').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Каскелен');

    expect(selectedCity, 'Каскелен');
  });
}
