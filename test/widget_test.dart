import 'package:flutter_test/flutter_test.dart';
import 'package:whyphy_app/app/app.dart';

void main() {
  testWidgets('renderiza a splash inicial do WhyPhy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AplicativoWhyPhy());

    expect(find.text('WhyPhy'), findsOneWidget);
  });
}
