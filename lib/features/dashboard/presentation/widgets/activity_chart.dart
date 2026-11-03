import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/rupiah.dart';
import '../../../../core/widgets/finova_card.dart';
import '../../data/dashboard_dummy_data.dart';

class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.activity});
  final List<CashActivity> activity;

  @override
  Widget build(BuildContext context) {
    final maxAmount = activity.fold<int>(
      0,
      (value, item) => math.max(value, math.max(item.income, item.expense)),
    );
    return FinovaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: const [
              _Legend(label: 'Pemasukan', color: AppColors.primary),
              _Legend(label: 'Pengeluaran', color: AppColors.pink),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Arus kas disetujui · dalam juta Rupiah',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Belum ada aktivitas pada periode ini.'),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 140,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (maxAmount / 1000000)
                            .toStringAsFixed(1)
                            .replaceAll('.', ','),
                        style: _axisStyle,
                      ),
                      Text(
                        (maxAmount / 2000000)
                            .toStringAsFixed(1)
                            .replaceAll('.', ','),
                        style: _axisStyle,
                      ),
                      const Text('0', style: _axisStyle),
                    ],
                  ),
                ),
                ...activity.map(
                  (item) => Expanded(
                    child: Semantics(
                      label:
                          '${item.label}: pemasukan ${formatRupiah(item.income)}, '
                          'pengeluaran ${formatRupiah(item.expense)}',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Container(
                              height: 140,
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: AppColors.border),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _Bar(
                                    value: item.income,
                                    maxAmount: maxAmount,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  _Bar(
                                    value: item.expense,
                                    maxAmount: maxAmount,
                                    color: AppColors.pink,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(item.label, style: _axisStyle),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static const _axisStyle = TextStyle(fontSize: 10, color: AppColors.muted);
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.maxAmount,
    required this.color,
  });
  final int value;
  final int maxAmount;
  final Color color;
  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      width: 18,
      height: maxAmount == 0 ? 0 : value / maxAmount * 140,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
    ],
  );
}
