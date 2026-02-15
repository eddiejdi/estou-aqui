import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? bio;
  final String role;

  const User({
    required this.id,
    required this.name,
    this.email = '',
    this.avatar,
    this.bio,
    this.role = 'user',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Usuário',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] as String? ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar': avatar,
    'bio': bio,
    'role': role,
  };

  User copyWith({
    String? name,
    String? email,
    String? avatar,
    String? bio,
    String? role,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [id, name, email, avatar, bio, role];
}
