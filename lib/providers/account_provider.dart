import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';

/// Zarządza zalogowanym użytkownikiem oraz jego punktami i poziomem.
/// Tryb gościa = brak zalogowanego konta (można przeglądać, ale nie
/// zgłaszać zdarzeń ani zdobywać punktów).
class AccountProvider extends ChangeNotifier {
  final AuthService _auth;
  AccountProvider({AuthService? auth}) : _auth = auth ?? LocalAuthService();

  UserProfile? _user;
  bool _loaded = false;
  bool _busy = false;
  String? _error;

  UserProfile? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  String? get error => _error;
  bool get isRemoteAuth => _auth.isRemote;

  String get displayName => _user?.displayName ?? 'Gość';

  Future<void> load() async {
    try {
      _user = await _auth.restore();
    } catch (_) {
      _user = null;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _run(() => _auth.signUpWithEmail(
          email: email, password: password, displayName: displayName));

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _run(() => _auth.signInWithEmail(email: email, password: password));

  Future<bool> quickSignIn({required String nickname}) =>
      _run(() => _auth.quickSignIn(nickname: nickname));

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    notifyListeners();
  }

  /// Przyznaje punkty i aktualizuje liczniki; zapisuje profil.
  Future<void> award({
    int points = 0,
    bool report = false,
    bool confirmation = false,
    bool place = false,
  }) async {
    final current = _user;
    if (current == null) return;
    final updated = current.copyWith(
      points: current.points + points,
      reports: current.reports + (report ? 1 : 0),
      confirmations: current.confirmations + (confirmation ? 1 : 0),
    );
    _user = updated;
    notifyListeners();
    try {
      await _auth.saveProfile(updated);
    } catch (_) {}
  }

  Future<bool> _run(Future<UserProfile> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _user = await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Wystąpił błąd: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
