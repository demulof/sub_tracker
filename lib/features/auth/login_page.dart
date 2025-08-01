// =================================================================
// 檔案: lib/features/auth/login_page.dart
// (此檔案已更新，加入登入後自動合併本機資料的功能)
// =================================================================
import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _auth = AuthService();
  // --- [新增] 引入 SubscriptionService ---
  final SubscriptionService _subscriptionService = SubscriptionService();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  String _email = '';
  String _password = '';
  String _displayName = '';
  String _error = '';
  bool _isLoading = false;

  void _toggleView() {
    setState(() {
      _isLogin = !_isLogin;
      _error = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
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
                  _isLogin ? '登入以繼續管理您的訂閱' : '我們需要一些資訊來設定您的帳號',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                if (!_isLogin) ...[
                  TextFormField(
                    key: const ValueKey('displayName'),
                    validator: (val) => val!.isEmpty ? '請輸入顯示名稱' : null,
                    onChanged: (val) => setState(() => _displayName = val),
                    decoration: _buildInputDecoration(
                      '顯示名稱',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  key: const ValueKey('email'),
                  validator: (val) =>
                      !val!.contains('@') ? '請輸入有效的 Email' : null,
                  onChanged: (val) => setState(() => _email = val),
                  decoration: _buildInputDecoration(
                    '電子郵件',
                    Icons.email_outlined,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('password'),
                  validator: (val) => val!.length < 6 ? '密碼長度至少需 6 個字元' : null,
                  onChanged: (val) => setState(() => _password = val),
                  decoration: _buildInputDecoration('密碼', Icons.lock_outline),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _error,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          // --- [修改] 登入/註冊按鈕的邏輯 ---
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                                _error = '';
                              });

                              // 1. 先檢查本地是否有資料
                              final bool hadLocalData =
                                  await _subscriptionService.hasLocalData();

                              dynamic result;
                              if (_isLogin) {
                                result = await _auth.signInWithEmailAndPassword(
                                  _email,
                                  _password,
                                );
                              } else {
                                result = await _auth
                                    .registerWithEmailAndPassword(
                                      _email,
                                      _password,
                                      _displayName,
                                    );
                              }

                              if (result != null) {
                                // 2. 如果登入/註冊成功，且之前有本地資料，則觸發合併
                                if (hadLocalData) {
                                  // 在背景執行合併，不影響 UI
                                  _subscriptionService
                                      .mergeLocalDataToFirestore();
                                }
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                              } else if (mounted) {
                                // 3. 如果失敗，顯示錯誤訊息
                                setState(() {
                                  _error = '發生錯誤，請檢查您的資訊。';
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF303F9F),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isLogin ? '登入' : '註冊',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _toggleView,
                  child: Text(
                    _isLogin ? '還沒有帳號？點此註冊' : '已經有帳號了？點此登入',
                    style: const TextStyle(color: Color(0xFF1A237E)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF303F9F)),
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
