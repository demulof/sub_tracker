// =================================================================
// 檔案: lib/features/home/home_page.dart
// (此檔案已更新，修正了型別錯誤並優化了訪客模式的刷新邏輯)
// =================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/app_user.dart';
import '../auth/login_page.dart';
import '../subscriptions/add_subscription_page.dart';
import '../statistics/statistics_page.dart';
import '../../services/subscription_service.dart';
import '../../shared/models/subscription.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isMonthlyView = true;

  // --- [修改] 用於管理數據流的變數 ---
  Stream<List<Subscription>>? _subscriptionStream;
  StreamSubscription<AppUser?>?
  _authSubscription; // <-- [修正] 型別從 User? 改為 AppUser?
  AppUser? _currentUser; // <-- [新增] 用於追蹤目前使用者狀態

  @override
  void initState() {
    super.initState();
    // 監聽使用者登入狀態的變化
    _authSubscription = _auth.user.listen((user) {
      // <-- [修正] 取得 user 物件
      // 當使用者登入或登出時，更新使用者狀態並重新建立訂閱數據的串流
      if (mounted) {
        setState(() {
          _currentUser = user; // <-- [新增] 更新目前使用者
          _subscriptionStream = _subscriptionService.getSubscriptions();
        });
      }
    });
    // 初始化第一次的數據串流
    _subscriptionStream = _subscriptionService.getSubscriptions();
  }

  @override
  void dispose() {
    // 記得取消監聽以避免記憶體洩漏
    _authSubscription?.cancel();
    super.dispose();
  }

  void _showAddSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          child: const AddSubscriptionPage(),
        );
      },
    ).then((_) {
      // 為了讓訪客模式在新增後能刷新，我們需要一個新的 Stream 事件
      // --- [修正] 判斷是否為訪客 (currentUser == null) ---
      if (_currentUser == null) {
        setState(() {
          // 重新觸發 Stream.fromFuture 以取得最新的本機資料
          _subscriptionStream = _subscriptionService.getSubscriptions();
        });
      }
    });
  }

  void _navigateToStatistics() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const StatisticsPage()));
  }

  DateTime _calculateNextPaymentDate(
    DateTime firstPayment,
    BillingCycle cycle,
  ) {
    DateTime now = DateTime.now();
    DateTime nextPayment = firstPayment;

    if (nextPayment.isAfter(now)) {
      return nextPayment;
    }

    switch (cycle) {
      case BillingCycle.monthly:
        while (nextPayment.isBefore(now)) {
          nextPayment = DateTime(
            nextPayment.year,
            nextPayment.month + 1,
            nextPayment.day,
          );
        }
        break;
      case BillingCycle.quarterly:
        while (nextPayment.isBefore(now)) {
          nextPayment = DateTime(
            nextPayment.year,
            nextPayment.month + 3,
            nextPayment.day,
          );
        }
        break;
      case BillingCycle.yearly:
        while (nextPayment.isBefore(now)) {
          nextPayment = DateTime(
            nextPayment.year + 1,
            nextPayment.month,
            nextPayment.day,
          );
        }
        break;
    }
    return nextPayment;
  }

  List<Subscription> _filterSubsForMonth(
    List<Subscription> allSubs,
    DateTime month,
  ) {
    return allSubs.where((sub) {
      final firstPayment = sub.firstPaymentDate;
      return firstPayment.year < month.year ||
          (firstPayment.year == month.year &&
              firstPayment.month <= month.month);
    }).toList();
  }

  double _calculateTotalSpending(List<Subscription> subs, bool isMonthly) {
    double total = 0;
    for (var sub in subs) {
      double monthlyAmount;
      switch (sub.cycle) {
        case BillingCycle.monthly:
          monthlyAmount = sub.amount;
          break;
        case BillingCycle.quarterly:
          monthlyAmount = sub.amount / 3;
          break;
        case BillingCycle.yearly:
          monthlyAmount = sub.amount / 12;
          break;
      }

      if (isMonthly) {
        total += monthlyAmount;
      } else {
        total += monthlyAmount * 12;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Subscription>>(
      stream: _subscriptionStream,
      builder: (context, subscriptionSnapshot) {
        if (subscriptionSnapshot.connectionState == ConnectionState.waiting &&
            (subscriptionSnapshot.data == null ||
                subscriptionSnapshot.data!.isEmpty)) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final subscriptions = subscriptionSnapshot.data ?? [];
        final now = DateTime.now();

        final upcomingPayments =
            subscriptions
                .map((sub) {
                  return MapEntry(
                    sub,
                    _calculateNextPaymentDate(sub.firstPaymentDate, sub.cycle),
                  );
                })
                .where((entry) {
                  return entry.value.isAfter(now) &&
                      entry.value.difference(now).inDays <= 30;
                })
                .toList()
              ..sort((a, b) => a.value.compareTo(b.value));

        double currentSpending;
        double previousSpending;

        if (_isMonthlyView) {
          final currentMonthSubs = _filterSubsForMonth(subscriptions, now);
          currentSpending = _calculateTotalSpending(currentMonthSubs, true);

          final lastMonth = DateTime(now.year, now.month - 1);
          final lastMonthSubs = _filterSubsForMonth(subscriptions, lastMonth);
          previousSpending = _calculateTotalSpending(lastMonthSubs, true);
        } else {
          final currentYearSubs = _filterSubsForMonth(
            subscriptions,
            DateTime(now.year, 12),
          );
          currentSpending = _calculateTotalSpending(currentYearSubs, false);

          final lastYear = DateTime(now.year - 1, 12);
          final lastYearSubs = _filterSubsForMonth(subscriptions, lastYear);
          previousSpending = _calculateTotalSpending(lastYearSubs, false);
        }

        final difference = currentSpending - previousSpending;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddSubscriptionSheet,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onSecondary,
              size: 32,
            ),
          ),
          body: CustomScrollView(
            slivers: [
              // AppBar 會使用最新的 _currentUser 狀態
              _buildAppBar(context, _currentUser),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _navigateToStatistics,
                        child: _buildTotalSpendingCard(
                          currentSpending,
                          difference,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildUpcomingPaymentsSection(upcomingPayments),
                      const SizedBox(height: 24),
                      _buildAllSubscriptionsSection(subscriptions),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, AppUser? user) {
    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return '早安';
      if (hour < 18) return '午安';
      return '晚安';
    }

    final String displayName = user?.displayName ?? '訪客';

    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(204),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${getGreeting()}，$displayName',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                Text(
                  '你的儀表板',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1A237E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            user != null ? _buildUserMenu(context) : _buildLoginButton(context),
          ],
        ),
      ),
      toolbarHeight: 80,
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return PopupMenuButton<int>(
      onSelected: (item) async {
        if (item == 0) {
          await _auth.signOut();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.black87),
              SizedBox(width: 8),
              Text('登出'),
            ],
          ),
        ),
      ],
      child: const CircleAvatar(
        backgroundColor: Color(0xFFE0E0E0),
        child: Icon(Icons.person, color: Color(0xFF757575)),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const LoginPage()));
      },
      child: const CircleAvatar(
        backgroundColor: Color(0xFFE0E0E0),
        child: Icon(Icons.person_outline, color: Color(0xFF757575)),
      ),
    );
  }

  Widget _buildTotalSpendingCard(double total, double diff) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A237E),
            Theme.of(context).colorScheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(102),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isMonthlyView ? '本月總支出' : '本年總支出',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isMonthlyView = !_isMonthlyView),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '月',
                        style: TextStyle(
                          color: _isMonthlyView ? Colors.white : Colors.white54,
                          fontWeight: _isMonthlyView
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const Text(
                        ' / ',
                        style: TextStyle(color: Colors.white54),
                      ),
                      Text(
                        '年',
                        style: TextStyle(
                          color: !_isMonthlyView
                              ? Colors.white
                              : Colors.white54,
                          fontWeight: !_isMonthlyView
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'NT\$ ${total.toInt()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '比上期${diff >= 0 ? "多" : "少"} NT\$ ${diff.abs().toInt()}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandIcon(Subscription sub, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: sub.brandColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          sub.name.substring(0, 1),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.55,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingPaymentsSection(
    List<MapEntry<Subscription, DateTime>> upcomingPayments,
  ) {
    if (upcomingPayments.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '即將付款',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            itemCount: upcomingPayments.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final entry = upcomingPayments[index];
              return _buildUpcomingPaymentCard(entry.key, entry.value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingPaymentCard(Subscription sub, DateTime nextPaymentDate) {
    final daysUntilPayment = nextPaymentDate.difference(DateTime.now()).inDays;
    final Color indicatorColor;
    if (daysUntilPayment <= 3) {
      indicatorColor = Colors.red;
    } else if (daysUntilPayment <= 14) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.green;
    }

    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBrandIcon(sub, 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'NT\$ ${sub.amount.toInt()}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: indicatorColor.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$daysUntilPayment 天後付款',
                style: TextStyle(
                  color: indicatorColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllSubscriptionsSection(List<Subscription> subscriptions) {
    if (subscriptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.0),
          child: Text(
            '點擊右下角按鈕新增您的第一筆訂閱',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '所有訂閱項目',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subscriptions.length,
          itemBuilder: (context, index) {
            return _buildSubscriptionListItem(subscriptions[index]);
          },
          separatorBuilder: (context, index) => const SizedBox(height: 12),
        ),
      ],
    );
  }

  Widget _buildSubscriptionListItem(Subscription sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildBrandIcon(sub, 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(sub.plan, style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${sub.currency} ${sub.amount.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1A237E),
                ),
              ),
              Text(
                sub.cycle == BillingCycle.monthly
                    ? '/ 月'
                    : (sub.cycle == BillingCycle.quarterly ? '/ 季' : '/ 年'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
