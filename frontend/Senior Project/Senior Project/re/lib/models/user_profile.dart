class UserProfile {
  final String username;
  final String email;
  final String bio;
  final String joined;

  // ✅ ใช้ได้ทุกแพลตฟอร์ม
  final String avatarPath;      // mobile/desktop
  final String avatarBase64;    // web

  const UserProfile({
    required this.username,
    required this.email,
    required this.bio,
    required this.joined,
    required this.avatarPath,
    required this.avatarBase64,
  });

  UserProfile copyWith({
    String? username,
    String? email,
    String? bio,
    String? joined,
    String? avatarPath,
    String? avatarBase64,
  }) {
    return UserProfile(
      username: username ?? this.username,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      joined: joined ?? this.joined,
      avatarPath: avatarPath ?? this.avatarPath,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    );
  }

  Map<String, String> toMap() => {
        'username': username,
        'email': email,
        'bio': bio,
        'joined': joined,
        'avatarPath': avatarPath,
        'avatarBase64': avatarBase64,
      };

  static UserProfile fromMap(Map<String, Object?> map) {
    String s(String k, String fallback) {
      final v = map[k] as String?;
      if (v == null) return fallback;
      final t = v.trim();
      return t.isEmpty ? fallback : t;
    }

    return UserProfile(
      username: s('username', 'Ibuyer'),
      email: s('email', 'ibuyer@gmail.com'),
      bio: s('bio', 'Love to eat meat'),
      joined: s('joined', 'October 2024'),
      avatarPath: (map['avatarPath'] as String?) ?? '',
      avatarBase64: (map['avatarBase64'] as String?) ?? '',
    );
  }

  static const defaultProfile = UserProfile(
    username: 'Ibuyer',
    email: 'ibuyer@gmail.com',
    bio: 'Love to eat meat',
    joined: 'October 2024',
    avatarPath: '',
    avatarBase64: '',
  );
}
