import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app.dart';
import 'package:mobile/core/config/api_config.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await ApiConfig.init();
    await tester.pumpWidget(const StroketionApp());
    await tester.pump();
    expect(find.text('Stroketion'), findsOneWidget);
  });
}
