// =================================================================
// 檔案: lib/features/statistics/statistics_page.dart
// (此檔案已更新，重構了數據流以徹底解決畫面閃爍問題)
// =================================================================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/subscription_service.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/custom_month_picker.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month);
  int touchedIndex = -1;

  // --- [新增] 用於管理數據流的變數 ---
  Stream<List<Subscription>>? _subscriptionStream;

  @override
  void initState() {
    super.initState();
    // --- [修改] 在 initState 中初始化數據流 ---
    // 這樣可以確保 StreamBuilder 只會訂閱一次數據流
    _subscriptionStream = _subscriptionService.getSubscriptions();
  }

  final List<Color> _categoryColors = [
    const Color(0xFF3B82F6), // 影視
    const Color(0xFFF59E0B), // 音樂
    const Color(0xFF6366F1), // AI 工具
    const Color(0xFF10B981), // 生產力
    Colors.grey, // 其他
  ];

  Future<void> _selectMonth(
    BuildContext context,
    List<Subscription> allSubscriptions,
  ) async {
    if (allSubscriptions.isEmpty) return;

    final firstDate = allSubscriptions
        .reduce(
          (a, b) => a.firstPaymentDate.isBefore(b.firstPaymentDate) ? a : b,
        )
        .firstPaymentDate;

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return CustomMonthPicker(
          initialDate: _selectedDate,
          firstDate: firstDate,
          lastDate: DateTime.now(),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<Subscription> _filterSubsForMonth(
    List<Subscription> allSubs,
    DateTime date,
  ) {
    return allSubs.where((sub) {
      final firstPayment = sub.firstPaymentDate;
      return firstPayment.year < date.year ||
          (firstPayment.year == date.year && firstPayment.month <= date.month);
    }).toList();
  }

  double _calculateMonthlySpending(List<Subscription> activeSubs) {
    double total = 0;
    for (var sub in activeSubs) {
      switch (sub.cycle) {
        case BillingCycle.monthly:
          total += sub.amount;
          break;
        case BillingCycle.quarterly:
          total += sub.amount / 3;
          break;
        case BillingCycle.yearly:
          total += sub.amount / 12;
          break;
      }
    }
    return total;
  }

  Map<String, double> _calculateCategorySpending(
    List<Subscription> activeSubs,
  ) {
    Map<String, double> categorySpending = {};
    for (var sub in activeSubs) {
      final key = sub.category.displayName;
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
      categorySpending.update(
        key,
        (value) => value + monthlyAmount,
        ifAbsent: () => monthlyAmount,
      );
    }
    return categorySpending;
  }

  double _calculateLifetimeSpending(Subscription sub, DateTime untilDate) {
    DateTime currentDate = sub.firstPaymentDate;
    double total = 0;

    if (currentDate.isAfter(untilDate)) {
      return 0;
    }

    while (currentDate.isBefore(untilDate) ||
        currentDate.isAtSameMomentAs(untilDate)) {
      total += sub.amount;
      switch (sub.cycle) {
        case BillingCycle.monthly:
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case BillingCycle.quarterly:
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 3,
            currentDate.day,
          );
          break;
        case BillingCycle.yearly:
          currentDate = DateTime(
            currentDate.year + 1,
            currentDate.month,
            currentDate.day,
          );
          break;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '統計分析',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: _subscriptionStream, // <-- [修改] 使用 state 中的 stream
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                '沒有足夠的資料進行分析',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final allSubscriptions = snapshot.data!;
          final activeSubsForMonth = _filterSubsForMonth(
            allSubscriptions,
            _selectedDate,
          );
          final categoryData = _calculateCategorySpending(activeSubsForMonth);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCoreSummary(allSubscriptions, activeSubsForMonth),
                const SizedBox(height: 32),
                _buildCategorySection(categoryData),
                const SizedBox(height: 32),
                _buildLifetimeSpendingSection(allSubscriptions),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoreSummary(
    List<Subscription> allSubs,
    List<Subscription> activeSubs,
  ) {
    final currentMonthSpending = _calculateMonthlySpending(activeSubs);

    final prevMonth = DateTime(_selectedDate.year, _selectedDate.month - 1);
    final prevMonthActiveSubs = _filterSubsForMonth(allSubs, prevMonth);
    final prevMonthSpending = _calculateMonthlySpending(prevMonthActiveSubs);
    final comparison = currentMonthSpending - prevMonthSpending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '總覽',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            ActionChip(
              avatar: Icon(
                Icons.calendar_today,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                DateFormat('yyyy年 M月', 'zh_TW').format(_selectedDate),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => _selectMonth(context, allSubs),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withAlpha(30),
              shape: StadiumBorder(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withAlpha(100),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(26),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('總支出', 'NT\$ ${currentMonthSpending.toInt()}'),
              _buildSummaryItem(
                '與前期比較',
                '${comparison >= 0 ? "+" : "-"} NT\$ ${comparison.abs().toInt()}',
                isPositive: comparison >= 0,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value, {
    bool isPositive = false,
  }) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green[600] : Colors.red[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(Map<String, double> categoryData) {
    final colors = _categoryColors;
    final dataEntries = categoryData.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '支出分類',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(26),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  if (touchedIndex != -1) {
                                    setState(() => touchedIndex = -1);
                                  }
                                  return;
                                }
                                if (touchedIndex !=
                                    pieTouchResponse
                                        .touchedSection!
                                        .touchedSectionIndex) {
                                  setState(
                                    () => touchedIndex = pieTouchResponse
                                        .touchedSection!
                                        .touchedSectionIndex,
                                  );
                                }
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 65,
                        sections: List.generate(dataEntries.length, (index) {
                          final isTouched = index == touchedIndex;
                          return PieChartSectionData(
                            color: colors[index % colors.length],
                            value: dataEntries[index].value,
                            showTitle: false,
                            radius: isTouched ? 25 : 20,
                          );
                        }),
                      ),
                    ),
                    if (touchedIndex != -1 && touchedIndex < dataEntries.length)
                      _buildCenterInfo(categoryData),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildLegend(categoryData),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCenterInfo(Map<String, double> categoryData) {
    final totalAmount = categoryData.values.reduce((a, b) => a + b);
    if (totalAmount == 0) return const SizedBox.shrink();

    final categoryName = categoryData.keys.elementAt(touchedIndex);
    final amount = categoryData.values.elementAt(touchedIndex);
    final percentage = (amount / totalAmount * 100).toStringAsFixed(1);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(13),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            categoryName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'NT\$ ${amount.toInt()}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, double> categoryData) {
    final colors = _categoryColors;
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(categoryData.length, (index) {
        return _buildCategoryIndicator(
          categoryData.keys.elementAt(index),
          colors[index % colors.length],
        );
      }),
    );
  }

  Widget _buildCategoryIndicator(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 8),
        Text(name),
      ],
    );
  }

  Widget _buildLifetimeSpendingSection(List<Subscription> allSubscriptions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '訂閱總支出',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allSubscriptions.length,
          itemBuilder: (context, index) {
            final sub = allSubscriptions[index];
            final total = _calculateLifetimeSpending(sub, _selectedDate);
            return _buildLifetimeSpendingItem(sub, total);
          },
        ),
      ],
    );
  }

  Widget _buildLifetimeSpendingItem(Subscription sub, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: sub.brandColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                sub.name.substring(0, 1),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              sub.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            'NT\$ ${amount.toInt()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }
}
