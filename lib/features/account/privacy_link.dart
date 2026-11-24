import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';

/// 隱私權政策連結。網址尚未設定（AppConfig.privacyPolicyUrl 為空）時不顯示。
class PrivacyLink extends StatelessWidget {
  const PrivacyLink({super.key, this.asListTile = false});

  final bool asListTile;

  static Future<void> open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(AppConfig.privacyPolicyUrl);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('開啟隱私權政策失敗：$e');
      }
    }
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('無法開啟隱私權政策頁面。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.privacyPolicyUrl.isEmpty) return const SizedBox.shrink();
    if (asListTile) {
      return ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('隱私權政策'),
        trailing: const Icon(Icons.open_in_new, size: 18),
        onTap: () => open(context),
      );
    }
    return TextButton(onPressed: () => open(context), child: const Text('隱私權政策'));
  }
}
