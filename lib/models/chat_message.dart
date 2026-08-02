class ChatMessage {
  final String id;
  final String author;
  final String text;
  final DateTime time;
  final bool mine;

  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.time,
    required this.mine,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'author': author,
    'text': text,
    'time': time.millisecondsSinceEpoch,
    'mine': mine,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    author: json['author'] as String? ?? '',
    text: json['text'] as String? ?? '',
    time: DateTime.fromMillisecondsSinceEpoch(
        (json['time'] as num?)?.toInt() ?? 0),
    mine: json['mine'] as bool? ?? false,
  );
}
