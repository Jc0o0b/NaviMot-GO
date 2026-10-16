import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Abstrakcja uwierzytelniania. Dziś działa implementacja lokalna
/// ([LocalAuthService]); docelowo podmieniana na Firebase Auth bez zmian
/// w resztce aplikacji.
abstract class AuthService {
  /// Czy usługa korzysta ze zdalnego backendu (Firebase) — dla UI/statusu.
  bool get isRemote;

  Future<UserProfile?> restore();
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserProfile> quickSignIn({required String nickname});
  Future<UserProfile> saveProfile(UserProfile profile);
  Future<void> signOut();
}

/// Lokalne (offline) konta zapisywane w SharedPreferences.
/// Hasła są jedynie zaciemniane (placeholder) — prawdziwe, bezpieczne
/// uwierzytelnianie zapewni Firebase Auth po podłączeniu backendu.
class LocalAuthService implements AuthService {
  static const String _accountsKey = 'auth_accounts';
  static const String _currentUidKey = 'auth_current_uid';

  @override
  bool get isRemote => false;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _readAccounts() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAccounts(Map<String, dynamic> accounts) async {
    final prefs = await _prefs;
    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  String _hash(String value) {
    // Prosty hash 32-bit (djb2) — działa też w kompilacji do JS.
    var hash = 5381;
    for (final unit in value.codeUnits) {
      hash = ((hash * 33) + unit) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  String _slug(String value) {
    final lower = value.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final code in lower.codeUnits) {
      final c = String.fromCharCode(code);
      if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        buffer.write(c);
      } else {
        buffer.write('_');
      }
    }
    return buffer.toString();
  }

  UserProfile _profileFrom(Map<String, dynamic> account) => UserProfile(
        uid: account['uid'] as String,
        email: account['email'] as String?,
        displayName: account['displayName'] as String? ?? 'Użytkownik',
        points: (account['points'] as num?)?.toInt() ?? 0,
        reports: (account['reports'] as num?)?.toInt() ?? 0,
        confirmations: (account['confirmations'] as num?)?.toInt() ?? 0,
      );

  @override
  Future<UserProfile?> restore() async {
    final prefs = await _prefs;
    final uid = prefs.getString(_currentUidKey);
    if (uid == null) return null;
    final accounts = await _readAccounts();
    final account = accounts[uid];
    if (account is Map<String, dynamic>) return _profileFrom(account);
    return null;
  }

  @override
  Future<UserProfile> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AuthException('Podaj poprawny adres e-mail');
    }
    if (password.length < 6) {
      throw AuthException('Hasło musi mieć min. 6 znaków');
    }
    final accounts = await _readAccounts();
    final uid = 'local-${_slug(normalized)}';
    if (accounts.containsKey(uid)) {
      throw AuthException('Konto z tym adresem już istnieje');
    }
    final name = displayName.trim().isEmpty
        ? normalized.split('@').first
        : displayName.trim();
    accounts[uid] = {
      'uid': uid,
      'email': normalized,
      'displayName': name,
      'passwordHash': _hash(password),
      'points': 0,
      'reports': 0,
      'confirmations': 0,
    };
    await _writeAccounts(accounts);
    final prefs = await _prefs;
    await prefs.setString(_currentUidKey, uid);
    return _profileFrom(accounts[uid] as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final accounts = await _readAccounts();
    final uid = 'local-${_slug(normalized)}';
    final account = accounts[uid];
    if (account is! Map<String, dynamic>) {
      throw AuthException('Nie znaleziono konta z tym adresem');
    }
    if (account['passwordHash'] != _hash(password)) {
      throw AuthException('Nieprawidłowe hasło');
    }
    final prefs = await _prefs;
    await prefs.setString(_currentUidKey, uid);
    return _profileFrom(account);
  }

  @override
  Future<UserProfile> quickSignIn({required String nickname}) async {
    final name = nickname.trim();
    if (name.length < 2) {
      throw AuthException('Pseudonim musi mieć min. 2 znaki');
    }
    final accounts = await _readAccounts();
    final uid = 'local-${_slug(name)}';
    if (accounts[uid] is! Map<String, dynamic>) {
      accounts[uid] = {
        'uid': uid,
        'email': null,
        'displayName': name,
        'passwordHash': null,
        'points': 0,
        'reports': 0,
        'confirmations': 0,
      };
      await _writeAccounts(accounts);
    }
    final prefs = await _prefs;
    await prefs.setString(_currentUidKey, uid);
    return _profileFrom(accounts[uid] as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> saveProfile(UserProfile profile) async {
    final accounts = await _readAccounts();
    final existing = accounts[profile.uid];
    accounts[profile.uid] = {
      if (existing is Map<String, dynamic>) ...existing,
      ...profile.toJson(),
    };
    await _writeAccounts(accounts);
    return profile;
  }

  @override
  Future<void> signOut() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUidKey);
  }
}
