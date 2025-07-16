import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 從 Firebase User 建立 AppUser 物件
  Future<AppUser?> _userFromFirebaseUser(User? user) async {
    if (user == null) {
      return null;
    }
    // 從 Firestore 獲取使用者資料
    DocumentSnapshot userData = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();
    if (userData.exists) {
      return AppUser(
        uid: user.uid,
        email: user.email!,
        displayName:
            (userData.data() as Map<String, dynamic>)['displayName'] ??
            user.email!.split('@')[0],
      );
    }
    // 如果 Firestore 中沒有資料，則使用預設值
    return AppUser(
      uid: user.uid,
      email: user.email!,
      displayName: user.displayName ?? user.email!.split('@')[0],
    );
  }

  // 監聽驗證狀態變化
  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncMap(_userFromFirebaseUser);
  }

  // 註冊
  Future<AppUser?> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return AppUser(uid: user.uid, email: email, displayName: displayName);
      }
      return null;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // 登入
  Future<AppUser?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await _userFromFirebaseUser(result.user);
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // 登出
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
