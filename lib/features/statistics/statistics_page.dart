// =================================================================
// 檔案: lib/features/statistics/statistics_page.dart
// (此檔案已更新，參照 HTML 範例重構了圓餅圖的視覺與互動)
// =================================================================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _isMonthlyView = true;
  int touchedIndex = -1;

  final List<Color> _categoryColors = [
    const Color(0xFF3B82F6), // 影視
    const Color(0xFFF59E0B), // 音樂
    const Color(0xFF6366F1), // AI 工具
    const Color(0xFF10B981), // 生產力
  ];

  final Map<String, double> _categoryData = {
    '影視': 589.5,
    '音樂': 328.5,
    'AI 工具': 266,
    '生產力': 134,
  };

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoreSummary(),
            const SizedBox(height: 32),
            _buildCategorySection(),
            const SizedBox(height: 32),
            _buildLifetimeSpendingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoreSummary() {
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
            ToggleButtons(
              isSelected: [_isMonthlyView, !_isMonthlyView],
              onPressed: (index) {
                setState(() {
                  _isMonthlyView = index == 0;
                });
              },
              borderRadius: BorderRadius.circular(8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('本月'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('本年'),
                ),
              ],
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
              _buildSummaryItem(
                '總支出',
                _isMonthlyView ? 'NT\$ 1,318' : 'NT\$ 15,816',
              ),
              _buildSummaryItem('與前期比較', '+ NT\$ 150', isPositive: true),
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
            color: isPositive ? Colors.green[600] : Colors.black87,
          ),
        ),
      ],
    );
  }

  // --- [修改] 重構整個支出分類區塊 ---
  Widget _buildCategorySection() {
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
              // 圖表區塊
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
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 4,
                        centerSpaceRadius: 65,
                        sections: _buildPieChartSections(),
                      ),
                    ),
                    // 自訂的互動提示
                    if (touchedIndex != -1) _buildCenterInfo(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 圖例區塊
              _buildLegend(),
            ],
          ),
        ),
      ],
    );
  }

  // --- [新增] 自訂的圖表中心提示資訊 ---
  Widget _buildCenterInfo() {
    final totalAmount = _categoryData.values.reduce((a, b) => a + b);
    final categoryName = _categoryData.keys.elementAt(touchedIndex);
    final amount = _categoryData.values.elementAt(touchedIndex);
    final percentage = (amount / totalAmount * 100).toStringAsFixed(1);

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
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

  // --- [新增] 圖例 Widget ---
  Widget _buildLegend() {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(_categoryData.length, (index) {
        return _buildCategoryIndicator(
          _categoryData.keys.elementAt(index),
          _categoryColors[index],
        );
      }),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    return List.generate(_categoryData.length, (index) {
      final isTouched = index == touchedIndex;
      final value = _categoryData.values.elementAt(index);

      return PieChartSectionData(
        color: _categoryColors[index],
        value: value,
        showTitle: false,
        radius: isTouched ? 25 : 20, // 調整半徑
      );
    });
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

  // 3. 服務項目總支出區塊
  Widget _buildLifetimeSpendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '服務總支出',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildLifetimeSpendingItem('Netflix', 4680, Colors.red[700]!),
            _buildLifetimeSpendingItem(
              'Microsoft 365',
              2190,
              Colors.blueGrey[700]!,
            ),
            _buildLifetimeSpendingItem('Spotify', 1788, Colors.green[600]!),
            _buildLifetimeSpendingItem('YouTube', 1596, Colors.red[900]!),
          ],
        ),
      ],
    );
  }

  Widget _buildLifetimeSpendingItem(String name, int amount, Color brandColor) {
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
              color: brandColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name.substring(0, 1),
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
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Text(
            'NT\$ $amount',
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
