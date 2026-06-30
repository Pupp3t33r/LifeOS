// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PendingOperationsTable extends PendingOperations
    with TableInfo<$PendingOperationsTable, PendingOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<OperationStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<OperationStatus>(
        $PendingOperationsTable.$converterstatus,
      );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    method,
    path,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingOperation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: $PendingOperationsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingOperationsTable createAlias(String alias) {
    return $PendingOperationsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OperationStatus, String, String> $converterstatus =
      const EnumNameConverter<OperationStatus>(OperationStatus.values);
}

class PendingOperation extends DataClass
    implements Insertable<PendingOperation> {
  /// Client-assigned id of the operation; doubles as the idempotency key. For a
  /// record-transaction op this mirrors the `transactionId` carried in
  /// [payload], so the row and the server resource share one identity.
  final String id;

  /// Diagnostic/routing label, e.g. `record_transaction`. The drainer does not
  /// interpret it — it replays [method]/[path]/[payload] verbatim.
  final String kind;

  /// HTTP verb to replay, e.g. `POST`.
  final String method;

  /// Request path relative to the Money API base, e.g.
  /// `/accounts/<id>/transactions`.
  final String path;

  /// JSON request body, stored exactly as it will be sent.
  final String payload;

  /// Where this row sits in the replay lifecycle.
  final OperationStatus status;

  /// How many send attempts have been made; drives backoff and diagnostics.
  final int attempts;

  /// Last failure detail, surfaced for [OperationStatus.failed] rows. Null until
  /// a send fails.
  final String? lastError;

  /// When the operation was first enqueued.
  final DateTime createdAt;

  /// When the row was last touched (status flip, attempt bump).
  final DateTime updatedAt;
  const PendingOperation({
    required this.id,
    required this.kind,
    required this.method,
    required this.path,
    required this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['method'] = Variable<String>(method);
    map['path'] = Variable<String>(path);
    map['payload'] = Variable<String>(payload);
    {
      map['status'] = Variable<String>(
        $PendingOperationsTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingOperationsCompanion toCompanion(bool nullToAbsent) {
    return PendingOperationsCompanion(
      id: Value(id),
      kind: Value(kind),
      method: Value(method),
      path: Value(path),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingOperation(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      method: serializer.fromJson<String>(json['method']),
      path: serializer.fromJson<String>(json['path']),
      payload: serializer.fromJson<String>(json['payload']),
      status: $PendingOperationsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'method': serializer.toJson<String>(method),
      'path': serializer.toJson<String>(path),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(
        $PendingOperationsTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingOperation copyWith({
    String? id,
    String? kind,
    String? method,
    String? path,
    String? payload,
    OperationStatus? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PendingOperation(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    method: method ?? this.method,
    path: path ?? this.path,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingOperation copyWithCompanion(PendingOperationsCompanion data) {
    return PendingOperation(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      method: data.method.present ? data.method.value : this.method,
      path: data.path.present ? data.path.value : this.path,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperation(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    method,
    path,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingOperation &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.method == this.method &&
          other.path == this.path &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PendingOperationsCompanion extends UpdateCompanion<PendingOperation> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> method;
  final Value<String> path;
  final Value<String> payload;
  final Value<OperationStatus> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingOperationsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.method = const Value.absent(),
    this.path = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingOperationsCompanion.insert({
    required String id,
    required String kind,
    required String method,
    required String path,
    required String payload,
    required OperationStatus status,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       method = Value(method),
       path = Value(path),
       payload = Value(payload),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PendingOperation> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? method,
    Expression<String>? path,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (method != null) 'method': method,
      if (path != null) 'path': path,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingOperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? method,
    Value<String>? path,
    Value<String>? payload,
    Value<OperationStatus>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingOperationsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      method: method ?? this.method,
      path: path ?? this.path,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PendingOperationsTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingOperationsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('method: $method, ')
          ..write('path: $path, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedFlowEntriesTable extends CachedFlowEntries
    with TableInfo<$CachedFlowEntriesTable, CachedFlowEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedFlowEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCurrencyMeta = const VerificationMeta(
    'totalCurrency',
  );
  @override
  late final GeneratedColumn<String> totalCurrency = GeneratedColumn<String>(
    'total_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linesJsonMeta = const VerificationMeta(
    'linesJson',
  );
  @override
  late final GeneratedColumn<String> linesJson = GeneratedColumn<String>(
    'lines_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entryId,
    year,
    month,
    direction,
    description,
    totalAmount,
    totalCurrency,
    linesJson,
    occurredAt,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_flow_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedFlowEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('total_currency')) {
      context.handle(
        _totalCurrencyMeta,
        totalCurrency.isAcceptableOrUnknown(
          data['total_currency']!,
          _totalCurrencyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalCurrencyMeta);
    }
    if (data.containsKey('lines_json')) {
      context.handle(
        _linesJsonMeta,
        linesJson.isAcceptableOrUnknown(data['lines_json']!, _linesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_linesJsonMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId};
  @override
  CachedFlowEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedFlowEntry(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      totalCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}total_currency'],
      )!,
      linesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lines_json'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $CachedFlowEntriesTable createAlias(String alias) {
    return $CachedFlowEntriesTable(attachedDatabase, alias);
  }
}

class CachedFlowEntry extends DataClass implements Insertable<CachedFlowEntry> {
  /// Server entry id (a Guid, as text); also the idempotency key (ADR-0003). The
  /// outbox overlay dedups against this, so a confirmed entry replaces its pending
  /// twin cleanly.
  final String entryId;

  /// The accounting period this entry was bucketed into.
  final int year;
  final int month;

  /// `'in'` (income) or `'out'` (expense) — the entry direction.
  final String direction;

  /// Optional entry-level note.
  final String? description;

  /// Signed entry total (Σ of line amounts) and its single currency (ADR-0019).
  final double totalAmount;
  final String totalCurrency;

  /// The entry's lines, as the JSON array the server returned.
  final String linesJson;

  /// When the entry actually happened, and when the server recorded it. Newest
  /// [occurredAt] first is the cockpit's display order.
  final DateTime occurredAt;
  final DateTime recordedAt;
  const CachedFlowEntry({
    required this.entryId,
    required this.year,
    required this.month,
    required this.direction,
    this.description,
    required this.totalAmount,
    required this.totalCurrency,
    required this.linesJson,
    required this.occurredAt,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['total_amount'] = Variable<double>(totalAmount);
    map['total_currency'] = Variable<String>(totalCurrency);
    map['lines_json'] = Variable<String>(linesJson);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  CachedFlowEntriesCompanion toCompanion(bool nullToAbsent) {
    return CachedFlowEntriesCompanion(
      entryId: Value(entryId),
      year: Value(year),
      month: Value(month),
      direction: Value(direction),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      totalAmount: Value(totalAmount),
      totalCurrency: Value(totalCurrency),
      linesJson: Value(linesJson),
      occurredAt: Value(occurredAt),
      recordedAt: Value(recordedAt),
    );
  }

  factory CachedFlowEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedFlowEntry(
      entryId: serializer.fromJson<String>(json['entryId']),
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      direction: serializer.fromJson<String>(json['direction']),
      description: serializer.fromJson<String?>(json['description']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      totalCurrency: serializer.fromJson<String>(json['totalCurrency']),
      linesJson: serializer.fromJson<String>(json['linesJson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'direction': serializer.toJson<String>(direction),
      'description': serializer.toJson<String?>(description),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'totalCurrency': serializer.toJson<String>(totalCurrency),
      'linesJson': serializer.toJson<String>(linesJson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  CachedFlowEntry copyWith({
    String? entryId,
    int? year,
    int? month,
    String? direction,
    Value<String?> description = const Value.absent(),
    double? totalAmount,
    String? totalCurrency,
    String? linesJson,
    DateTime? occurredAt,
    DateTime? recordedAt,
  }) => CachedFlowEntry(
    entryId: entryId ?? this.entryId,
    year: year ?? this.year,
    month: month ?? this.month,
    direction: direction ?? this.direction,
    description: description.present ? description.value : this.description,
    totalAmount: totalAmount ?? this.totalAmount,
    totalCurrency: totalCurrency ?? this.totalCurrency,
    linesJson: linesJson ?? this.linesJson,
    occurredAt: occurredAt ?? this.occurredAt,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  CachedFlowEntry copyWithCompanion(CachedFlowEntriesCompanion data) {
    return CachedFlowEntry(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      direction: data.direction.present ? data.direction.value : this.direction,
      description: data.description.present
          ? data.description.value
          : this.description,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      totalCurrency: data.totalCurrency.present
          ? data.totalCurrency.value
          : this.totalCurrency,
      linesJson: data.linesJson.present ? data.linesJson.value : this.linesJson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedFlowEntry(')
          ..write('entryId: $entryId, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('direction: $direction, ')
          ..write('description: $description, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('totalCurrency: $totalCurrency, ')
          ..write('linesJson: $linesJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entryId,
    year,
    month,
    direction,
    description,
    totalAmount,
    totalCurrency,
    linesJson,
    occurredAt,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedFlowEntry &&
          other.entryId == this.entryId &&
          other.year == this.year &&
          other.month == this.month &&
          other.direction == this.direction &&
          other.description == this.description &&
          other.totalAmount == this.totalAmount &&
          other.totalCurrency == this.totalCurrency &&
          other.linesJson == this.linesJson &&
          other.occurredAt == this.occurredAt &&
          other.recordedAt == this.recordedAt);
}

class CachedFlowEntriesCompanion extends UpdateCompanion<CachedFlowEntry> {
  final Value<String> entryId;
  final Value<int> year;
  final Value<int> month;
  final Value<String> direction;
  final Value<String?> description;
  final Value<double> totalAmount;
  final Value<String> totalCurrency;
  final Value<String> linesJson;
  final Value<DateTime> occurredAt;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const CachedFlowEntriesCompanion({
    this.entryId = const Value.absent(),
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.direction = const Value.absent(),
    this.description = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.totalCurrency = const Value.absent(),
    this.linesJson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedFlowEntriesCompanion.insert({
    required String entryId,
    required int year,
    required int month,
    required String direction,
    this.description = const Value.absent(),
    required double totalAmount,
    required String totalCurrency,
    required String linesJson,
    required DateTime occurredAt,
    required DateTime recordedAt,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       year = Value(year),
       month = Value(month),
       direction = Value(direction),
       totalAmount = Value(totalAmount),
       totalCurrency = Value(totalCurrency),
       linesJson = Value(linesJson),
       occurredAt = Value(occurredAt),
       recordedAt = Value(recordedAt);
  static Insertable<CachedFlowEntry> custom({
    Expression<String>? entryId,
    Expression<int>? year,
    Expression<int>? month,
    Expression<String>? direction,
    Expression<String>? description,
    Expression<double>? totalAmount,
    Expression<String>? totalCurrency,
    Expression<String>? linesJson,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (direction != null) 'direction': direction,
      if (description != null) 'description': description,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (totalCurrency != null) 'total_currency': totalCurrency,
      if (linesJson != null) 'lines_json': linesJson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedFlowEntriesCompanion copyWith({
    Value<String>? entryId,
    Value<int>? year,
    Value<int>? month,
    Value<String>? direction,
    Value<String?>? description,
    Value<double>? totalAmount,
    Value<String>? totalCurrency,
    Value<String>? linesJson,
    Value<DateTime>? occurredAt,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return CachedFlowEntriesCompanion(
      entryId: entryId ?? this.entryId,
      year: year ?? this.year,
      month: month ?? this.month,
      direction: direction ?? this.direction,
      description: description ?? this.description,
      totalAmount: totalAmount ?? this.totalAmount,
      totalCurrency: totalCurrency ?? this.totalCurrency,
      linesJson: linesJson ?? this.linesJson,
      occurredAt: occurredAt ?? this.occurredAt,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (totalCurrency.present) {
      map['total_currency'] = Variable<String>(totalCurrency.value);
    }
    if (linesJson.present) {
      map['lines_json'] = Variable<String>(linesJson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedFlowEntriesCompanion(')
          ..write('entryId: $entryId, ')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('direction: $direction, ')
          ..write('description: $description, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('totalCurrency: $totalCurrency, ')
          ..write('linesJson: $linesJson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedPeriodMetaTable extends CachedPeriodMeta
    with TableInfo<$CachedPeriodMetaTable, PeriodSyncMeta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPeriodMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<int> month = GeneratedColumn<int>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [year, month, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_period_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeriodSyncMeta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {year, month};
  @override
  PeriodSyncMeta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodSyncMeta(
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}month'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
    );
  }

  @override
  $CachedPeriodMetaTable createAlias(String alias) {
    return $CachedPeriodMetaTable(attachedDatabase, alias);
  }
}

class PeriodSyncMeta extends DataClass implements Insertable<PeriodSyncMeta> {
  final int year;
  final int month;

  /// Wall-clock time of the last successful server revalidation for this period.
  final DateTime lastSyncedAt;
  const PeriodSyncMeta({
    required this.year,
    required this.month,
    required this.lastSyncedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['year'] = Variable<int>(year);
    map['month'] = Variable<int>(month);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    return map;
  }

  CachedPeriodMetaCompanion toCompanion(bool nullToAbsent) {
    return CachedPeriodMetaCompanion(
      year: Value(year),
      month: Value(month),
      lastSyncedAt: Value(lastSyncedAt),
    );
  }

  factory PeriodSyncMeta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodSyncMeta(
      year: serializer.fromJson<int>(json['year']),
      month: serializer.fromJson<int>(json['month']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'year': serializer.toJson<int>(year),
      'month': serializer.toJson<int>(month),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
    };
  }

  PeriodSyncMeta copyWith({int? year, int? month, DateTime? lastSyncedAt}) =>
      PeriodSyncMeta(
        year: year ?? this.year,
        month: month ?? this.month,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
  PeriodSyncMeta copyWithCompanion(CachedPeriodMetaCompanion data) {
    return PeriodSyncMeta(
      year: data.year.present ? data.year.value : this.year,
      month: data.month.present ? data.month.value : this.month,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeriodSyncMeta(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(year, month, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodSyncMeta &&
          other.year == this.year &&
          other.month == this.month &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class CachedPeriodMetaCompanion extends UpdateCompanion<PeriodSyncMeta> {
  final Value<int> year;
  final Value<int> month;
  final Value<DateTime> lastSyncedAt;
  final Value<int> rowid;
  const CachedPeriodMetaCompanion({
    this.year = const Value.absent(),
    this.month = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPeriodMetaCompanion.insert({
    required int year,
    required int month,
    required DateTime lastSyncedAt,
    this.rowid = const Value.absent(),
  }) : year = Value(year),
       month = Value(month),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<PeriodSyncMeta> custom({
    Expression<int>? year,
    Expression<int>? month,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (year != null) 'year': year,
      if (month != null) 'month': month,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPeriodMetaCompanion copyWith({
    Value<int>? year,
    Value<int>? month,
    Value<DateTime>? lastSyncedAt,
    Value<int>? rowid,
  }) {
    return CachedPeriodMetaCompanion(
      year: year ?? this.year,
      month: month ?? this.month,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (month.present) {
      map['month'] = Variable<int>(month.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPeriodMetaCompanion(')
          ..write('year: $year, ')
          ..write('month: $month, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PendingOperationsTable pendingOperations =
      $PendingOperationsTable(this);
  late final $CachedFlowEntriesTable cachedFlowEntries =
      $CachedFlowEntriesTable(this);
  late final $CachedPeriodMetaTable cachedPeriodMeta = $CachedPeriodMetaTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    pendingOperations,
    cachedFlowEntries,
    cachedPeriodMeta,
  ];
}

typedef $$PendingOperationsTableCreateCompanionBuilder =
    PendingOperationsCompanion Function({
      required String id,
      required String kind,
      required String method,
      required String path,
      required String payload,
      required OperationStatus status,
      Value<int> attempts,
      Value<String?> lastError,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PendingOperationsTableUpdateCompanionBuilder =
    PendingOperationsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> method,
      Value<String> path,
      Value<String> payload,
      Value<OperationStatus> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OperationStatus, OperationStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingOperationsTable> {
  $$PendingOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OperationStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperation,
          $$PendingOperationsTableFilterComposer,
          $$PendingOperationsTableOrderingComposer,
          $$PendingOperationsTableAnnotationComposer,
          $$PendingOperationsTableCreateCompanionBuilder,
          $$PendingOperationsTableUpdateCompanionBuilder,
          (
            PendingOperation,
            BaseReferences<
              _$AppDatabase,
              $PendingOperationsTable,
              PendingOperation
            >,
          ),
          PendingOperation,
          PrefetchHooks Function()
        > {
  $$PendingOperationsTableTableManager(
    _$AppDatabase db,
    $PendingOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingOperationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<OperationStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingOperationsCompanion(
                id: id,
                kind: kind,
                method: method,
                path: path,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String method,
                required String path,
                required String payload,
                required OperationStatus status,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingOperationsCompanion.insert(
                id: id,
                kind: kind,
                method: method,
                path: path,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingOperationsTable,
      PendingOperation,
      $$PendingOperationsTableFilterComposer,
      $$PendingOperationsTableOrderingComposer,
      $$PendingOperationsTableAnnotationComposer,
      $$PendingOperationsTableCreateCompanionBuilder,
      $$PendingOperationsTableUpdateCompanionBuilder,
      (
        PendingOperation,
        BaseReferences<
          _$AppDatabase,
          $PendingOperationsTable,
          PendingOperation
        >,
      ),
      PendingOperation,
      PrefetchHooks Function()
    >;
typedef $$CachedFlowEntriesTableCreateCompanionBuilder =
    CachedFlowEntriesCompanion Function({
      required String entryId,
      required int year,
      required int month,
      required String direction,
      Value<String?> description,
      required double totalAmount,
      required String totalCurrency,
      required String linesJson,
      required DateTime occurredAt,
      required DateTime recordedAt,
      Value<int> rowid,
    });
typedef $$CachedFlowEntriesTableUpdateCompanionBuilder =
    CachedFlowEntriesCompanion Function({
      Value<String> entryId,
      Value<int> year,
      Value<int> month,
      Value<String> direction,
      Value<String?> description,
      Value<double> totalAmount,
      Value<String> totalCurrency,
      Value<String> linesJson,
      Value<DateTime> occurredAt,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

class $$CachedFlowEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedFlowEntriesTable> {
  $$CachedFlowEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get totalCurrency => $composableBuilder(
    column: $table.totalCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linesJson => $composableBuilder(
    column: $table.linesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedFlowEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedFlowEntriesTable> {
  $$CachedFlowEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get totalCurrency => $composableBuilder(
    column: $table.totalCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linesJson => $composableBuilder(
    column: $table.linesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedFlowEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedFlowEntriesTable> {
  $$CachedFlowEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get totalCurrency => $composableBuilder(
    column: $table.totalCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linesJson =>
      $composableBuilder(column: $table.linesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$CachedFlowEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedFlowEntriesTable,
          CachedFlowEntry,
          $$CachedFlowEntriesTableFilterComposer,
          $$CachedFlowEntriesTableOrderingComposer,
          $$CachedFlowEntriesTableAnnotationComposer,
          $$CachedFlowEntriesTableCreateCompanionBuilder,
          $$CachedFlowEntriesTableUpdateCompanionBuilder,
          (
            CachedFlowEntry,
            BaseReferences<
              _$AppDatabase,
              $CachedFlowEntriesTable,
              CachedFlowEntry
            >,
          ),
          CachedFlowEntry,
          PrefetchHooks Function()
        > {
  $$CachedFlowEntriesTableTableManager(
    _$AppDatabase db,
    $CachedFlowEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedFlowEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedFlowEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedFlowEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<String> totalCurrency = const Value.absent(),
                Value<String> linesJson = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedFlowEntriesCompanion(
                entryId: entryId,
                year: year,
                month: month,
                direction: direction,
                description: description,
                totalAmount: totalAmount,
                totalCurrency: totalCurrency,
                linesJson: linesJson,
                occurredAt: occurredAt,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required int year,
                required int month,
                required String direction,
                Value<String?> description = const Value.absent(),
                required double totalAmount,
                required String totalCurrency,
                required String linesJson,
                required DateTime occurredAt,
                required DateTime recordedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedFlowEntriesCompanion.insert(
                entryId: entryId,
                year: year,
                month: month,
                direction: direction,
                description: description,
                totalAmount: totalAmount,
                totalCurrency: totalCurrency,
                linesJson: linesJson,
                occurredAt: occurredAt,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedFlowEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedFlowEntriesTable,
      CachedFlowEntry,
      $$CachedFlowEntriesTableFilterComposer,
      $$CachedFlowEntriesTableOrderingComposer,
      $$CachedFlowEntriesTableAnnotationComposer,
      $$CachedFlowEntriesTableCreateCompanionBuilder,
      $$CachedFlowEntriesTableUpdateCompanionBuilder,
      (
        CachedFlowEntry,
        BaseReferences<_$AppDatabase, $CachedFlowEntriesTable, CachedFlowEntry>,
      ),
      CachedFlowEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedPeriodMetaTableCreateCompanionBuilder =
    CachedPeriodMetaCompanion Function({
      required int year,
      required int month,
      required DateTime lastSyncedAt,
      Value<int> rowid,
    });
typedef $$CachedPeriodMetaTableUpdateCompanionBuilder =
    CachedPeriodMetaCompanion Function({
      Value<int> year,
      Value<int> month,
      Value<DateTime> lastSyncedAt,
      Value<int> rowid,
    });

class $$CachedPeriodMetaTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPeriodMetaTable> {
  $$CachedPeriodMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPeriodMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPeriodMetaTable> {
  $$CachedPeriodMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPeriodMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPeriodMetaTable> {
  $$CachedPeriodMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );
}

class $$CachedPeriodMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedPeriodMetaTable,
          PeriodSyncMeta,
          $$CachedPeriodMetaTableFilterComposer,
          $$CachedPeriodMetaTableOrderingComposer,
          $$CachedPeriodMetaTableAnnotationComposer,
          $$CachedPeriodMetaTableCreateCompanionBuilder,
          $$CachedPeriodMetaTableUpdateCompanionBuilder,
          (
            PeriodSyncMeta,
            BaseReferences<
              _$AppDatabase,
              $CachedPeriodMetaTable,
              PeriodSyncMeta
            >,
          ),
          PeriodSyncMeta,
          PrefetchHooks Function()
        > {
  $$CachedPeriodMetaTableTableManager(
    _$AppDatabase db,
    $CachedPeriodMetaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPeriodMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPeriodMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPeriodMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> year = const Value.absent(),
                Value<int> month = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPeriodMetaCompanion(
                year: year,
                month: month,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int year,
                required int month,
                required DateTime lastSyncedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedPeriodMetaCompanion.insert(
                year: year,
                month: month,
                lastSyncedAt: lastSyncedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPeriodMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedPeriodMetaTable,
      PeriodSyncMeta,
      $$CachedPeriodMetaTableFilterComposer,
      $$CachedPeriodMetaTableOrderingComposer,
      $$CachedPeriodMetaTableAnnotationComposer,
      $$CachedPeriodMetaTableCreateCompanionBuilder,
      $$CachedPeriodMetaTableUpdateCompanionBuilder,
      (
        PeriodSyncMeta,
        BaseReferences<_$AppDatabase, $CachedPeriodMetaTable, PeriodSyncMeta>,
      ),
      PeriodSyncMeta,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PendingOperationsTableTableManager get pendingOperations =>
      $$PendingOperationsTableTableManager(_db, _db.pendingOperations);
  $$CachedFlowEntriesTableTableManager get cachedFlowEntries =>
      $$CachedFlowEntriesTableTableManager(_db, _db.cachedFlowEntries);
  $$CachedPeriodMetaTableTableManager get cachedPeriodMeta =>
      $$CachedPeriodMetaTableTableManager(_db, _db.cachedPeriodMeta);
}
