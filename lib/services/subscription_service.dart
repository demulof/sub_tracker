// =================================================================
// 檔案: lib/services/subscription_service.dart
// (此檔案已更新，加入了檢查本機資料的功能)
// =================================================================
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../shared/models/subscription.dart';

class SubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _localSubscriptionsKey = 'local_subscriptions';

  // 取得訂閱列表的 Stream
  Stream<List<Subscription>> getSubscriptions() {
    final user = _auth.currentUser;

    if (user != null) {
      // 已登入：從 Firestore 讀取
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Subscription.fromJson(doc.data()))
                .toList(),
          );
    } else {
      // 訪客：從本機讀取
      // 因為 shared_preferences 不是響應式的，我們需要一個手動刷新的方式
      // 這裡我們回傳一個基於 Future 的 Stream，它只會觸發一次
      return Stream.fromFuture(_getLocalSubscriptions());
    }
  }

  // 新增訂閱
  Future<void> addSubscription(Subscription subscription) async {
    final user = _auth.currentUser;
    // 使用傳入的 ID 或產生一個新的
    final subscriptionWithId = Subscription(
      id: subscription.id.isEmpty ? const Uuid().v4() : subscription.id,
      name: subscription.name,
      plan: subscription.plan,
      amount: subscription.amount,
      currency: subscription.currency,
      cycle: subscription.cycle,
      firstPaymentDate: subscription.firstPaymentDate,
      brandColor: subscription.brandColor,
      category: subscription.category,
    );

    if (user != null) {
      // 已登入：存入 Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(subscriptionWithId.id)
          .set(subscriptionWithId.toJson());
    } else {
      // 訪客：存入本機
      final localSubs = await _getLocalSubscriptions();
      localSubs.add(subscriptionWithId);
      await _saveLocalSubscriptions(localSubs);
    }
  }

  // 從本機讀取資料
  Future<List<Subscription>> _getLocalSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_localSubscriptionsKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        return jsonList
            .map(
              (jsonItem) =>
                  Subscription.fromJson(jsonItem as Map<String, dynamic>),
            )
            .toList();
      } catch (e) {
        print('Error decoding local subscriptions: $e');
        return [];
      }
    }
    return [];
  }

  // 儲存資料到本機
  Future<void> _saveLocalSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    // 將 firstPaymentDate 轉為 ISO 8601 字串以符合 JSON 標準
    List<Map<String, dynamic>> listToSave = subscriptions.map((s) {
      var json = s.toJson();
      json['firstPaymentDate'] = s.firstPaymentDate.toIso8601String();
      return json;
    }).toList();

    final jsonString = json.encode(listToSave);
    await prefs.setString(_localSubscriptionsKey, jsonString);
  }

  // --- [新增] 檢查是否存在本機資料 ---
  Future<bool> hasLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_localSubscriptionsKey);
    return jsonString != null && jsonString.isNotEmpty;
  }

  // 合併本機資料到雲端
  Future<void> mergeLocalDataToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final localSubs = await _getLocalSubscriptions();
    if (localSubs.isEmpty) return;

    final batch = _firestore.batch();
    for (var sub in localSubs) {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('subscriptions')
          .doc(sub.id);
      batch.set(docRef, sub.toJson());
    }
    await batch.commit();
    // 合併後清除本機資料
    await (await SharedPreferences.getInstance()).remove(
      _localSubscriptionsKey,
    );
  }
}
