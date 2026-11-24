import 'package:flutter/material.dart';

import '../../services/exchange_rate_service.dart';
import '../../services/subscription_service.dart';
import '../../shared/billing.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/brand_icon.dart';
import '../account/account_page.dart';
import '../auth/app_user.dart';
import '../auth/auth_service.dart';
import '../auth/login_page.dart';
import '../statistics/statistics_page.dart';
import '../subscriptions/add_subscription_page.dart';

/// 兩個日期相差幾天（只看日期，不受時間與日光節約影響）。
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

Future<void> showSubscriptionEditor(
  BuildContext context, {
  Subscription? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: AddSubscriptionPage(existing: existing),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService.instance;
  late Stream<List<Subscription>> _subscriptions;
  late final Stream<AppUser?> _user;
  bool _isMonthlyView = true;

  @override
  void initState() {
    super.initState();
    _subscriptions = SubscriptionService.instance.watchSubscriptions();
    _user = _auth.user;
  }

  void _retry() => setState(() {
    _subscriptions = SubscriptionService.instance.watchSubscriptions();
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _user,
      initialData: _auth.currentUser,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: '新增訂閱',
            onPressed: () => showSubscriptionEditor(context),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onSecondary,
              size: 32,
            ),
          ),
          body: StreamBuilder<List<Subscription>>(
            stream: _subscriptions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildError();
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ValueListenableBuilder<ExchangeRates>(
                valueListenable: ExchangeRateService.instance.rates,
                builder: (context, rates, _) =>
                    _buildContent(context, user, snapshot.data!, rates),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('無法載入訂閱資料，請檢查網路連線。', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _retry, child: const Text('重試')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppUser? user,
    List<Subscription> subs,
    ExchangeRates rates,
  ) {
    final today = dateOnly(DateTime.now());
    final toTwd = rates.toTwd;

    final double current;
    final double previous;
    if (_isMonthlyView) {
      final start = monthStart(today);
      current = spendingInRange(subs, start, nextMonthStart(today), toTwd);
      final prevStart = DateTime(today.year, today.month - 1);
      previous = spendingInRange(subs, prevStart, start, toTwd);
    } else {
      current = spendingInRange(
        subs,
        DateTime(today.year),
        DateTime(today.year + 1),
        toTwd,
      );
      previous = spendingInRange(
        subs,
        DateTime(today.year - 1),
        DateTime(today.year),
        toTwd,
      );
    }

    final upcoming = <MapEntry<Subscription, DateTime>>[];
    for (final sub in subs) {
      final next = nextPaymentDate(sub, today);
      if (next != null && daysBetween(today, next) <= 30) {
        upcoming.add(MapEntry(sub, next));
      }
    }
    upcoming.sort((a, b) => a.value.compareTo(b.value));

    final active = subs.where((s) => !s.isEndedOn(today)).toList();
    final ended = subs.where((s) => s.isEndedOn(today)).toList();
    final usesForeignCurrency = subs.any((s) => s.currency != 'TWD');

    return CustomScrollView(
      slivers: [
        _buildAppBar(context, user),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user != null && !user.emailVerified)
                  _buildVerifyBanner(),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StatisticsPage(),
                    ),
                  ),
                  child: _buildTotalCard(current, current - previous),
                ),
                if (usesForeignCurrency)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      rates.isFallback
                          ? '外幣以預設匯率估算，連上網路後會自動更新。'
                          : '外幣已依最新匯率換算為新台幣。',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 24),
                _buildUpcoming(upcoming, today),
                const SizedBox(height: 24),
                _buildList('所有訂閱項目', active, rates, emptyHint: true),
                if (ended.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildList('已停止的訂閱', ended, rates, dimmed: true),
                ],
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, AppUser? user) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早安' : (hour < 18 ? '午安' : '晚安');
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(204),
      toolbarHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting，${user?.displayName ?? '訪客'}',
                    overflow: TextOverflow.ellipsis,
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
            ),
            user != null ? _buildUserMenu() : _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMenu() {
    return PopupMenuButton<int>(
      tooltip: '帳號選單',
      onSelected: (item) async {
        if (item == 0) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AccountPage()),
          );
        } else if (item == 1) {
          await _auth.signOut();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<int>(
          value: 0,
          child: Row(
            children: [
              Icon(Icons.manage_accounts_outlined, color: Colors.black87),
              SizedBox(width: 8),
              Text('帳號設定'),
            ],
          ),
        ),
        PopupMenuItem<int>(
          value: 1,
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

  Widget _buildLoginButton() {
    return Tooltip(
      message: '登入或註冊',
      child: GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const LoginPage())),
        child: const CircleAvatar(
          backgroundColor: Color(0xFFE0E0E0),
          child: Icon(Icons.person_outline, color: Color(0xFF757575)),
        ),
      ),
    );
  }

  Widget _buildVerifyBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('請到信箱點擊驗證連結，完成 Email 驗證。')),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _auth.resendVerificationEmail();
                messenger.showSnackBar(
                  const SnackBar(content: Text('驗證信已寄出。')),
                );
              } on AuthFailure catch (e) {
                messenger.showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: const Text('重寄'),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(double total, double diff) {
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
                      _toggleText('月', _isMonthlyView),
                      const Text(' / ', style: TextStyle(color: Colors.white54)),
                      _toggleText('年', !_isMonthlyView),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatTwd(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            diff.round() == 0
                ? '與${_isMonthlyView ? '上月' : '去年'}相同'
                : '比${_isMonthlyView ? '上月' : '去年'}${diff > 0 ? '多' : '少'} ${formatTwd(diff.abs())}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 2),
          const Text(
            '含本期尚未扣款的預定款項',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _toggleText(String text, bool selected) => Text(
    text,
    style: TextStyle(
      color: selected ? Colors.white : Colors.white54,
      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
    ),
  );

  Widget _buildUpcoming(
    List<MapEntry<Subscription, DateTime>> upcoming,
    DateTime today,
  ) {
    if (upcoming.isEmpty) return const SizedBox.shrink();
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
            itemCount: upcoming.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final entry = upcoming[index];
              return _buildUpcomingCard(
                entry.key,
                daysBetween(today, entry.value),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(Subscription sub, int days) {
    final Color color = days <= 3
        ? Colors.red
        : (days <= 14 ? Colors.orange : Colors.green);
    return InkWell(
      onTap: () => showSubscriptionEditor(context, existing: sub),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 170,
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
                BrandIcon(name: sub.name, color: sub.brandColor, size: 40),
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
                        formatAmount(sub.amount, sub.currency),
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  days == 0 ? '今天付款' : '$days 天後付款',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    String title,
    List<Subscription> subs,
    ExchangeRates rates, {
    bool dimmed = false,
    bool emptyHint = false,
  }) {
    if (subs.isEmpty) {
      if (!emptyHint) return const SizedBox.shrink();
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
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
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: dimmed ? Colors.grey[600] : null,
          ),
        ),
        const SizedBox(height: 16),
        for (final sub in subs) ...[
          _buildListItem(sub, rates, dimmed),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildListItem(Subscription sub, ExchangeRates rates, bool dimmed) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showSubscriptionEditor(context, existing: sub),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BrandIcon(
                name: sub.name,
                color: sub.brandColor,
                size: 48,
                dimmed: dimmed,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: dimmed ? Colors.grey[600] : null,
                      ),
                    ),
                    Text(
                      dimmed && sub.endDate != null
                          ? '${formatDate(sub.endDate!)} 起停止'
                          : sub.plan,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(sub.amount, sub.currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: dimmed ? Colors.grey[600] : const Color(0xFF1A237E),
                    ),
                  ),
                  Text(
                    sub.currency == 'TWD'
                        ? sub.cycle.shortLabel
                        : '≈ ${formatTwd(rates.toTwd(sub.amount, sub.currency))} ${sub.cycle.shortLabel}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
