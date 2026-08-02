import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../models/voivodeships.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/section_header.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const SectionHeader(
              title: 'Czat motocyklistów', icon: Icons.forum),
          Expanded(
            child: ListView.builder(
              itemCount: voivodeships.length,
              itemBuilder: (_, i) =>
                  _VoivodeshipTile(voivodeship: voivodeships[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoivodeshipTile extends StatelessWidget {
  final Voivodeship voivodeship;
  const _VoivodeshipTile({required this.voivodeship});

  @override
  Widget build(BuildContext context) {
    final chatVM = context.watch<ChatProvider>();
    final messages = chatVM.messagesFor(voivodeship.id);
    final last = messages.isEmpty ? null : messages.last;
    final subtitle = last == null
        ? 'Wspólne przejazdy w ${voivodeship.name.toLowerCase()}'
        : '${last.author}: ${last.text}';
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(Icons.motorcycle,
            color: Theme.of(context).colorScheme.primary, size: 22),
      ),
      title: Text(voivodeship.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              color: last == null
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(voivodeship: voivodeship),
        ),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  final Voivodeship voivodeship;
  const ConversationScreen({super.key, required this.voivodeship});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final nickname = context.read<SettingsProvider>().nickname;
    context.read<ChatProvider>().send(widget.voivodeship.id, nickname, text);
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatVM = context.watch<ChatProvider>();
    final messages = chatVM.messagesFor(widget.voivodeship.id);
    _scrollToBottom();
    return Scaffold(
      appBar: AppBar(
        title: Text('Czat ${widget.voivodeship.name}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Umawiaj wspólne przejazdy i dziel się informacjami z drogi',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) => _MessageBubble(message: messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Brak wiadomości w tym województwie',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text('Napisz pierwszy i znajdź towarzystwo na trasę',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Napisz wiadomość...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'chat-send',
              onPressed: _send,
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm').format(message.time.toLocal());
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine ? Colors.deepOrange : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.author,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                color: mine ? Colors.white : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
