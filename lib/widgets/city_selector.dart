import 'package:flutter/material.dart';

import '../app_data.dart';

/// Consistent city input for profiles and orders, with a free-text fallback.
class CitySelector extends StatefulWidget {
  const CitySelector({
    super.key,
    required this.initialCity,
    required this.onChanged,
    this.label = 'Город *',
  });

  final String initialCity;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<CitySelector> createState() => _CitySelectorState();
}

class _CitySelectorState extends State<CitySelector> {
  static const _otherCity = 'Другой населённый пункт';
  late String _selection;
  late final TextEditingController _otherCityController;

  bool get _isOther => _selection == _otherCity;

  @override
  void initState() {
    super.initState();
    final initialCity = widget.initialCity.trim();
    _selection = kazakhstanCities.contains(initialCity) ? initialCity : _otherCity;
    _otherCityController = TextEditingController(
      text: _selection == _otherCity ? initialCity : '',
    );
  }

  @override
  void dispose() {
    _otherCityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selection,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
            ),
            items: [
              ...kazakhstanCities.map(
                (city) => DropdownMenuItem(value: city, child: Text(city)),
              ),
              const DropdownMenuItem(
                value: _otherCity,
                child: Text(_otherCity),
              ),
            ],
            validator: (value) {
              if (value == null) return 'Выберите город';
              return null;
            },
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selection = value);
              widget.onChanged(
                value == _otherCity
                    ? _otherCityController.text.trim()
                    : value,
              );
            },
          ),
          if (_isOther) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherCityController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Название населённого пункта *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Укажите населённый пункт'
                  : null,
              onChanged: (value) => widget.onChanged(value.trim()),
            ),
          ],
        ],
      );
}
