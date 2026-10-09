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
                initialCity: 'Каскелен',
                onChanged: (city) => selectedCity = city,
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextFormField), 'Талгар');

    expect(selectedCity, 'Талгар');
  });
}
