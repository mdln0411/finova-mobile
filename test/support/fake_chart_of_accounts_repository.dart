import 'dart:async';

import 'package:finova/features/chart_of_accounts/domain/chart_account.dart';
import 'package:finova/features/chart_of_accounts/domain/chart_of_accounts_repository.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';

class FakeChartOfAccountsRepository implements ChartOfAccountsRepository {
  List<ChartAccount> accounts = const [];
  ChartOfAccountsFailure? readFailure;
  ChartOfAccountsFailure? writeFailure;
  Completer<void>? writeDelay;
  int initializeCalls = 0;
  String? requestedCompany;
  final events = StreamController<List<ChartAccount>>.broadcast();
  @override
  Stream<List<ChartAccount>> watchAccounts(String companyId) async* {
    requestedCompany = companyId;
    if (readFailure != null) throw readFailure!;
    yield accounts;
    yield* events.stream;
  }

  @override
  Future<int> initializeDefaults(String companyId) async {
    initializeCalls++;
    if (writeDelay != null) await writeDelay!.future;
    if (writeFailure != null) throw writeFailure!;
    final added = defaultChartOfAccounts
        .where(
          (account) =>
              !accounts.any((existing) => existing.code == account.code),
        )
        .toList();
    accounts = [...accounts, ...added]
      ..sort((a, b) => a.code.compareTo(b.code));
    events.add(accounts);
    return added.length;
  }

  Future<void> dispose() => events.close();
}
