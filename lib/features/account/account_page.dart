import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../services/exchange_rate_service.dart';
import '../auth/app_user.dart';
import '../auth/auth_service.dart';
import 'privacy_link.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _auth = AuthService.instance;
  late final Stream<AppUser?> _userStream = _auth.user;
  bool _busy = false;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editName(AppUser user) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: '修改顯示名稱',
        initialText: user.displayName,
        confirmLabel: '儲存',
        maxLength: AuthService.maxDisplayNameLength,
      ),
    );
    if (name == null || name.isEmpty || name == user.displayName) return;
    try {
      await _auth.updateDisplayName(name);
      _snack('已更新顯示名稱。');
    } on AuthFailure catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    try {
      await _auth.sendPasswordReset(user.email);
      _snack('重設密碼信已寄到 ${user.email}。');
    } on AuthFailure catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _TextInputDialog(
        title: '永久刪除帳號',
        message: '刪除後，你的帳號與雲端上所有訂閱資料都會永久刪除，無法復原。\n\n請輸入密碼確認：',
        label: '密碼',
        confirmLabel: '永久刪除',
        obscure: true,
        destructive: true,
      ),
    );
    if (password == null || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _auth.deleteAccount(password);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('帳號已刪除。')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshRates() async {
    final ok = await ExchangeRateService.instance.refresh();
    _snack(ok ? '匯率已更新。' : '目前無法更新匯率，請稍後再試。');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帳號設定', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<AppUser?>(
        stream: _userStream,
        initialData: _auth.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('目前未登入'));
          }
          return AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              children: [
                if (_busy) const LinearProgressIndicator(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('顯示名稱'),
                  subtitle: Text(user.displayName),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _editName(user),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email'),
                  subtitle: Text(
                    user.emailVerified ? user.email : '${user.email}（尚未驗證）',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('重設密碼'),
                  subtitle: const Text('寄送重設密碼信到你的信箱'),
                  onTap: () => _resetPassword(user),
                ),
                const Divider(),
                ValueListenableBuilder<ExchangeRates>(
                  valueListenable: ExchangeRateService.instance.rates,
                  builder: (context, rates, _) => ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('匯率'),
                    subtitle: Text(
                      rates.isFallback
                          ? '使用預設匯率（尚未取得線上匯率）\n${AppConfig.exchangeRateAttribution}'
                          : 'USD ${rates.twdPerUnit['USD']!.toStringAsFixed(2)}、'
                                'JPY ${rates.twdPerUnit['JPY']!.toStringAsFixed(4)}，'
                                '更新於 ${DateFormat('yyyy/MM/dd HH:mm').format(rates.updatedAt!)}\n'
                                '${AppConfig.exchangeRateAttribution}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: '更新匯率',
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshRates,
                    ),
                  ),
                ),
                const PrivacyLink(asListTile: true),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('登出'),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    await _auth.signOut();
                    navigator.popUntil((route) => route.isFirst);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('刪除帳號', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('永久刪除帳號與所有雲端資料'),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 含單一輸入框的對話框。控制器由自己管理，避免關閉動畫期間被提早釋放。
class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.confirmLabel,
    this.message,
    this.label,
    this.initialText = '',
    this.maxLength,
    this.obscure = false,
    this.destructive = false,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final String? label;
  final String initialText;
  final int? maxLength;
  final bool obscure;
  final bool destructive;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: widget.obscure,
            maxLength: widget.maxLength,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          style: widget.destructive
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.of(context).pop(
            widget.obscure ? _controller.text : _controller.text.trim(),
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
