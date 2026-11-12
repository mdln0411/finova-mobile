import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/chart_account.dart';

abstract final class ChartAccountCodec {
  static Map<String, dynamic> values(ChartAccount account) => {
    'code': account.code,
    'name': account.name,
    'type': account.type.name,
    'normalBalance': account.normalBalance.name,
    'parentCode': account.parentCode,
    'isPosting': account.isPosting,
    'isActive': account.isActive,
  };

  static ChartAccount fromDocument(String id, Map<String, dynamic> data) {
    final type = AccountType.values
        .where((value) => value.name == data['type'])
        .firstOrNull;
    final side = BalanceSide.values
        .where((value) => value.name == data['normalBalance'])
        .firstOrNull;
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final creator = data['createdBy'];
    if (data['code'] != id ||
        data['name'] is! String ||
        type == null ||
        side == null ||
        data['isPosting'] is! bool ||
        data['isActive'] is! bool ||
        !data.containsKey('parentCode') ||
        (data['parentCode'] != null && data['parentCode'] is! String) ||
        creator is! String ||
        creator.isEmpty ||
        createdAt is! Timestamp ||
        updatedAt is! Timestamp ||
        updatedAt.compareTo(createdAt) < 0) {
      throw const ChartOfAccountsFailure(
        'Format akun belum sesuai. Hubungi Manager untuk memeriksa data.',
      );
    }
    final account = ChartAccount(
      code: id,
      name: data['name'] as String,
      type: type,
      normalBalance: side,
      isPosting: data['isPosting'] as bool,
      isActive: data['isActive'] as bool,
      parentCode: data['parentCode'] as String?,
    );
    final error = account.validate();
    if (error != null) throw ChartOfAccountsFailure(error);
    return account;
  }
}
