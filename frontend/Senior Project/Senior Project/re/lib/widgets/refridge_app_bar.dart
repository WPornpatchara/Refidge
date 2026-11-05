import 'package:flutter/material.dart';
import 'package:re/pages/profile_page.dart';

import '../managers/app_locale.dart';
import '../pages/notification_setting_page.dart';  // ← เปลี่ยน import
import '../models/inventory_item.dart';

class RefridgeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  final bool showBack;
  final bool showFlag;
  final bool showNotification;
  final bool showProfile;

  final VoidCallback? onBackTap;
  final VoidCallback? onProfileTap;

  final AppLocale? appLocale;

  final List<InventoryItem> items;

  const RefridgeAppBar({
    super.key,
    required this.title,
    required this.items,
    this.showBack         = true,
    this.showFlag         = true,
    this.showNotification = true,
    this.showProfile      = true,
    this.onBackTap,
    this.onProfileTap,
    this.appLocale,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop         = Navigator.of(context).canPop();
    final shouldShowBack = showBack && canPop;
    final isThai         = appLocale?.isThai ?? false;
    final flagAsset      = isThai
        ? 'assets/flags/th_circle.png'
        : 'assets/flags/en_circle.png';
    final flagScale = isThai ? 1.30 : 1.0;

    void openProfile() {
      if (appLocale == null) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProfilePage(appLocale: appLocale!),
      ));
    }

    Future<void> openNotification() async {
      if (appLocale == null) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NotificationSettingsPage(  
          items:     items,
          appLocale: appLocale!,
        ),
      ));
    }

    return AppBar(
      backgroundColor: const Color(0xFFA6C48A),
      elevation: 0,
      leading: shouldShowBack
          ? IconButton(
              icon:      const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: onBackTap ?? () => Navigator.pop(context),
            )
          : null,
      titleSpacing: shouldShowBack ? 0 : 16,
      title: Text(title, style: const TextStyle(color: Colors.black)),
      actions: [
        if (showFlag && appLocale != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: appLocale!.toggle,
              icon: SizedBox(
                width: 26, height: 26,
                child: ClipOval(
                  child: Transform.scale(
                    scale: flagScale,
                    child: Image.asset(
                      flagAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.language, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (showNotification)
          IconButton(
            icon:      const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: openNotification,
          ),

        if (showProfile)
          IconButton(
            icon:      const Icon(Icons.account_circle_outlined, color: Colors.black),
            onPressed: onProfileTap ?? openProfile,
          ),
      ],
    );
  }
}