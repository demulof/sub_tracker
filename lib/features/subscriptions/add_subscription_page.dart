import 'package:flutter/material.dart';
import '../../shared/models/subscription.dart'; // 引入模型

class AddSubscriptionPage extends StatefulWidget {
  const AddSubscriptionPage({super.key});

  @override
  State<AddSubscriptionPage> createState() => _AddSubscriptionPageState();
}

class _AddSubscriptionPageState extends State<AddSubscriptionPage> {
  final _formKey = GlobalKey<FormState>();

  // Form fields controllers and variables
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  BillingCycle _selectedCycle = BillingCycle.monthly;
  DateTime _selectedDate = DateTime.now();
  // --- [新增] 幣值狀態管理 ---
  String _selectedCurrency = 'TWD';
  final List<String> _currencies = ['TWD', 'USD', 'JPY', 'EUR'];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- [新增] 選擇幣值的底部彈窗 ---
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

  void _saveSubscription() {
    if (_formKey.currentState!.validate()) {
      // 在此處處理儲存邏輯
      print('儲存的資料:');
      print('名稱: ${_nameController.text}');
      print('金額: ${_amountController.text}');
      print('幣值: $_selectedCurrency'); // 確認幣值已儲存
      print('週期: $_selectedCycle');
      print('首次付款日: $_selectedDate');

      Navigator.of(context).pop(); // 關閉頁面
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 讓鍵盤彈出時，視野跟著上移
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
            // Handle Bar
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

            // Title
            Text(
              '新增訂閱項目',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF1A237E),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields
            _buildTextField(
              controller: _nameController,
              label: '服務名稱',
              hint: '例如：YouTube Premium',
              validator: (value) =>
                  value == null || value.isEmpty ? '請輸入服務名稱' : null,
              // --- [修改] 明確指定鍵盤類型以支援中文 ---
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),

            _buildAmountField(),
            const SizedBox(height: 16),

            _buildCycleSelector(),
            const SizedBox(height: 16),

            _buildDatePicker(),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSubscription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '儲存訂閱',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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

  // --- [修改] 金額欄位，加入幣值切換功能 ---
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
            hintText: '399',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: _showCurrencyPicker, // 點擊時觸發幣值選擇
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
                  backgroundColor: Colors.grey[200],
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
        // 使用 ToggleButtons 讓選項更緊湊
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
            selectedColor: const Color(0xFF1A237E),
            fillColor: const Color(0xFFFFC107).withAlpha(200),
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
                  '${_selectedDate.year} / ${_selectedDate.month} / ${_selectedDate.day}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Icon(Icons.calendar_today, color: Color(0xFF1A237E)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
