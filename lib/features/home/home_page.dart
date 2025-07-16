import 'package:flutter/material.dart';
import 'dart:math';

import '../auth/auth_service.dart';
import '../auth/app_user.dart';
import '../auth/login_page.dart';
import '../subscriptions/add_subscription_page.dart';
// --- [修改] 移除多餘的 import，因為 mock_data.dart 已引入 Subscription 模型 ---
// import '../../shared/models/subscription.dart';
import '../../shared/mock_data.dart';
import '../../shared/models/subscription.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService();
  bool _isMonthlyView = true;

  // 開啟新增訂閱頁面的方法
  void _showAddSubscriptionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return const AddSubscriptionPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _auth.user,
      builder: (context, snapshot) {
        final AppUser? currentUser = snapshot.data;

        final upcomingPayments =
            mockSubscriptions
                .where((s) => s.nextPaymentDate.isAfter(DateTime.now()))
                .toList()
              ..sort((a, b) => a.nextPaymentDate.compareTo(b.nextPaymentDate));

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddSubscriptionSheet,
            backgroundColor: const Color(0xFFFFC107),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: const Icon(Icons.add, color: Color(0xFF1A237E), size: 32),
          ),
          body: CustomScrollView(
            slivers: [
              _buildAppBar(context, currentUser),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildTotalSpendingCard(),
                      const SizedBox(height: 24),
                      _buildUpcomingPaymentsSection(upcomingPayments),
                      const SizedBox(height: 24),
                      _buildAllSubscriptionsSection(),
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
      backgroundColor: const Color(0xFFF8FAFC).withAlpha(204),
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

  Widget _buildTotalSpendingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF303F9F)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF303F9F).withAlpha(102),
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
            _isMonthlyView ? 'NT\$ 1,318' : 'NT\$ 3,508',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isMonthlyView ? '比上個月多 NT\$ 150' : '比去年少 NT\$ 500',
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

  Widget _buildUpcomingPaymentsSection(List<Subscription> upcomingPayments) {
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
            itemCount: min(3, upcomingPayments.length),
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _buildUpcomingPaymentCard(upcomingPayments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingPaymentCard(Subscription sub) {
    final daysUntilPayment = sub.nextPaymentDate
        .difference(DateTime.now())
        .inDays;
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

  Widget _buildAllSubscriptionsSection() {
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
          itemCount: mockSubscriptions.length,
          itemBuilder: (context, index) {
            return _buildSubscriptionListItem(mockSubscriptions[index]);
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
                'NT\$ ${sub.amount.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1A237E),
                ),
              ),
              Text(
                sub.cycle == BillingCycle.monthly ? '/ 月' : '/ 年',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
