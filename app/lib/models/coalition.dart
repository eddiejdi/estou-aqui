import 'package:equatable/equatable.dart';
import 'user.dart';
import 'event.dart';

/// Coalizão — agrupa vários protestos/eventos sobre a mesma causa
class Coalition extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? hashtag;
  final String? imageUrl;
  final EventCategory category;
  final String status; // active, ended, cancelled
  final int totalEvents;
  final int totalAttendees;
  final int totalCities;
  final List<String> cities;
  final User? creator;
  final List<SocialEvent> events;
  final List<String> tags;
  final DateTime createdAt;

  const Coalition({
    required this.id,
    required this.name,
    required this.description,
    this.hashtag,
    this.imageUrl,
    this.category = EventCategory.manifestacao,
    this.status = 'active',
    this.totalEvents = 0,
    this.totalAttendees = 0,
    this.totalCities = 0,
    this.cities = const [],
    this.creator,
    this.events = const [],
    this.tags = const [],
    required this.createdAt,
  });

  factory Coalition.fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List<dynamic>? ?? [];
    return Coalition(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hashtag: json['hashtag'] as String?,
      imageUrl: json['imageUrl'] as String?,
      category: EventCategory.fromString(json['category'] ?? 'manifestacao'),
      status: json['status'] as String? ?? 'active',
      totalEvents: json['totalEvents'] as int? ?? 0,
      totalAttendees: json['totalAttendees'] as int? ?? 0,
      totalCities: json['totalCities'] as int? ?? 0,
      cities: (json['cities'] as List<dynamic>?)?.cast<String>() ?? [],
      creator: json['creator'] != null ? User.fromJson(json['creator']) : null,
      events: eventsList
          .map((e) => SocialEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'hashtag': hashtag,
    'imageUrl': imageUrl,
    'category': category.name,
    'tags': tags,
  };

  bool get isActive => status == 'active';

  /// Resumo textual para exibição
  String get summary {
    final parts = <String>[];
    if (totalEvents > 0) parts.add('$totalEvents evento${totalEvents > 1 ? 's' : ''}');
    if (totalCities > 0) parts.add('$totalCities cidade${totalCities > 1 ? 's' : ''}');
    if (totalAttendees > 0) parts.add('$totalAttendees participantes');
    return parts.join(' · ');
  }

  @override
  List<Object?> get props => [id, name, totalEvents, totalAttendees];
}
