import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/screens/login_screen.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/wardrobe_service.dart';

void main() {
  tearDown(() {
    useAuthService(DemoAuthService());
    useWardrobeService(DemoWardrobeService());
  });

  testWidgets('a live session opens the home screen, not the login form', (
    tester,
  ) async {
    // Regression: `home: LoginScreen()` meant every relaunch looked like a
    // logout even though the Supabase token was still valid.
    await authService.signIn(email: 'uji@gayaku.app', password: 'x');
    await tester.pumpWidget(const GayakuApp());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('no session still lands on the login form', (tester) async {
    await tester.pumpWidget(const GayakuApp());
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
