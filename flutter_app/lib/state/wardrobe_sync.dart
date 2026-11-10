import '../models/wardrobe.dart';
import '../services/wardrobe_service.dart';
import 'wardrobe_store.dart';

/// Supabase is the shared wardrobe and `wardrobe.db` is this device's copy.
/// The screens read one `wardrobeItems` notifier, so both sides meet here
/// instead of every screen learning about the backend.
///
/// ponytail: a remote item is not mirrored into SQLite, so the first launch
/// without a network shows the cache only. Mirror on read when offline stops
/// meaning "demo".

/// Replaces the catalog with the owner's rows. No-op on the demo backend, and a
/// failed fetch leaves the local cache in place rather than blanking the UI.
///
/// Catches everything, not just `WardrobeException`: a DNS failure surfaces as
/// `AuthRetryableFetchException` from gotrue and used to escape `main()` as an
/// unhandled async error, freezing the app on the splash screen.
Future<void> loadWardrobeFromBackend() async {
  if (wardrobeService is DemoWardrobeService) return;
  try {
    wardrobeItems.value = await wardrobeService.items();
  } catch (_) {
    // Offline or signed out: keep what the file already holds.
  }
}

/// Remote first, then the cache: a row the backend rejected must not look
/// saved.
Future<void> saveWardrobeItem(WardrobeItem item) async {
  final stored = await wardrobeService.save(item);
  await addWardrobeItem(stored);
}
