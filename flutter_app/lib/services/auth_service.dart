import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Who is signed in, without any Supabase type leaking into the UI.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName = '',
  });

  final String id;
  final String email;
  final String displayName;
}

/// A failed sign-in/sign-up with a message that can be shown as-is.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The only seam between the screens and the auth backend.
///
/// Screens call [authService]; nothing else in the app imports Supabase.
abstract class AuthService {
  AuthUser? get currentUser;

  Future<AuthUser> signIn({required String email, required String password});

  /// Returns null when the backend wants the email confirmed first, so the
  /// caller can tell the user to check their inbox instead of opening Home.
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  /// Stores the display name on the account and returns the updated user.
  Future<AuthUser> updateDisplayName(String name);

  /// Sends the "reset your password" mail to [email].
  Future<void> requestPasswordReset(String email);
}

/// Stands in for the backend in tests and in runs built without credentials,
/// so `flutter run` still works before a Supabase project exists.
///
/// ponytail: accepts any credentials — replace by passing real credentials to
/// `flutter run` (see supabase/README.md); no screen depends on this class.
class DemoAuthService implements AuthService {
  AuthUser? _user;
  String _displayName = '';

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _user = _userFor(email, '');

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => _user = _userFor(email, displayName);

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<AuthUser> updateDisplayName(String name) async {
    _displayName = name.trim();
    final email = _user?.email ?? '';
    return _user = _userFor(email, _displayName);
  }

  AuthUser _userFor(String email, String displayName) {
    final trimmed = email.trim();
    final chosen = displayName.trim().isEmpty ? _displayName : displayName;
    return AuthUser(
      id: 'demo-user',
      email: trimmed,
      displayName: chosen.trim().isEmpty
          ? trimmed.split('@').first
          : chosen.trim(),
    );
  }
}

/// Talks to Supabase Auth (GoTrue). Profile rows are created by a database
/// trigger on `auth.users`, so sign-up needs no second request.
class SupabaseAuthService implements AuthService {
  SupabaseAuthService(this._client);

  final sb.SupabaseClient _client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _fromUser(user);
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final res = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = res.user;
        if (user == null) {
          throw const AuthException('Email atau password salah.');
        }
        return _fromUser(user);
      });

  @override
  Future<AuthUser?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _guard(() async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    final user = res.user;
    if (user == null) throw const AuthException('Registrasi gagal.');
    // No session means the project requires email confirmation.
    return res.session == null ? null : _fromUser(user);
  });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email.trim()));

  @override
  Future<AuthUser> updateDisplayName(String name) => _guard(() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sesi habis, masuk ulang.');
    final clean = name.trim();
    // The name lives on `profiles`; `auth.users` metadata is not writable from
    // the client without a second call, and nothing else reads it.
    await _client
        .from('profiles')
        .update({'display_name': clean})
        .eq('id', user.id);
    return AuthUser(id: user.id, email: user.email ?? '', displayName: clean);
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on sb.AuthException catch (e) {
      throw AuthException(_friendly(e.message));
    }
  }

  AuthUser _fromUser(sb.User user) {
    final name = user.userMetadata?['display_name'];
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: name is String ? name : '',
    );
  }

  /// Supabase error strings are English and shown to the user, so the ones a
  /// user can actually trigger get an Indonesian equivalent.
  static String _friendly(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email atau password salah.';
    }
    if (lower.contains('already registered') ||
        lower.contains('already exists')) {
      return 'Email sudah terdaftar.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password minimal 6 karakter.';
    }
    if (lower.contains('unable to validate email')) {
      return 'Format email tidak valid.';
    }
    return message;
  }
}

AuthService _auth = DemoAuthService();

/// The auth backend the screens talk to. Defaults to [DemoAuthService];
/// [main] swaps in [SupabaseAuthService] when credentials are compiled in.
AuthService get authService => _auth;

/// Swaps the backend; called once from [main] before the first frame.
void useAuthService(AuthService service) => _auth = service;
