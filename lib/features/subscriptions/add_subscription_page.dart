// =================================================================
// 檔案: lib/features/subscriptions/add_subscription_page.dart
// (此檔案已更新，使用自訂對話框取代 DatePicker 以移除標頭)
// =================================================================
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/subscription_service.dart';
import '../../shared/models/subscription.dart';

// --- Data models for suggestions ---
class Plan {
  final String name;
  final Map<String, double> prices;
  Plan({required this.name, required this.prices});
}

class SubscriptionSuggestion {
  final String name;
  final String nativeCurrency;
  final Color brandColor;
  final List<Plan> plans;
  final SubscriptionCategory category;
  SubscriptionSuggestion({
    required this.name,
    required this.nativeCurrency,
    required this.brandColor,
    required this.plans,
    required this.category,
  });
}

// --- Data list for suggestions ---
final List<SubscriptionSuggestion> popularSuggestions = [
  SubscriptionSuggestion(
    name: 'Netflix',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFE50914),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '基本', prices: {'TWD': 270, 'USD': 6.99}),
      Plan(name: '標準', prices: {'TWD': 330, 'USD': 10.99}),
      Plan(name: '高級', prices: {'TWD': 390, 'USD': 15.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Disney+',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF113CCF),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '標準方案', prices: {'TWD': 270}),
      Plan(name: '高級方案', prices: {'TWD': 320}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'YouTube',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFFF0000),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: 'Premium 個人', prices: {'TWD': 199, 'USD': 7.99}),
      Plan(name: 'Premium 家庭', prices: {'TWD': 399, 'USD': 14.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: '動畫瘋',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF00A2E8),
    category: SubscriptionCategory.video,
    plans: [
      Plan(name: '月費方案', prices: {'TWD': 99}),
      Plan(name: '年費方案', prices: {'TWD': 990}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Spotify',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF1DB954),
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: 'Individual', prices: {'TWD': 149, 'USD': 5.99}),
      Plan(name: 'Duo', prices: {'TWD': 198, 'USD': 7.99}),
      Plan(name: 'Family', prices: {'TWD': 268, 'USD': 9.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'KKBOX',
    nativeCurrency: 'TWD',
    brandColor: Colors.cyan[600]!,
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: '標準音質', prices: {'TWD': 149}),
      Plan(name: '無損音質', prices: {'TWD': 299}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Apple Music',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFFFC3C44),
    category: SubscriptionCategory.music,
    plans: [
      Plan(name: '個人方案', prices: {'TWD': 165, 'USD': 10.99}),
      Plan(name: '家庭方案', prices: {'TWD': 265, 'USD': 16.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'ChatGPT',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFF74AA9C),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Plus', prices: {'USD': 20}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Gemini',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFF8E44AD),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Advanced', prices: {'USD': 19.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Claude',
    nativeCurrency: 'USD',
    brandColor: const Color(0xFFD97757),
    category: SubscriptionCategory.ai,
    plans: [
      Plan(name: 'Pro', prices: {'USD': 20}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Microsoft 365',
    nativeCurrency: 'TWD',
    brandColor: const Color(0xFF0078D4),
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '個人版', prices: {'TWD': 219, 'USD': 6.99}),
      Plan(name: '家用版', prices: {'TWD': 320, 'USD': 9.99}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'Google One',
    nativeCurrency: 'TWD',
    brandColor: Colors.blue[700]!,
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '100 GB', prices: {'TWD': 65}),
      Plan(name: '200 GB', prices: {'TWD': 90}),
      Plan(name: '2 TB', prices: {'TWD': 330}),
    ],
  ),
  SubscriptionSuggestion(
    name: 'iCloud+',
    nativeCurrency: 'TWD',
    brandColor: Colors.indigo[300]!,
    category: SubscriptionCategory.productivity,
    plans: [
      Plan(name: '50 GB', prices: {'TWD': 30}),
      Plan(name: '200 GB', prices: {'TWD': 90}),
      Plan(name: '2 TB', prices: {'TWD': 300}),
    ],
  ),
];

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});
  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _subscriptionService = SubscriptionService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _selectedDate = DateTime.now();
  String _selectedCurrency = 'TWD';
  final List<String> _currencies = ['TWD', 'USD', 'JPY'];

  Plan? _selectedPlan;
  SubscriptionCategory _selectedCategory = SubscriptionCategory.video;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _applySuggestion(
    SubscriptionSuggestion suggestion,
    Plan plan,
    String currency,
  ) {
    setState(() {
      _selectedPlan = plan;
      _nameController.text = suggestion.name;
      _amountController.text = plan.prices[currency]!
          .toStringAsFixed(2)
          .replaceAll(RegExp(r'\.00$'), '');
      _selectedCurrency = currency;
    });
  }

  void _showPlanPicker(SubscriptionSuggestion suggestion) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '選擇 ${suggestion.name} 的方案',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...suggestion.plans.map((plan) {
                final currencyToShow =
                    plan.prices.containsKey(_selectedCurrency)
                    ? _selectedCurrency
                    : suggestion.nativeCurrency;
                final priceToShow = plan.prices[currencyToShow];

                return ListTile(
                  title: Text(plan.name),
                  trailing: Text(
                    '$currencyToShow ${priceToShow!.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}',
                  ),
                  onTap: () {
                    _applySuggestion(suggestion, plan, currencyToShow);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- [修改] 使用自訂的 Dialog 取代 showDatePicker ---
  Future<void> _pickDate() async {
    DateTime? pickedDate = _selectedDate;
    final DateTime? result = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(0),
          content: SizedBox(
            height: 380, // 調整高度以容納按鈕
            width: 320,
            child: Column(
              children: [
                Expanded(
                  child: CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                    onDateChanged: (DateTime date) {
                      pickedDate = date;
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(null),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(pickedDate),
                        child: const Text('確定'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && result != _selectedDate) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: _currencies.map((currency) {
              return ListTile(
                title: Text(currency),
                onTap: () {
                  setState(() {
                    _selectedCurrency = currency;
                    if (_selectedPlan != null) {
                      if (_selectedPlan!.prices.containsKey(currency)) {
                        _amountController.text = _selectedPlan!
                            .prices[currency]!
                            .toStringAsFixed(2)
                            .replaceAll(RegExp(r'\.00$'), '');
                      }
                    }
                  });
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _saveSubscription() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final suggestion = popularSuggestions.firstWhere(
        (s) => s.name == _nameController.text,
        orElse: () => SubscriptionSuggestion(
          name: _nameController.text,
          nativeCurrency: 'TWD',
          brandColor: Colors.grey,
          category: SubscriptionCategory.other,
          plans: [],
        ),
      );

      final newSubscription = Subscription(
        id: '',
        name: _nameController.text,
        plan: _selectedPlan?.name ?? '自訂方案',
        amount: double.parse(_amountController.text),
        currency: _selectedCurrency,
        cycle: _selectedCycle,
        firstPaymentDate: _selectedDate,
        brandColor: suggestion.brandColor,
        category: suggestion.category,
      );

      try {
        await _subscriptionService.addSubscription(newSubscription);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('儲存失敗，請稍後再試。')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '新增訂閱項目',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildSuggestionsSection(),

              const SizedBox(height: 20),
              _buildTextField(
                controller: _nameController,
                label: '服務名稱',
                hint: '例如：YouTube Premium',
                validator: (value) =>
                    value == null || value.isEmpty ? '請輸入服務名稱' : null,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _buildAmountField(),
              const SizedBox(height: 12),
              _buildCycleSelector(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveSubscription,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          '儲存訂閱',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    final filteredSuggestions = popularSuggestions
        .where((s) => s.category == _selectedCategory)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '或從常用服務快速新增',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4b5563),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: SubscriptionCategory.values.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = SubscriptionCategory.values[index];
              final isSelected = category == _selectedCategory;
              return ChoiceChip(
                label: Text(category.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  }
                },
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: (80 * 2) + 12,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 100 / 80,
            ),
            itemCount: filteredSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = filteredSuggestions[index];
              return InkWell(
                onTap: () => _showPlanPicker(suggestion),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: suggestion.brandColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            suggestion.name.substring(0, 1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4b5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '金額',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4b5563),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          validator: (value) {
            if (value == null || value.isEmpty) return '請輸入金額';
            if (double.tryParse(value) == null) return '請輸入有效的數字';
            return null;
          },
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: '390',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: _showCurrencyPicker,
                borderRadius: BorderRadius.circular(12),
                child: Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedCurrency,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCycleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '付款週期',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4b5563),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ToggleButtons(
            isSelected: [
              _selectedCycle == BillingCycle.monthly,
              _selectedCycle == BillingCycle.quarterly,
              _selectedCycle == BillingCycle.yearly,
            ],
            onPressed: (index) {
              setState(() {
                _selectedCycle = BillingCycle.values[index];
              });
            },
            borderRadius: BorderRadius.circular(12),
            constraints: BoxConstraints(
              minHeight: 40.0,
              minWidth: (MediaQuery.of(context).size.width - 48) / 3,
            ),
            children: const [Text('每月'), Text('每季'), Text('每年')],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '首次付款日',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF4b5563),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('yyyy / MM / dd').format(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
                const Icon(Icons.calendar_today),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
