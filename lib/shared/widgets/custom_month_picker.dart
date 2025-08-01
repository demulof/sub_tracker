// =================================================================
// 檔案: lib/shared/widgets/custom_month_picker.dart
// (這是全新的檔案，包含了可重複使用的自訂月份選擇器)
// =================================================================
import 'package:flutter/material.dart';

class CustomMonthPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const CustomMonthPicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<CustomMonthPicker> createState() => _CustomMonthPickerState();
}

class _CustomMonthPickerState extends State<CustomMonthPicker> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildYearSelector(),
          const Divider(),
          Expanded(child: _buildMonthGrid()),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _selectedYear > widget.firstDate.year
              ? () => setState(() => _selectedYear--)
              : null,
        ),
        Text(
          '$_selectedYear 年',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _selectedYear < widget.lastDate.year
              ? () => setState(() => _selectedYear++)
              : null,
        ),
      ],
    );
  }

  Widget _buildMonthGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        final month = index + 1;
        final isSelected =
            _selectedYear == widget.initialDate.year &&
            month == widget.initialDate.month;

        final currentDate = DateTime(_selectedYear, month);
        final firstValidDate = DateTime(
          widget.firstDate.year,
          widget.firstDate.month,
        );
        final lastValidDate = DateTime(
          widget.lastDate.year,
          widget.lastDate.month,
        );

        final bool isEnabled =
            (currentDate.isAfter(firstValidDate) ||
                currentDate.isAtSameMomentAs(firstValidDate)) &&
            (currentDate.isBefore(lastValidDate) ||
                currentDate.isAtSameMomentAs(lastValidDate));

        return TextButton(
          onPressed: isEnabled
              ? () {
                  final selectedDate = DateTime(_selectedYear, month);
                  Navigator.of(context).pop(selectedDate);
                }
              : null,
          style: TextButton.styleFrom(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primary.withAlpha(51)
                : null,
            shape: const CircleBorder(),
          ),
          child: Text(
            '$month月',
            style: TextStyle(
              color: isEnabled
                  ? (isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black87)
                  : Colors.grey[400],
            ),
          ),
        );
      },
    );
  }
}
