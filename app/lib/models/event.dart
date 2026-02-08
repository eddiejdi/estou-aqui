import 'package:equatable/equatable.dart';
import 'user.dart';

enum EventStatus { scheduled, active, ended, cancelled }

enum EventCategory {
  manifestacao,
  protesto,
  marcha,
  atoPublico,
  assembleia,
  greve,
  ocupacao,
  vigilia,
  outro;

  String get label {
    switch (this) {
      case EventCategory.manifestacao: return 'Manifestação';
      case EventCategory.protesto: return 'Protesto';
      case EventCategory.marcha: return 'Marcha';
      case EventCategory.atoPublico: return 'Ato Público';
      case EventCategory.assembleia: return 'Assembleia';
      case EventCategory.greve: return 'Greve';
      case EventCategory.ocupacao: return 'Ocupação';
      case EventCategory.vigilia: return 'Vigília';
      case EventCategory.outro: return 'Outro';
    }
  }

  String get emoji {
    switch (this) {
      case EventCategory.manifestacao: return '✊';
      case EventCategory.protesto: return '📢';
      case EventCategory.marcha: return '🚶';
      case EventCategory.atoPublico: return '🏛️';
      case EventCategory.assembleia: return '🗣️';
      case EventCategory.greve: return '🛑';
      case EventCategory.ocupacao: return '🏕️';
      case EventCategory.vigilia: return '🕯️';
      case EventCategory.outro: return '📍';
    }
  }

  static EventCategory fromString(String value) {
    switch (value) {
      case 'manifestacao': return EventCategory.manifestacao;
      case 'protesto': return EventCategory.protesto;
      case 'marcha': return EventCategory.marcha;
      case 'ato_publico': return EventCategory.atoPublico;
      case 'assembleia': return EventCategory.assembleia;
      case 'greve': return EventCategory.greve;
      case 'ocupacao': return EventCategory.ocupacao;
      case 'vigilia': return EventCategory.vigilia;
      default: return EventCategory.outro;
    }
  }
}

class SocialEvent extends Equatable {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? state;
  final DateTime startDate;
  final DateTime? endDate;
  final EventStatus status;
  final int estimatedAttendees;
  final int confirmedAttendees;
  final double? areaSquareMeters;
  final User? organizer;
  final List<String> tags;
  final bool isVerified;
  final DateTime createdAt;

  const SocialEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.imageUrl,
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.state,
    required this.startDate,
    this.endDate,
    this.status = EventStatus.scheduled,
    this.estimatedAttendees = 0,
    this.confirmedAttendees = 0,
    this.areaSquareMeters,
    this.organizer,
    this.tags = const [],
    this.isVerified = false,
    required this.createdAt,
  });

  factory SocialEvent.fromJson(Map<String, dynamic> json) {
    return SocialEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: EventCategory.fromString(json['category'] ?? 'outro'),
      imageUrl: json['imageUrl'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      status: EventStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => EventStatus.scheduled,
      ),
      estimatedAttendees: json['estimatedAttendees'] as int? ?? 0,
      confirmedAttendees: json['confirmedAttendees'] as int? ?? 0,
      areaSquareMeters: (json['areaSquareMeters'] as num?)?.toDouble(),
      organizer: json['organizer'] != null ? User.fromJson(json['organizer']) : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isVerified: json['isVerified'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'category': category.name,
    'imageUrl': imageUrl,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'city': city,
    'state': state,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'tags': tags,
    'areaSquareMeters': areaSquareMeters,
  };

  bool get isActive => status == EventStatus.active;
  bool get isUpcoming => status == EventStatus.scheduled && startDate.isAfter(DateTime.now());

  String get locationDisplay {
    if (address != null) return address!;
    if (city != null && state != null) return '$city, $state';
    if (city != null) return city!;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  @override
  List<Object?> get props => [id, title, status, estimatedAttendees, confirmedAttendees];
}
