import 'package:equatable/equatable.dart';
import 'user.dart';

enum ChatMessageType { text, image, location, alert }

class ChatMessage extends Equatable {
  final String id;
  final String userId;
  final String eventId;
  final String content;
  final ChatMessageType type;
  final User? user;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.content,
    this.type = ChatMessageType.text,
    this.user,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      userId: json['userId'] as String,
      eventId: json['eventId'] as String,
      content: json['content'] as String,
      type: ChatMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ChatMessageType.text,
      ),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, userId, eventId, content, createdAt];
}
