import 'package:drift/drift.dart';

class _NoOpQueryExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  QueryExecutor beginExclusive() => this;

  @override
  TransactionExecutor beginTransaction() => throw UnimplementedError();

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  Future<int> runCustom(String statement, [List<Object?>? args]) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
          String statement, List<Object?> args) async =>
      [];

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;
}

QueryExecutor openDriftConnection() {
  return _NoOpQueryExecutor();
}
