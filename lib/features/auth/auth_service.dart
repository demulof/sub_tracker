import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../services/subscription_service.dart';
import 'app_user.dart';

/// 給畫面顯示的錯誤，訊息已轉成中文。
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const int maxDisplayNameLength = 30;
  static const int minPasswordLength = 8;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    final email = user.email ?? '';
    final name = user.displayName;
    return AppUser(
      uid: user.uid,
      email: email,
      displayName: (name != null && name.isNotEmpty)
          ? name
          : (email.contains('@') ? email.split('@').first : '使用者'),
      emailVerified: user.emailVerified,
    );
  }

  /// 使用者狀態（含顯示名稱變更）。
  Stream<AppUser?> get user => _auth.userChanges().map(_toAppUser);

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  /// 密碼規則：至少 8 碼，且同時包含英文字母與數字。回傳 null 表示通過。
  static String? validatePassword(String? value) {
    final v = value ?? '';
    if (v.length < minPasswordLength) return '密碼至少需 $minPasswordLength 個字元';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return '密碼需同時包含英文字母與數字';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return '請輸入有效的 Email';
    }
    return null;
  }

  Future<AppUser> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user!;
      final name = displayName.trim();
      await user.updateDisplayName(name);
      // 只存必要欄位；Email 已由 Firebase Auth 保管，不在 Firestore 重複儲存。
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        // 帳號本身已建立成功，個人資料文件只是備份，失敗不擋住註冊流程。
        debugPrint('建立使用者資料失敗：${e.code}');
      }
      try {
        await user.sendEmailVerification();
      } catch (e) {
        debugPrint('寄送驗證信失敗：$e');
      }
      await user.reload();
      return _toAppUser(_auth.currentUser)!;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<AppUser> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _toAppUser(result.user)!;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  /// 寄送重設密碼信。為避免洩漏「此 Email 是否已註冊」，成功與否都顯示相同訊息。
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return;
      throw _map(e);
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  Future<void> updateDisplayName(String name) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final trimmed = name.trim();
    try {
      await user.updateDisplayName(trimmed);
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
    // 以 Firebase Auth 的顯示名稱為準；Firestore 只是備份，同步失敗不影響使用。
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': trimmed,
      });
    } on FirebaseException catch (e) {
      debugPrint('同步顯示名稱到 Firestore 失敗：${e.code}');
    }
  }

  Future<void> signOut() => _auth.signOut();

  /// 永久刪除帳號：先重新驗證密碼，再刪除雲端資料，最後刪除帳號本身。
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthFailure('目前沒有登入的帳號。');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await SubscriptionService.instance.deleteAllCloudData(user.uid);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    } on FirebaseException catch (e) {
      debugPrint('刪除雲端資料失敗：${e.code}');
      throw const AuthFailure('刪除資料時發生錯誤，帳號尚未刪除，請確認網路後再試一次。');
    }
  }

  AuthFailure _map(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException: ${e.code}');
    final message = switch (e.code) {
      'invalid-email' => 'Email 格式不正確。',
      'user-disabled' => '此帳號已被停用。',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' => 'Email 或密碼錯誤。',
      'email-already-in-use' => '此 Email 已經註冊過，請直接登入。',
      'weak-password' => '密碼強度不足，請使用更長且包含英數字的密碼。',
      'password-does-not-meet-requirements' => '密碼不符合安全規則，請使用更長且包含英數字的密碼。',
      'too-many-requests' => '嘗試次數過多，請稍後再試。',
      'network-request-failed' => '網路連線失敗，請檢查網路後再試。',
      'requires-recent-login' => '為了安全，請重新輸入密碼後再試一次。',
      'operation-not-allowed' => '目前未開放此登入方式。',
      _ => '發生錯誤，請稍後再試。',
    };
    return AuthFailure(message, code: e.code);
  }
}
