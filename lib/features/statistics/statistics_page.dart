import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/subscription_service.dart';
import '../../shared/billing.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/brand_icon.dart';
import '../../shared/widgets/custom_month_picker.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final Stream<List<Subscription>> _subscriptions;
  DateTime _selectedMonth = monthStart(DateTime.now());
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _subscriptions = SubscriptionService.instance.watchSubscriptions();
  }

  Future<void> _selectMonth(List<Subscription> subs) async {
    if (subs.isEmpty) return;
    final earliest = subs
        .map((s) => s.firstPaymentDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final now = DateTime.now();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => CustomMonthPicker(
        initialDate: _selectedMonth,
        firstDate: earliest.isBefore(now) ? earliest : now,
        lastDate: DateTime(now.year, now.month + 12),
      ),
    );
    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = monthStart(picked);
        _touchedIndex = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計分析', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: _subscriptions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('無法載入資料，請檢查網路連線。'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final subs = snapshot.data!;
          if (subs.isEmpty) {
            return const Center(
              child: Text(
                '沒有足夠的資料進行分析',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ValueListenableBuilder<ExchangeRates>(
            valueListenable: ExchangeRateService.instance.rates,
            builder: (context, rates, _) => _buildBody(subs, rates),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<Subscription> subs, ExchangeRates rates) {
    final toTwd = rates.toTwd;
    final start = _selectedMonth;
    final end = nextMonthStart(start);
    final prevStart = DateTime(start.year, start.month - 1);

    final charged = spendingInRange(subs, start, end, toTwd);
    final prevCharged = spendingInRange(subs, prevStart, start, toTwd);
    final byCategory = monthlyCostByCategory(subs, start, toTwd);
    final monthlyTotal = byCategory.values.fold(0.0, (a, b) => a + b);

    final lifetime = subs
        .map((s) => MapEntry(s, lifetimeSpending(s, end, toTwd)))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(subs, charged, charged - prevCharged, monthlyTotal),
          const SizedBox(height: 32),
          _buildCategorySection(byCategory, monthlyTotal),
          const SizedBox(height: 32),
          _sectionTitle('累計支出（至 ${DateFormat('yyyy年M月').format(start)} 底）'),
          const SizedBox(height: 16),
          if (lifetime.isEmpty)
            Text('這個月份之前還沒有扣款紀錄。', style: TextStyle(color: Colors.grey[600]))
          else
            for (final e in lifetime) _buildLifetimeItem(e.key, e.value),
          const SizedBox(height: 16),
          Text(
            rates.isFallback
                ? '外幣以預設匯率估算（尚未取得線上匯率）。'
                : '外幣依 ${DateFormat('yyyy/MM/dd HH:mm').format(rates.updatedAt!)} 的匯率換算，'
                      '歷史金額同樣以目前匯率計算。',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            AppConfig.exchangeRateAttribution,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.grey.withAlpha(26), spreadRadius: 2, blurRadius: 10),
    ],
  );

  Widget _buildSummary(
    List<Subscription> subs,
    double charged,
    double diff,
    double monthlyTotal,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    // 支出增加用紅色、減少用綠色。
    final diffColor = diff.round() == 0
        ? Colors.grey[700]!
        : (diff > 0 ? Colors.red[600]! : Colors.green[600]!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('總覽'),
            ActionChip(
              avatar: Icon(Icons.calendar_today, size: 16, color: primary),
              label: Text(
                DateFormat('yyyy年 M月').format(_selectedMonth),
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _selectMonth(subs),
              backgroundColor: primary.withAlpha(30),
              shape: StadiumBorder(side: BorderSide(color: primary.withAlpha(100))),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('當月扣款', formatTwd(charged), const Color(0xFF1A237E)),
              _summaryItem(
                '與上月比較',
                '${diff >= 0 ? '+' : '-'} ${formatTwd(diff.abs())}',
                diffColor,
              ),
              _summaryItem('每月平均成本', formatTwd(monthlyTotal), const Color(0xFF1A237E)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Flexible(
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    Map<SubscriptionCategory, double> data,
    double total,
  ) {
    // 依分類定義的順序排列，顏色固定跟著分類走。
    final entries = SubscriptionCategory.values
        .where((c) => (data[c] ?? 0) > 0)
        .map((c) => MapEntry(c, data[c]!))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('支出分類'),
        const SizedBox(height: 4),
        Text(
          '以當月訂閱中的項目，換算每月平均成本',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: _cardDecoration,
          child: entries.isEmpty
              ? const Center(child: Text('這個月份沒有訂閱中的項目'))
              : Column(
                  children: [
                    SizedBox(
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  final index =
                                      (!event.isInterestedForInteractions ||
                                          response?.touchedSection == null)
                                      ? -1
                                      : response!.touchedSection!.touchedSectionIndex;
                                  if (index != _touchedIndex) {
                                    setState(() => _touchedIndex = index);
                                  }
                                },
                              ),
                              borderData: FlBorderData(show: false),
                              sectionsSpace: 4,
                              centerSpaceRadius: 65,
                              sections: [
                                for (var i = 0; i < entries.length; i++)
                                  PieChartSectionData(
                                    color: entries[i].key.color,
                                    value: entries[i].value,
                                    showTitle: false,
                                    radius: i == _touchedIndex ? 25 : 20,
                                  ),
                              ],
                            ),
                          ),
                          if (_touchedIndex >= 0 && _touchedIndex < entries.length)
                            _buildCenterInfo(entries[_touchedIndex], total),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final e in entries)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(width: 12, height: 12, color: e.key.color),
                              const SizedBox(width: 8),
                              Text('${e.key.displayName} ${formatTwd(e.value)}'),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCenterInfo(MapEntry<SubscriptionCategory, double> entry, double total) {
    final percentage = total == 0 ? '0' : (entry.value / total * 100).toStringAsFixed(1);
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
            entry.key.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(formatTwd(entry.value), style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(
            '$percentage%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeItem(Subscription sub, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          BrandIcon(name: sub.name, color: sub.brandColor, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              sub.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            formatTwd(amount),
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
