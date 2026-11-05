import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileStorage {
  static const _kUsername = 'profile.username';
  static const _kEmail = 'profile.email';
  static const _kBio = 'profile.bio';
  static const _kJoined = 'profile.joined';
  static const _kAvatarPath = 'profile.avatarPath';

  static Future<UserProfile> load() async {
    final sp = await SharedPreferences.getInstance();
    final map = <String, Object?>{
      'username': sp.getString(_kUsername),
      'email': sp.getString(_kEmail),
      'bio': sp.getString(_kBio),
      'joined': sp.getString(_kJoined),
      'avatarPath': sp.getString(_kAvatarPath),
    };
    return UserProfile.fromMap(map);
  }

  static Future<void> save(UserProfile profile) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kUsername, profile.username);
    await sp.setString(_kEmail, profile.email);
    await sp.setString(_kBio, profile.bio);
    await sp.setString(_kJoined, profile.joined);
    await sp.setString(_kAvatarPath, profile.avatarPath);
  }
}
