import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/rupiah.dart';
import '../../../../core/widgets/finova_card.dart';
import '../../domain/finance_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accountName,
    this.onTap,
    this.footer,
  });
  final FinanceTransaction transaction;
  final String Function(String code) accountName;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final income = tx.type == TransactionType.income;
    return FinovaCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: income
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFDF2F8),
                    child: Icon(
                      income
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      size: 18,
                      color: income ? AppColors.primary : AppColors.pink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatShortDate(tx.date)} · ${accountName(tx.categoryAccountId)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          accountName(tx.cashAccountId),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${income ? '+' : '-'}${formatRupiah(tx.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: income ? AppColors.primary : AppColors.text,
                    ),
                  ),
                  StatusBadge(status: tx.status),
                ],
              ),
              if (tx.status == TransactionStatus.rejected &&
                  tx.rejectReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Alasan: ${tx.rejectReason}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ],
              if (footer != null) ...[const SizedBox(height: 12), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final TransactionStatus status;
  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      TransactionStatus.pending => (
        const Color(0xFFFEF9C3),
        const Color(0xFF854D0E),
      ),
      TransactionStatus.approved => (
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      TransactionStatus.rejected => (
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
