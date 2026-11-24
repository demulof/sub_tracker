import 'package:flutter/material.dart';

/// 以服務名稱第一個字做成的圖示（不使用各品牌的商標圖檔）。
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    required this.name,
    required this.color,
    this.size = 48,
    this.dimmed = false,
  });

  final String name;
  final Color color;
  final double size;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: dimmed ? Colors.grey[400] : color,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.5,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}
