import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/voivodeships.dart';

class ChatProvider extends ChangeNotifier {
  static const String _key = 'chat_messages';

  final Map<String, List<ChatMessage>> _messages = {
    for (final v in voivodeships) v.id: [],
  };
  bool _loaded = false;
  Future<void>? _loadFuture;

  bool get isLoaded => _loaded;

  ChatProvider() {
    load();
  }

  List<ChatMessage> messagesFor(String voivodeshipId) {
    return List.unmodifiable(_messages[voivodeshipId] ?? const []);
  }

  int totalCount() {
    var n = 0;
    for (final list in _messages.values) {
      n += list.length;
    }
    return n;
  }

  Future<void> load() {
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        for (final v in voivodeships) {
          final list = data[v.id];
          if (list is List) {
            _messages[v.id] = list
                .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      }
    } catch (_) {
      _messages.clear();
      for (final v in voivodeships) {
        _messages[v.id] = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> send(String voivodeshipId, String author, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final list = _messages[voivodeshipId] ??= [];
    list.add(ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      author: author.trim().isEmpty ? 'Motocyklista' : author,
      text: trimmed,
      time: DateTime.now(),
      mine: true,
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          for (final v in voivodeships)
            v.id: _messages[v.id]!.map((m) => m.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }
}
