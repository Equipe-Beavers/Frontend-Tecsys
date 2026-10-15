import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_tecsys/widgets/slider_field.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('max-only mode uses a regular slider and updates the maximum', (
    tester,
  ) async {
    RangeValues? changedValues;
    await tester.pumpWidget(
      _host(
        SliderField(
          label: 'Distância máxima',
          valueLabel: '5 km',
          minValue: 0,
          maxValue: 100,
          values: const RangeValues(0, 50),
          onChanged: (values) => changedValues = values,
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 50);
    expect(find.byType(RangeSlider), findsNothing);
    slider.onChanged!(75);
    expect(changedValues, const RangeValues(0, 75));
  });

  testWidgets('min-only mode reverses direction and updates the minimum', (
    tester,
  ) async {
    RangeValues? changedValues;
    await tester.pumpWidget(
      _host(
        SliderField(
          label: 'Distância mínima',
          valueLabel: '2 km',
          minValue: 0,
          maxValue: 100,
          values: const RangeValues(20, 100),
          enableMin: true,
          enableMax: false,
          onChanged: (values) => changedValues = values,
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 20);
    final direction = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.byType(Slider),
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(direction.textDirection, TextDirection.rtl);
    slider.onChanged!(30);
    expect(changedValues, const RangeValues(30, 100));
  });

  testWidgets('min and max modes use a range slider', (tester) async {
    RangeValues? changedValues;
    await tester.pumpWidget(
      _host(
        SliderField(
          label: 'Faixa',
          valueLabel: '2–8 km',
          minValue: 0,
          maxValue: 100,
          values: const RangeValues(20, 80),
          enableMin: true,
          enableMax: true,
          onChanged: (values) => changedValues = values,
        ),
      ),
    );

    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values, const RangeValues(20, 80));
    expect(find.byType(Slider), findsNothing);
    slider.onChanged!(const RangeValues(30, 70));
    expect(changedValues, const RangeValues(30, 70));
  });
}
