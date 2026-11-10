import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts ship in assets/google_fonts/. Failing loudly beats silently fetching a
  // different face at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  // The wardrobe is a database, not a constant: read it before the first frame
  // so the home and wardrobe screens never flash an empty catalog.
  await initWardrobeStore();

  // ponytail: SQLite is what the screens read today; Supabase is the shared
  // copy behind the same service seam. Without credentials the app runs on
  // DemoAuthService/DemoWardrobeService, so the UI still works before a
  // project exists - see supabase/README.md for the switch-over.
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabaseKey,
      );
      final client = Supabase.instance.client;
      useAuthService(SupabaseAuthService(client));
      useWardrobeService(SupabaseWardrobeService(client));
      useOutfitService(SupabaseOutfitService(client));
      usePlannerService(SupabasePlannerService(client));
    } catch (_) {
      // Wrong URL or no network at launch: demo services keep the UI usable
      // instead of leaving the splash screen up forever.
    }
  }

  runApp(const GayakuApp());

  // Supabase is the shared wardrobe and SQLite is the offline copy. Fired after
  // the first frame, not awaited: the token refresh retries with backoff, so a
  // slow or dead network used to hold the splash screen for over a minute. The
  // notifier fills in when the rows arrive.
  unawaited(loadWardrobeFromBackend());
  unawaited(loadOutfitsFromBackend());
  unawaited(loadPlannerFromBackend());
}

class GayakuApp extends StatelessWidget {
  const GayakuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gayaku',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // A stored session still starts on its own: opening the app on the login
      // form while the token is alive made every relaunch look like a logout.
      home: authService.currentUser == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}
