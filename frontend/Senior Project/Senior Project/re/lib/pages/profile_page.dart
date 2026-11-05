import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:re/managers/app_locale.dart';

import '../models/user_profile.dart';
import '../services/profile_storage.dart';
import '../widgets/refridge_app_bar.dart';
import '../widgets/food_loading.dart';

import '../pages/favorite_page.dart';
import '../pages/history_page.dart';
import '../pages/downloads_page.dart';

class ProfilePage extends StatefulWidget {
  static const routeName = '';

  final AppLocale appLocale;  

  const ProfilePage({
    super.key,
    required this.appLocale, 
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}


class _ProfilePageState extends State<ProfilePage> {
  UserProfile _profile = UserProfile.defaultProfile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loaded = await ProfileStorage.load();
    if (!mounted) return;
    setState(() {
      _profile = loaded;
      _loading = false;
    });
  }

  // ✅ โชว์ FoodLoading แบบไม่ค้างแน่นอน แล้วค่อย push ไปหน้าใหม่
  Future<void> _pushWithFoodLoading(
    Widget page, {
    required String text,
  }) async {
    // 1) เปิด dialog (ใช้ rootNavigator ให้ชัวร์)
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => Material(
        color: Colors.black.withOpacity(0.10),
        child: Center(child: FoodLoading(text: text)),
      ),
    );

    // 2) รอให้ dialog วาดก่อน (กันไม่เห็น loading)
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    // 3) ปิด dialog ก่อน push (กันค้าง/ทับหน้า)
    Navigator.of(context, rootNavigator: true).pop();

    // 4) push แบบสมูท
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  Future<void> _chooseAvatarSource() async {
    final isThai = widget.appLocale.isThai;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(isThai ? 'เลือกจากแกลเลอรี' : 'Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text(isThai ? 'ถ่ายรูป' : 'Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              if (_profile.avatarPath.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(isThai ? 'ลบรูปภาพ' : 'Remove photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _removeAvatar();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path);

    final target = File(
      p.join(dir.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await File(x.path).copy(target.path);

    final updated = _profile.copyWith(avatarPath: target.path);
    await ProfileStorage.save(updated);

    if (!mounted) return;

    setState(() {
      _profile = updated;
    });

    // ✅ กัน cache ค้าง
    try {
      final f = File(updated.avatarPath);
      if (f.existsSync()) {
        FileImage(f).evict();
      }
    } catch (_) {}
  }

  Future<void> _removeAvatar() async {
    final updated = _profile.copyWith(avatarPath: '');
    await ProfileStorage.save(updated);
    if (!mounted) return;
    setState(() {
      _profile = updated;
    });
  }

  Future<void> _editProfile() async {
    final isThai = widget.appLocale.isThai;

    final u = TextEditingController(text: _profile.username);
    final e = TextEditingController(text: _profile.email);
    final b = TextEditingController(text: _profile.bio);
    final j = TextEditingController(text: _profile.joined);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isThai ? 'แก้ไขโปรไฟล์' : 'Edit profile'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: u,
                decoration: InputDecoration(labelText: isThai ? 'ชื่อผู้ใช้' : 'Username'),
              ),
              TextField(
                controller: e,
                decoration: InputDecoration(labelText: isThai ? 'อีเมล' : 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: b,
                decoration: InputDecoration(labelText: isThai ? 'ประวัติ' : 'Bio'),
              ),
              TextField(
                controller: j,
                decoration: InputDecoration(
                  labelText: isThai ? 'เข้าร่วมเมื่อ (เช่น ตุลาคม 2024)' : 'Joined (e.g. October 2024)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isThai ? 'ยกเลิก' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isThai ? 'บันทึก' : 'Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final updated = _profile.copyWith(
      username: u.text.trim().isEmpty ? _profile.username : u.text.trim(),
      email: e.text.trim().isEmpty ? _profile.email : e.text.trim(),
      bio: b.text.trim().isEmpty ? _profile.bio : b.text.trim(),
      joined: j.text.trim().isEmpty ? _profile.joined : j.text.trim(),
    );

    await ProfileStorage.save(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    final isThai = widget.appLocale.isThai;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    ImageProvider? avatar;
    if (_profile.avatarPath.isNotEmpty) {
      final f = File(_profile.avatarPath);
      if (f.existsSync()) avatar = FileImage(f);
    }

 return Scaffold(
  backgroundColor: const Color(0xFFFFF2C6),

  appBar: RefridgeAppBar(
    title: isThai ? 'โปรไฟล์' : 'Profile',
    appLocale: widget.appLocale,
    items: const [], 
  ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF99BC85),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _chooseAvatarSource,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withOpacity(0.6),
                        backgroundImage: avatar,
                        child: avatar == null
                            ? const Icon(Icons.person,
                                size: 40, color: Colors.black54)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_profile.bio, style: const TextStyle(fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: _editProfile,
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2C6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isThai ? 'ชื่อผู้ใช้ : ${_profile.username}' : 'Username : ${_profile.username}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(isThai ? 'เข้าร่วม : ${_profile.joined}' : 'Joined : ${_profile.joined}',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(isThai ? 'อีเมล : ${_profile.email}' : 'Email : ${_profile.email}',
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _profileRow(Icons.favorite, isThai ? 'รายการโปรด' : 'Favourites', onTap: () {
            _pushWithFoodLoading(
              FavoritePage(appLocale: widget.appLocale),
              text: isThai ? 'กำลังโหลดรายการโปรด...' : 'Loading favourites...',
            );
          }),
          _profileRow(Icons.download, isThai ? 'ดาวน์โหลด' : 'Downloads', onTap: () {
            _pushWithFoodLoading(
              DownloadsPage(appLocale: widget.appLocale),
              text: isThai ? 'กำลังโหลดดาวน์โหลด...' : 'Loading downloads...',
            );
          }),
          _profileRow(Icons.history, isThai ? 'ประวัติ' : 'History', onTap: () {
            _pushWithFoodLoading(
              HistoryPage(appLocale: widget.appLocale),
              text: isThai ? 'กำลังโหลดประวัติ...' : 'Loading history...',
            );
          }),

          _profileRow(Icons.logout, isThai ? 'ออกจากระบบ' : 'Log Out', onTap: () {}),
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String title,
      {required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF99BC85),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
