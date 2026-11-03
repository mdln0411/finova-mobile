import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/rupiah.dart';
import '../../data/dashboard_dummy_data.dart';

class RecentTransactionTile extends StatelessWidget {
  const RecentTransactionTile({super.key, required this.transaction});
  final RecentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final approved = transaction.status == TransactionStatus.approved;
    final statusColor = switch (transaction.status) {
      TransactionStatus.approved => AppColors.primary,
      TransactionStatus.pending => const Color(0xFF854D0E),
      TransactionStatus.rejected => const Color(0xFFB91C1C),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: transaction.isIncome
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFDF2F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              transaction.isIncome
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: transaction.isIncome ? AppColors.primary : AppColors.pink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.category} · ${transaction.dateLabel}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${transaction.isIncome ? '+' : '−'}${formatRupiah(transaction.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: approved && transaction.isIncome
                            ? AppColors.primary
                            : AppColors.text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        transaction.status.label,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
