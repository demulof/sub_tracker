import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../shared/models/subscription.dart';

/// 訂閱資料的存取層。
/// - 已登入：資料存在 Firestore `users/{uid}/subscriptions/{id}`。
/// - 訪客：資料存在本機 shared_preferences，變更時立即通知畫面更新。
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const _localKey = 'local_subscriptions';
  static const _batchLimit = 400; // Firestore 單一批次上限 500，保留餘裕。

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StreamController<List<Subscription>> _localChanges =
      StreamController<List<Subscription>>.broadcast();

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('subscriptions');

  // ---------------------------------------------------------------- 讀取

  /// 訂閱列表的即時資料流。登入或登出時會自動切換資料來源。
  Stream<List<Subscription>> watchSubscriptions() {
    late final StreamController<List<Subscription>> controller;
    StreamSubscription<User?>? authSub;
    StreamSubscription<List<Subscription>>? dataSub;
    String? currentUid;
    var started = false;

    void switchTo(User? user) {
      if (started && user?.uid == currentUid) return;
      started = true;
      currentUid = user?.uid;
      dataSub?.cancel();
      final source = user == null ? _watchLocal() : _watchRemote(user.uid);
      dataSub = source.listen(
        controller.add,
        onError: (Object e, StackTrace st) {
          // 登出或刪除帳號的瞬間，舊的雲端監聽可能先收到權限錯誤，
          // 這時資料來源即將切換，不需要顯示錯誤畫面。
          if (e is FirebaseException &&
              e.code == 'permission-denied' &&
              _auth.currentUser?.uid != user?.uid) {
            return;
          }
          controller.addError(e, st);
        },
      );
    }

    controller = StreamController<List<Subscription>>(
      onListen: () {
        authSub = _auth.authStateChanges().listen(
          switchTo,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await dataSub?.cancel();
        await authSub?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<List<Subscription>> _watchRemote(String uid) {
    return _collection(uid).snapshots().map((snapshot) {
      final list = <Subscription>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(Subscription.fromMap(doc.data()));
        } catch (e) {
          debugPrint('略過格式錯誤的訂閱資料 ${doc.id}：$e');
        }
      }
      return _sorted(list);
    });
  }

  Stream<List<Subscription>> _watchLocal() async* {
    yield _sorted(await _loadLocal());
    yield* _localChanges.stream.map(_sorted);
  }

  List<Subscription> _sorted(List<Subscription> list) =>
      list..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // ---------------------------------------------------------------- 寫入

  /// 新增或更新訂閱。id 為空字串時視為新增。
  Future<Subscription> saveSubscription(Subscription subscription) async {
    final sub = subscription.id.isEmpty
        ? subscription.copyWith(id: const Uuid().v4())
        : subscription;
    final user = _auth.currentUser;
    if (user != null) {
      await _awaitWrite(_collection(user.uid).doc(sub.id).set(sub.toFirestore()));
    } else {
      final list = await _loadLocal();
      final index = list.indexWhere((s) => s.id == sub.id);
      if (index >= 0) {
        list[index] = sub;
      } else {
        list.add(sub);
      }
      await _saveLocal(list);
    }
    return sub;
  }

  Future<void> deleteSubscription(String id) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _awaitWrite(_collection(user.uid).doc(id).delete());
    } else {
      final list = await _loadLocal()
        ..removeWhere((s) => s.id == id);
      await _saveLocal(list);
    }
  }

  /// 離線時 Firestore 會先寫入本機快取，等連線後才同步，Future 要到伺服器確認才會完成。
  /// 這裡最多等 8 秒：逾時視為「已排入同步」，避免畫面卡在儲存中；
  /// 伺服器拒絕（例如違反安全規則）等錯誤仍會在時限內拋出。
  Future<void> _awaitWrite(Future<void> write) async {
    try {
      await write.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('寫入尚未得到伺服器確認，將在連線後自動同步');
    }
  }

  // ---------------------------------------------------------------- 本機資料

  Future<List<Subscription>> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      final list = <Subscription>[];
      for (final item in decoded) {
        try {
          list.add(Subscription.fromMap(Map<String, dynamic>.from(item as Map)));
        } catch (e) {
          debugPrint('略過格式錯誤的本機訂閱資料：$e');
        }
      }
      return list;
    } catch (e) {
      debugPrint('讀取本機訂閱資料失敗：$e');
      return [];
    }
  }

  Future<void> _saveLocal(List<Subscription> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localKey,
      json.encode(list.map((s) => s.toLocalJson()).toList()),
    );
    _localChanges.add(List.of(list));
  }

  Future<int> localCount() async => (await _loadLocal()).length;

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey);
    _localChanges.add(const []);
  }

  /// 把訪客模式的本機資料上傳到目前登入的帳號，成功後清除本機資料。
  /// 以相同 id 寫入，重複執行不會產生重複資料。
  Future<void> mergeLocalToCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final local = await _loadLocal();
    if (local.isEmpty) return;
    for (var i = 0; i < local.length; i += _batchLimit) {
      final batch = _firestore.batch();
      for (final sub in local.skip(i).take(_batchLimit)) {
        batch.set(_collection(user.uid).doc(sub.id), sub.toFirestore());
      }
      await batch.commit();
    }
    await clearLocal();
  }

  /// 刪除帳號時使用：清除該使用者在 Firestore 的所有資料。
  Future<void> deleteAllCloudData(String uid) async {
    while (true) {
      final snapshot = await _collection(uid).limit(_batchLimit).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _firestore.collection('users').doc(uid).delete();
  }
}
