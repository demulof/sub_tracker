import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';
import '../account/privacy_link.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService.instance;
  final _subscriptions = SubscriptionService.instance;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleView() => setState(() {
    _isLogin = !_isLogin;
    _error = '';
  });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = '';
    });

    // 登入前先記下訪客模式有幾筆資料，登入後詢問是否合併。
    final localCount = await _subscriptions.localCount();
    try {
      if (_isLogin) {
        await _auth.signIn(_emailController.text, _passwordController.text);
      } else {
        await _auth.register(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is AuthFailure ? e.message : '發生錯誤，請稍後再試。';
          _isLoading = false;
        });
      }
      return;
    }

    if (localCount > 0 && mounted) {
      await _askMerge(localCount);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _askMerge(int count) async {
    final merge = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('合併訪客資料'),
        content: Text(
          '這台裝置上有 $count 筆以訪客身分建立的訂閱。要把它們加入目前登入的帳號嗎？\n\n'
          '選擇「先不要」時，資料會保留在這台裝置上，登出後仍可看到。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('先不要'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('合併'),
          ),
        ],
      ),
    );
    if (merge != true) return;
    try {
      await _subscriptions.mergeLocalToCloud();
    } catch (e) {
      debugPrint('合併訪客資料失敗：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('合併失敗，資料仍保留在本機，下次登入時可再試一次。')),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    final emailError = AuthService.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _error = '請先在上方輸入註冊時使用的 Email。');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordReset(_emailController.text);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重設密碼'),
          content: const Text('如果這個 Email 已經註冊，你會收到一封重設密碼的信，請依信中連結設定新密碼。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('確定'),
            ),
          ],
        ),
      );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '關閉',
          icon: const Icon(Icons.close, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? '歡迎回來' : '建立新帳號',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? '登入後資料會同步到雲端' : '註冊後即可在不同裝置使用同一份資料',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      maxLength: AuthService.maxDisplayNameLength,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.nickname],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '請輸入顯示名稱' : null,
                      decoration: _decoration('顯示名稱', Icons.person_outline),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    validator: AuthService.validateEmail,
                    decoration: _decoration('電子郵件', Icons.email_outlined),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                    ],
                    onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                    validator: _isLogin
                        ? (v) => (v == null || v.isEmpty) ? '請輸入密碼' : null
                        : AuthService.validatePassword,
                    decoration: _decoration(
                      '密碼',
                      Icons.lock_outline,
                      helper: _isLogin ? null : '至少 8 碼，需包含英文字母與數字',
                      suffix: IconButton(
                        tooltip: _obscure ? '顯示密碼' : '隱藏密碼',
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _forgotPassword,
                        child: const Text('忘記密碼？'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF303F9F),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isLogin ? '登入' : '註冊',
                              style: const TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleView,
                    child: Text(
                      _isLogin ? '還沒有帳號？點此註冊' : '已經有帳號了？點此登入',
                      style: const TextStyle(color: Color(0xFF1A237E)),
                    ),
                  ),
                  if (!_isLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '註冊即表示你同意本 app 依隱私權政策處理你的帳號資料。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  const PrivacyLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? helper,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      prefixIcon: Icon(icon, color: const Color(0xFF303F9F)),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
      ),
    );
  }
}
