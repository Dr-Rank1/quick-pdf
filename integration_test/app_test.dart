import 'package:flutter_riverpod/flutter_riverpod.dart';import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quick_pdf/constants/preference_keys.dart';
import 'package:quick_pdf/main.dart';
import 'package:quick_pdf/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launches past onboarding and opens Tools tab', (tester) async {
    SharedPreferences.setMockInitialValues({
      kPrefHasSeenOnboarding: true,
    });

    final router = createAppRouter(showOnboarding: false);
    await tester.pumpWidget(
      ProviderScope(child: QuickPDFApp(router: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent'), findsOneWidget);

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    expect(find.text('Create'), findsOneWidget);
    expect(find.text('PDF Tools'), findsOneWidget);
  });
}
