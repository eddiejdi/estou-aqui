import 'package:equatable/equatable.dart';
import 'user.dart';

class Checkin extends Equatable {
  final String id;
  final String userId;
  final String eventId;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime? checkedOutAt;
  final DateTime createdAt;
  final User? user;

  const Checkin({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.latitude,
    required this.longitude,
    this.isActive = true,
    this.checkedOutAt,
    required this.createdAt,
    this.user,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'] as String,
      userId: json['userId'] as String,
      eventId: json['eventId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
      checkedOutAt: json['checkedOutAt'] != null
          ? DateTime.parse(json['checkedOutAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }

  @override
  List<Object?> get props => [id, userId, eventId, isActive];
}
