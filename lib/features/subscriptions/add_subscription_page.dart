import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/subscription_service.dart';
import '../../shared/format.dart';
import '../../shared/models/subscription.dart';
import '../../shared/widgets/brand_icon.dart';
import 'suggestions.dart';

/// 新增或編輯訂閱。傳入 [existing] 時為編輯模式（可修改、停止訂閱、刪除）。
class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key, this.existing});

  final Subscription? existing;

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _service = SubscriptionService.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _planController = TextEditingController();
  final _amountController = TextEditingController();

  BillingCycle _cycle = BillingCycle.monthly;
  DateTime _firstPaymentDate = dateOnly(DateTime.now());
  String _currency = 'TWD';
  SubscriptionCategory _category = SubscriptionCategory.video;
  bool _isEnded = false;
  DateTime _endDate = dateOnly(DateTime.now());
  Plan? _selectedPlan;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final sub = widget.existing;
    if (sub != null) {
      _nameController.text = sub.name;
      _planController.text = sub.plan;
      _amountController.text = amountToInput(sub.amount);
      _cycle = sub.cycle;
      _firstPaymentDate = sub.firstPaymentDate;
      _currency = sub.currency;
      _category = sub.category;
      _isEnded = sub.endDate != null;
      _endDate = sub.endDate ?? dateOnly(DateTime.now());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _planController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  SubscriptionSuggestion? _matchSuggestion(String name) {
    final key = name.trim().toLowerCase();
    for (final s in popularSuggestions) {
      if (s.name.toLowerCase() == key) return s;
    }
    return null;
  }

  void _applySuggestion(SubscriptionSuggestion s, Plan plan, String currency) {
    setState(() {
      _selectedPlan = plan;
      _nameController.text = s.name;
      _planController.text = plan.name;
      _amountController.text = amountToInput(plan.prices[currency]!);
      _currency = currency;
      _category = s.category;
    });
  }

  // ------------------------------------------------------------ 選擇器

  void _showPlanPicker(SubscriptionSuggestion suggestion) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '選擇 ${suggestion.name} 的方案',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...suggestion.plans.map((plan) {
              final currency = plan.prices.containsKey(_currency)
                  ? _currency
                  : suggestion.nativeCurrency;
              return ListTile(
                title: Text(plan.name),
                trailing: Text(formatAmount(plan.prices[currency]!, currency)),
                onTap: () {
                  _applySuggestion(suggestion, plan, currency);
                  Navigator.of(context).pop();
                },
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Text(
                '價格僅供參考，請以實際帳單金額為準。',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: SubscriptionLimits.currencies.map((currency) {
            return ListTile(
              title: Text(currency),
              trailing: currency == _currency ? const Icon(Icons.check) : null,
              onTap: () {
                setState(() {
                  _currency = currency;
                  final price = _selectedPlan?.prices[currency];
                  if (price != null) {
                    _amountController.text = amountToInput(price);
                  }
                });
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 不含標頭的日曆對話框。
  Future<DateTime?> _pickDate(DateTime initial) {
    DateTime picked = initial;
    return showDialog<DateTime>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          height: 380,
          width: 320,
          child: Column(
            children: [
              Expanded(
                child: CalendarDatePicker(
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(DateTime.now().year + 5, 12, 31),
                  onDateChanged: (d) => picked = d,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(picked),
                      child: const Text('確定'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ 儲存 / 刪除

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEnded && !_endDate.isAfter(_firstPaymentDate)) {
      _showMessage('停止續訂日必須晚於首次付款日。');
      return;
    }

    final name = _nameController.text.trim();
    final plan = _planController.text.trim();
    final suggestion = _matchSuggestion(name);
    final existing = widget.existing;
    final Color brandColor;
    if (suggestion != null) {
      brandColor = suggestion.brandColor;
    } else if (existing != null && existing.name == name) {
      brandColor = existing.brandColor;
    } else {
      brandColor = _category.color;
    }

    final sub = Subscription(
      id: existing?.id ?? '',
      name: name,
      plan: plan.isEmpty ? '自訂方案' : plan,
      amount: double.parse(_amountController.text.trim()),
      currency: _currency,
      cycle: _cycle,
      firstPaymentDate: _firstPaymentDate,
      endDate: _isEnded ? _endDate : null,
      brandColor: brandColor,
      category: _category,
    );

    setState(() => _isSaving = true);
    try {
      await _service.saveSubscription(sub);
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      debugPrint('儲存訂閱失敗：${e.code}');
      _showMessage('儲存失敗，請稍後再試。');
    } catch (e) {
      debugPrint('儲存訂閱失敗：$e');
      _showMessage('儲存失敗，請稍後再試。');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除訂閱'),
        content: Text(
          '確定要刪除「${existing.name}」嗎？刪除後無法復原，相關的統計紀錄也會一併消失。\n\n'
          '如果只是不再續訂，建議改用「已停止訂閱」，保留過去的支出紀錄。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _service.deleteSubscription(existing.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('刪除訂閱失敗：$e');
      _showMessage('刪除失敗，請稍後再試。');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 這個頁面顯示在底部彈出視窗裡，SnackBar 會被遮住，所以用對話框提示。
  void _showMessage(String text) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ 畫面

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
              _isEditing ? '編輯訂閱項目' : '新增訂閱項目',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1A237E),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _label('分類'),
            _buildCategoryChips(),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              _buildSuggestions(),
            ],
            const SizedBox(height: 20),
            _label('服務名稱'),
            TextFormField(
              controller: _nameController,
              maxLength: SubscriptionLimits.maxNameLength,
              textInputAction: TextInputAction.next,
              decoration: _decoration(hint: '例如：YouTube'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '請輸入服務名稱' : null,
            ),
            _label('方案名稱（選填）'),
            TextFormField(
              controller: _planController,
              maxLength: SubscriptionLimits.maxPlanLength,
              textInputAction: TextInputAction.next,
              decoration: _decoration(hint: '例如：Premium 個人'),
            ),
            _buildAmountField(),
            const SizedBox(height: 12),
            _buildCycleSelector(),
            const SizedBox(height: 16),
            _label('首次付款日'),
            _dateField(_firstPaymentDate, () async {
              final d = await _pickDate(_firstPaymentDate);
              if (d != null) setState(() => _firstPaymentDate = dateOnly(d));
            }),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('已停止訂閱'),
              subtitle: const Text('保留過去的支出紀錄，之後不再計算扣款'),
              value: _isEnded,
              onChanged: (v) => setState(() => _isEnded = v),
            ),
            if (_isEnded) ...[
              _label('停止續訂日（此日起不再扣款）'),
              _dateField(_endDate, () async {
                final d = await _pickDate(_endDate);
                if (d != null) setState(() => _endDate = dateOnly(d));
              }),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        _isEditing ? '儲存變更' : '儲存訂閱',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _isSaving ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('刪除此訂閱'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w500,
        color: Color(0xFF4B5563),
      ),
    ),
  );

  InputDecoration _decoration({String? hint, Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hint,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      );

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SubscriptionCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = SubscriptionCategory.values[index];
          return ChoiceChip(
            label: Text(category.displayName),
            selected: category == _category,
            showCheckmark: false,
            onSelected: (selected) {
              if (selected) setState(() => _category = category);
            },
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    final items = popularSuggestions
        .where((s) => s.category == _category)
        .toList();
    if (items.isEmpty) {
      return Text(
        '此分類沒有常用服務，請直接在下方輸入。',
        style: TextStyle(color: Colors.grey[600]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '從常用服務快速新增（價格僅供參考）',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 100 / 80,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final s = items[index];
            return InkWell(
              onTap: () => _showPlanPicker(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BrandIcon(name: s.name, color: s.brandColor, size: 40),
                    const SizedBox(height: 4),
                    Text(
                      s.name,
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
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('金額'),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          validator: (value) {
            final v = double.tryParse(value?.trim() ?? '');
            if (v == null) return '請輸入有效的金額';
            if (v <= 0) return '金額必須大於 0';
            if (v > SubscriptionLimits.maxAmount) return '金額過大';
            return null;
          },
          decoration: _decoration(
            hint: '390',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showCurrencyPicker,
                borderRadius: BorderRadius.circular(12),
                child: Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currency,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
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
        _label('付款週期'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<BillingCycle>(
            segments: BillingCycle.values
                .map(
                  (c) => ButtonSegment<BillingCycle>(
                    value: c,
                    label: Text(c.displayName),
                  ),
                )
                .toList(),
            selected: {_cycle},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _cycle = s.first),
          ),
        ),
      ],
    );
  }

  Widget _dateField(DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDate(date), style: const TextStyle(fontSize: 16)),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }
}
