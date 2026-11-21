import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'navigation.dart';
import 'screens/login_screen.dart';
import 'screens/update_password_screen.dart';
import 'services/auth_service.dart';
import 'services/outfit_service.dart';
import 'services/wardrobe_service.dart';
import 'state/outfit_store.dart';
import 'state/planner_store.dart';
import 'state/wardrobe_store.dart';
import 'state/wardrobe_sync.dart';
import 'theme/app_theme.dart';

/// Compile-time credentials, so no secret ever sits in the repo:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
/// See `supabase/README.md`. The key is the public one (a legacy anon key works
/// in the same slot); RLS, not secrecy, is what protects the data.
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/google_fonts/. Failing loudly beats silently fetching a
  // different face at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Supabase first: the cache file is per account, so the store needs to know
  // who is signed in before it opens anything. A restored session answers that
  // without a network round trip.
  SupabaseClient? client;
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseKey,
      );
      client = Supabase.instance.client;

      debugPrint('Supabase user at startup: ${client.auth.currentUser?.id}');
      useAuthService(SupabaseAuthService(client));
      useWardrobeService(SupabaseWardrobeService(client));
      useOutfitService(SupabaseOutfitService(client));
      usePlannerService(SupabasePlannerService(client));
    } catch (error, stack) {
      debugPrint('Supabase initialization failed; using demo services: $error');
      debugPrint('$stack');
    }
  }

  // The wardrobe is a database, not a constant: read it before the first frame
  // so the home and wardrobe screens never flash an empty catalog.
  await initWardrobeStore(userId: client?.auth.currentUser?.id);

  runApp(const GayakuApp());

  if (client != null) followAuthChanges(client);

  // Supabase is the shared wardrobe and SQLite is the offline copy. Fired after
  // the first frame, not awaited: the token refresh retries with backoff, so a
  // slow or dead network used to hold the splash screen for over a minute. The
  // notifier fills in when the rows arrive.
  unawaited(loadWardrobeFromBackend());
  unawaited(loadOutfitsFromBackend());
  unawaited(loadPlannerFromBackend());
}

/// Keeps the local cache in step with whoever is signed in. The file is per
/// account, so a sign-in opens that account's file and pulls its rows, and a
/// sign-out closes it — previously one shared `wardrobe.db` meant the next
/// person saw the previous account's garments until a sync happened to succeed.
void followAuthChanges(SupabaseClient client) {
  client.auth.onAuthStateChange.listen((state) async {
    if (state.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          // Ganti dengan nama widget halaman ubah password di lib/screens/ kamu
          builder: (_) => const UpdatePasswordScreen(),
        ),
      );
      return;
    }
    if (state.event == AuthChangeEvent.signedOut) {
      await closeWardrobeStore();
      return;
    }
    if (state.event != AuthChangeEvent.signedIn &&
        state.event != AuthChangeEvent.initialSession) {
      return;
    }
    final id = state.session?.user.id;
    if (id == null) return;
    await initWardrobeStore(userId: id);
    await loadWardrobeFromBackend();
    await loadOutfitsFromBackend();
    await loadPlannerFromBackend();
  });
}

class GayakuApp extends StatelessWidget {
  const GayakuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: globalThemeMode,
      builder: (context, currentMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: globalLanguage,
          builder: (context, langCode, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Gayaku',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: currentMode,
              locale: Locale(langCode),
              // A stored session still starts on its own: opening the app on the login
              // form while the token is alive made every relaunch look like a logout.
              home: authService.currentUser == null
                  ? const LoginScreen()
                  : const NavShell(),
            );
          },
        );
      },
    );
  }
}