import 'package:carebridge/app.dart';
import 'package:carebridge/features/care/application/care_store.dart';
import 'package:carebridge/features/care/data/demo_care_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('CareBridge renders splash screen', (tester) async {
    final store = CareStore(DemoCareRepository());
    await tester.runAsync(store.load);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: const CareBridgeApp(),
      ),
    );

    expect(find.text('CareBridge'), findsOneWidget);
  });
}
