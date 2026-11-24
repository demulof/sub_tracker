import 'package:intl/intl.dart';

final NumberFormat _integer = NumberFormat('#,##0');
final NumberFormat _decimal = NumberFormat('#,##0.##');

/// 新台幣金額，四捨五入到整數，例如 NT$ 1,234。
String formatTwd(double amount) => 'NT\$ ${_integer.format(amount.round())}';

/// 原幣金額。日圓與新台幣不顯示小數，美元最多兩位小數。
String formatAmount(double amount, String currency) {
  final text = currency == 'USD'
      ? _decimal.format(amount)
      : _integer.format(amount.round());
  return '$currency $text';
}

/// 輸入框用的數字字串，去掉多餘的小數 0，例如 270.0 → 270、6.99 → 6.99。
String amountToInput(double amount) =>
    amount.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

String formatDate(DateTime d) => DateFormat('yyyy/MM/dd').format(d);
