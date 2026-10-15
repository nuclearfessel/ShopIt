// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ShoppingListsTable extends ShoppingLists
    with TableInfo<$ShoppingListsTable, ShoppingList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, updatedAt, deletedAt, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $ShoppingListsTable createAlias(String alias) {
    return $ShoppingListsTable(attachedDatabase, alias);
  }
}

class ShoppingList extends DataClass implements Insertable<ShoppingList> {
  final String id;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String name;
  const ShoppingList({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    return map;
  }

  ShoppingListsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingListsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
    );
  }

  factory ShoppingList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingList(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
    };
  }

  ShoppingList copyWith({
    String? id,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
  }) => ShoppingList(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
  );
  ShoppingList copyWithCompanion(ShoppingListsCompanion data) {
    return ShoppingList(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingList(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, updatedAt, deletedAt, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingList &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name);
}

class ShoppingListsCompanion extends UpdateCompanion<ShoppingList> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<int> rowid;
  const ShoppingListsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShoppingListsCompanion.insert({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String name,
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ShoppingList> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShoppingListsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return ShoppingListsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingListsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shopping_lists (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _checkedMeta = const VerificationMeta(
    'checked',
  );
  @override
  late final GeneratedColumn<bool> checked = GeneratedColumn<bool>(
    'checked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("checked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _taxableMeta = const VerificationMeta(
    'taxable',
  );
  @override
  late final GeneratedColumn<bool> taxable = GeneratedColumn<bool>(
    'taxable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("taxable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasCouponMeta = const VerificationMeta(
    'hasCoupon',
  );
  @override
  late final GeneratedColumn<bool> hasCoupon = GeneratedColumn<bool>(
    'has_coupon',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_coupon" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    listId,
    name,
    quantity,
    unit,
    checked,
    category,
    price,
    note,
    taxable,
    hasCoupon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShoppingItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('checked')) {
      context.handle(
        _checkedMeta,
        checked.isAcceptableOrUnknown(data['checked']!, _checkedMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('taxable')) {
      context.handle(
        _taxableMeta,
        taxable.isAcceptableOrUnknown(data['taxable']!, _taxableMeta),
      );
    }
    if (data.containsKey('has_coupon')) {
      context.handle(
        _hasCouponMeta,
        hasCoupon.isAcceptableOrUnknown(data['has_coupon']!, _hasCouponMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      checked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}checked'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      taxable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}taxable'],
      )!,
      hasCoupon: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_coupon'],
      )!,
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItem extends DataClass implements Insertable<ShoppingItem> {
  final String id;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String listId;
  final String name;
  final double quantity;
  final String unit;
  final bool checked;
  final String category;

  /// Price of one unit; the line total is price * quantity.
  final double? price;
  final String note;

  /// "Item has sales tax" and "I have a coupon" flags from the item editor.
  final bool taxable;
  final bool hasCoupon;
  const ShoppingItem({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.checked,
    required this.category,
    this.price,
    required this.note,
    required this.taxable,
    required this.hasCoupon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['list_id'] = Variable<String>(listId);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    map['checked'] = Variable<bool>(checked);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    map['note'] = Variable<String>(note);
    map['taxable'] = Variable<bool>(taxable);
    map['has_coupon'] = Variable<bool>(hasCoupon);
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      listId: Value(listId),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      checked: Value(checked),
      category: Value(category),
      price: price == null && nullToAbsent
          ? const Value.absent()
          : Value(price),
      note: Value(note),
      taxable: Value(taxable),
      hasCoupon: Value(hasCoupon),
    );
  }

  factory ShoppingItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItem(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      listId: serializer.fromJson<String>(json['listId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      checked: serializer.fromJson<bool>(json['checked']),
      category: serializer.fromJson<String>(json['category']),
      price: serializer.fromJson<double?>(json['price']),
      note: serializer.fromJson<String>(json['note']),
      taxable: serializer.fromJson<bool>(json['taxable']),
      hasCoupon: serializer.fromJson<bool>(json['hasCoupon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'listId': serializer.toJson<String>(listId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'checked': serializer.toJson<bool>(checked),
      'category': serializer.toJson<String>(category),
      'price': serializer.toJson<double?>(price),
      'note': serializer.toJson<String>(note),
      'taxable': serializer.toJson<bool>(taxable),
      'hasCoupon': serializer.toJson<bool>(hasCoupon),
    };
  }

  ShoppingItem copyWith({
    String? id,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? listId,
    String? name,
    double? quantity,
    String? unit,
    bool? checked,
    String? category,
    Value<double?> price = const Value.absent(),
    String? note,
    bool? taxable,
    bool? hasCoupon,
  }) => ShoppingItem(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    listId: listId ?? this.listId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    checked: checked ?? this.checked,
    category: category ?? this.category,
    price: price.present ? price.value : this.price,
    note: note ?? this.note,
    taxable: taxable ?? this.taxable,
    hasCoupon: hasCoupon ?? this.hasCoupon,
  );
  ShoppingItem copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItem(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      listId: data.listId.present ? data.listId.value : this.listId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      checked: data.checked.present ? data.checked.value : this.checked,
      category: data.category.present ? data.category.value : this.category,
      price: data.price.present ? data.price.value : this.price,
      note: data.note.present ? data.note.value : this.note,
      taxable: data.taxable.present ? data.taxable.value : this.taxable,
      hasCoupon: data.hasCoupon.present ? data.hasCoupon.value : this.hasCoupon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItem(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('checked: $checked, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('note: $note, ')
          ..write('taxable: $taxable, ')
          ..write('hasCoupon: $hasCoupon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    listId,
    name,
    quantity,
    unit,
    checked,
    category,
    price,
    note,
    taxable,
    hasCoupon,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItem &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.listId == this.listId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.checked == this.checked &&
          other.category == this.category &&
          other.price == this.price &&
          other.note == this.note &&
          other.taxable == this.taxable &&
          other.hasCoupon == this.hasCoupon);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItem> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> listId;
  final Value<String> name;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<bool> checked;
  final Value<String> category;
  final Value<double?> price;
  final Value<String> note;
  final Value<bool> taxable;
  final Value<bool> hasCoupon;
  final Value<int> rowid;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.listId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.checked = const Value.absent(),
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.note = const Value.absent(),
    this.taxable = const Value.absent(),
    this.hasCoupon = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String listId,
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.checked = const Value.absent(),
    this.category = const Value.absent(),
    this.price = const Value.absent(),
    this.note = const Value.absent(),
    this.taxable = const Value.absent(),
    this.hasCoupon = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : listId = Value(listId),
       name = Value(name);
  static Insertable<ShoppingItem> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? listId,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<bool>? checked,
    Expression<String>? category,
    Expression<double>? price,
    Expression<String>? note,
    Expression<bool>? taxable,
    Expression<bool>? hasCoupon,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (listId != null) 'list_id': listId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (checked != null) 'checked': checked,
      if (category != null) 'category': category,
      if (price != null) 'price': price,
      if (note != null) 'note': note,
      if (taxable != null) 'taxable': taxable,
      if (hasCoupon != null) 'has_coupon': hasCoupon,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShoppingItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? listId,
    Value<String>? name,
    Value<double>? quantity,
    Value<String>? unit,
    Value<bool>? checked,
    Value<String>? category,
    Value<double?>? price,
    Value<String>? note,
    Value<bool>? taxable,
    Value<bool>? hasCoupon,
    Value<int>? rowid,
  }) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
      category: category ?? this.category,
      price: price ?? this.price,
      note: note ?? this.note,
      taxable: taxable ?? this.taxable,
      hasCoupon: hasCoupon ?? this.hasCoupon,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (checked.present) {
      map['checked'] = Variable<bool>(checked.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (taxable.present) {
      map['taxable'] = Variable<bool>(taxable.value);
    }
    if (hasCoupon.present) {
      map['has_coupon'] = Variable<bool>(hasCoupon.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('listId: $listId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('checked: $checked, ')
          ..write('category: $category, ')
          ..write('price: $price, ')
          ..write('note: $note, ')
          ..write('taxable: $taxable, ')
          ..write('hasCoupon: $hasCoupon, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PantryItemsTable extends PantryItems
    with TableInfo<$PantryItemsTable, PantryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PantryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _expiryDateMeta = const VerificationMeta(
    'expiryDate',
  );
  @override
  late final GeneratedColumn<DateTime> expiryDate = GeneratedColumn<DateTime>(
    'expiry_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    name,
    quantity,
    unit,
    expiryDate,
    location,
    category,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pantry_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PantryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('expiry_date')) {
      context.handle(
        _expiryDateMeta,
        expiryDate.isAcceptableOrUnknown(data['expiry_date']!, _expiryDateMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PantryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PantryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      expiryDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expiry_date'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $PantryItemsTable createAlias(String alias) {
    return $PantryItemsTable(attachedDatabase, alias);
  }
}

class PantryItem extends DataClass implements Insertable<PantryItem> {
  final String id;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String name;
  final double quantity;
  final String unit;
  final DateTime? expiryDate;
  final String location;
  final String category;
  final String note;
  const PantryItem({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.quantity,
    required this.unit,
    this.expiryDate,
    required this.location,
    required this.category,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || expiryDate != null) {
      map['expiry_date'] = Variable<DateTime>(expiryDate);
    }
    map['location'] = Variable<String>(location);
    map['category'] = Variable<String>(category);
    map['note'] = Variable<String>(note);
    return map;
  }

  PantryItemsCompanion toCompanion(bool nullToAbsent) {
    return PantryItemsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      expiryDate: expiryDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expiryDate),
      location: Value(location),
      category: Value(category),
      note: Value(note),
    );
  }

  factory PantryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PantryItem(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      expiryDate: serializer.fromJson<DateTime?>(json['expiryDate']),
      location: serializer.fromJson<String>(json['location']),
      category: serializer.fromJson<String>(json['category']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'expiryDate': serializer.toJson<DateTime?>(expiryDate),
      'location': serializer.toJson<String>(location),
      'category': serializer.toJson<String>(category),
      'note': serializer.toJson<String>(note),
    };
  }

  PantryItem copyWith({
    String? id,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
    double? quantity,
    String? unit,
    Value<DateTime?> expiryDate = const Value.absent(),
    String? location,
    String? category,
    String? note,
  }) => PantryItem(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    expiryDate: expiryDate.present ? expiryDate.value : this.expiryDate,
    location: location ?? this.location,
    category: category ?? this.category,
    note: note ?? this.note,
  );
  PantryItem copyWithCompanion(PantryItemsCompanion data) {
    return PantryItem(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      expiryDate: data.expiryDate.present
          ? data.expiryDate.value
          : this.expiryDate,
      location: data.location.present ? data.location.value : this.location,
      category: data.category.present ? data.category.value : this.category,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PantryItem(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('location: $location, ')
          ..write('category: $category, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    name,
    quantity,
    unit,
    expiryDate,
    location,
    category,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PantryItem &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.expiryDate == this.expiryDate &&
          other.location == this.location &&
          other.category == this.category &&
          other.note == this.note);
}

class PantryItemsCompanion extends UpdateCompanion<PantryItem> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<DateTime?> expiryDate;
  final Value<String> location;
  final Value<String> category;
  final Value<String> note;
  final Value<int> rowid;
  const PantryItemsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.location = const Value.absent(),
    this.category = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PantryItemsCompanion.insert({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.expiryDate = const Value.absent(),
    this.location = const Value.absent(),
    this.category = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PantryItem> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<DateTime>? expiryDate,
    Expression<String>? location,
    Expression<String>? category,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (expiryDate != null) 'expiry_date': expiryDate,
      if (location != null) 'location': location,
      if (category != null) 'category': category,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PantryItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<double>? quantity,
    Value<String>? unit,
    Value<DateTime?>? expiryDate,
    Value<String>? location,
    Value<String>? category,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return PantryItemsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      location: location ?? this.location,
      category: category ?? this.category,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (expiryDate.present) {
      map['expiry_date'] = Variable<DateTime>(expiryDate.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PantryItemsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('expiryDate: $expiryDate, ')
          ..write('location: $location, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [name, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String name;
  final int sortOrder;
  const Category({required this.name, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(name: Value(name), sortOrder: Value(sortOrder));
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Category copyWith({String? name, int? sortOrder}) =>
      Category(name: name ?? this.name, sortOrder: sortOrder ?? this.sortOrder);
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String name,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       sortOrder = Value(sortOrder);
  static Insertable<Category> custom({
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? name,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatalogItemsTable extends CatalogItems
    with TableInfo<$CatalogItemsTable, CatalogItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatalogItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newId,
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
    requiredDuringInsert: false,
    clientDefault: DateTime.now,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultUnitMeta = const VerificationMeta(
    'defaultUnit',
  );
  @override
  late final GeneratedColumn<String> defaultUnit = GeneratedColumn<String>(
    'default_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _parentNameMeta = const VerificationMeta(
    'parentName',
  );
  @override
  late final GeneratedColumn<String> parentName = GeneratedColumn<String>(
    'parent_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAt,
    deletedAt,
    name,
    category,
    defaultUnit,
    isCustom,
    parentName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'catalog_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatalogItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('default_unit')) {
      context.handle(
        _defaultUnitMeta,
        defaultUnit.isAcceptableOrUnknown(
          data['default_unit']!,
          _defaultUnitMeta,
        ),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('parent_name')) {
      context.handle(
        _parentNameMeta,
        parentName.isAcceptableOrUnknown(data['parent_name']!, _parentNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatalogItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatalogItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      defaultUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_unit'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      parentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_name'],
      )!,
    );
  }

  @override
  $CatalogItemsTable createAlias(String alias) {
    return $CatalogItemsTable(attachedDatabase, alias);
  }
}

class CatalogItem extends DataClass implements Insertable<CatalogItem> {
  final String id;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String name;
  final String category;
  final String defaultUnit;
  final bool isCustom;

  /// For a variant (a type, cut or flavour) the group it belongs to, e.g.
  /// "Onions" for "Red onions". Empty for top-level items.
  final String parentName;
  const CatalogItem({
    required this.id,
    required this.updatedAt,
    this.deletedAt,
    required this.name,
    required this.category,
    required this.defaultUnit,
    required this.isCustom,
    required this.parentName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    map['default_unit'] = Variable<String>(defaultUnit);
    map['is_custom'] = Variable<bool>(isCustom);
    map['parent_name'] = Variable<String>(parentName);
    return map;
  }

  CatalogItemsCompanion toCompanion(bool nullToAbsent) {
    return CatalogItemsCompanion(
      id: Value(id),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      name: Value(name),
      category: Value(category),
      defaultUnit: Value(defaultUnit),
      isCustom: Value(isCustom),
      parentName: Value(parentName),
    );
  }

  factory CatalogItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatalogItem(
      id: serializer.fromJson<String>(json['id']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      defaultUnit: serializer.fromJson<String>(json['defaultUnit']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      parentName: serializer.fromJson<String>(json['parentName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'defaultUnit': serializer.toJson<String>(defaultUnit),
      'isCustom': serializer.toJson<bool>(isCustom),
      'parentName': serializer.toJson<String>(parentName),
    };
  }

  CatalogItem copyWith({
    String? id,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    String? name,
    String? category,
    String? defaultUnit,
    bool? isCustom,
    String? parentName,
  }) => CatalogItem(
    id: id ?? this.id,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    name: name ?? this.name,
    category: category ?? this.category,
    defaultUnit: defaultUnit ?? this.defaultUnit,
    isCustom: isCustom ?? this.isCustom,
    parentName: parentName ?? this.parentName,
  );
  CatalogItem copyWithCompanion(CatalogItemsCompanion data) {
    return CatalogItem(
      id: data.id.present ? data.id.value : this.id,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      defaultUnit: data.defaultUnit.present
          ? data.defaultUnit.value
          : this.defaultUnit,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      parentName: data.parentName.present
          ? data.parentName.value
          : this.parentName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatalogItem(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('isCustom: $isCustom, ')
          ..write('parentName: $parentName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAt,
    deletedAt,
    name,
    category,
    defaultUnit,
    isCustom,
    parentName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatalogItem &&
          other.id == this.id &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.name == this.name &&
          other.category == this.category &&
          other.defaultUnit == this.defaultUnit &&
          other.isCustom == this.isCustom &&
          other.parentName == this.parentName);
}

class CatalogItemsCompanion extends UpdateCompanion<CatalogItem> {
  final Value<String> id;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String> name;
  final Value<String> category;
  final Value<String> defaultUnit;
  final Value<bool> isCustom;
  final Value<String> parentName;
  final Value<int> rowid;
  const CatalogItemsCompanion({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.defaultUnit = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.parentName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatalogItemsCompanion.insert({
    this.id = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required String name,
    required String category,
    this.defaultUnit = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.parentName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       category = Value(category);
  static Insertable<CatalogItem> custom({
    Expression<String>? id,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? defaultUnit,
    Expression<bool>? isCustom,
    Expression<String>? parentName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (defaultUnit != null) 'default_unit': defaultUnit,
      if (isCustom != null) 'is_custom': isCustom,
      if (parentName != null) 'parent_name': parentName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatalogItemsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String>? name,
    Value<String>? category,
    Value<String>? defaultUnit,
    Value<bool>? isCustom,
    Value<String>? parentName,
    Value<int>? rowid,
  }) {
    return CatalogItemsCompanion(
      id: id ?? this.id,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      name: name ?? this.name,
      category: category ?? this.category,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      isCustom: isCustom ?? this.isCustom,
      parentName: parentName ?? this.parentName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (defaultUnit.present) {
      map['default_unit'] = Variable<String>(defaultUnit.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (parentName.present) {
      map['parent_name'] = Variable<String>(parentName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatalogItemsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('defaultUnit: $defaultUnit, ')
          ..write('isCustom: $isCustom, ')
          ..write('parentName: $parentName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ShoppingListsTable shoppingLists = $ShoppingListsTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $PantryItemsTable pantryItems = $PantryItemsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $CatalogItemsTable catalogItems = $CatalogItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shoppingLists,
    shoppingItems,
    pantryItems,
    categories,
    catalogItems,
  ];
}

typedef $$ShoppingListsTableCreateCompanionBuilder =
    ShoppingListsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      required String name,
      Value<int> rowid,
    });
typedef $$ShoppingListsTableUpdateCompanionBuilder =
    ShoppingListsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> name,
      Value<int> rowid,
    });

final class $$ShoppingListsTableReferences
    extends BaseReferences<_$AppDatabase, $ShoppingListsTable, ShoppingList> {
  $$ShoppingListsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ShoppingItemsTable, List<ShoppingItem>>
  _shoppingItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shoppingItems,
    aliasName: 'shopping_lists__id__shopping_items__list_id',
  );

  $$ShoppingItemsTableProcessedTableManager get shoppingItemsRefs {
    final manager = $$ShoppingItemsTableTableManager(
      $_db,
      $_db.shoppingItems,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shoppingItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ShoppingListsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> shoppingItemsRefs(
    Expression<bool> Function($$ShoppingItemsTableFilterComposer f) f,
  ) {
    final $$ShoppingItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShoppingListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingListsTable> {
  $$ShoppingListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> shoppingItemsRefs<T extends Object>(
    Expression<T> Function($$ShoppingItemsTableAnnotationComposer a) f,
  ) {
    final $$ShoppingItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shoppingItems,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ShoppingListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingListsTable,
          ShoppingList,
          $$ShoppingListsTableFilterComposer,
          $$ShoppingListsTableOrderingComposer,
          $$ShoppingListsTableAnnotationComposer,
          $$ShoppingListsTableCreateCompanionBuilder,
          $$ShoppingListsTableUpdateCompanionBuilder,
          (ShoppingList, $$ShoppingListsTableReferences),
          ShoppingList,
          PrefetchHooks Function({bool shoppingItemsRefs})
        > {
  $$ShoppingListsTableTableManager(_$AppDatabase db, $ShoppingListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShoppingListsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => ShoppingListsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShoppingListsTable, ShoppingList>(table),
                  $$ShoppingListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({shoppingItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (shoppingItemsRefs) db.shoppingItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (shoppingItemsRefs)
                    await $_getPrefetchedData<
                      ShoppingList,
                      $ShoppingListsTable,
                      ShoppingItem
                    >(
                      currentTable: table,
                      referencedTable: $$ShoppingListsTableReferences
                          ._shoppingItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ShoppingListsTableReferences(
                            db,
                            table,
                            p0,
                          ).shoppingItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingListsTable,
      ShoppingList,
      $$ShoppingListsTableFilterComposer,
      $$ShoppingListsTableOrderingComposer,
      $$ShoppingListsTableAnnotationComposer,
      $$ShoppingListsTableCreateCompanionBuilder,
      $$ShoppingListsTableUpdateCompanionBuilder,
      (ShoppingList, $$ShoppingListsTableReferences),
      ShoppingList,
      PrefetchHooks Function({bool shoppingItemsRefs})
    >;
typedef $$ShoppingItemsTableCreateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      required String listId,
      required String name,
      Value<double> quantity,
      Value<String> unit,
      Value<bool> checked,
      Value<String> category,
      Value<double?> price,
      Value<String> note,
      Value<bool> taxable,
      Value<bool> hasCoupon,
      Value<int> rowid,
    });
typedef $$ShoppingItemsTableUpdateCompanionBuilder =
    ShoppingItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> listId,
      Value<String> name,
      Value<double> quantity,
      Value<String> unit,
      Value<bool> checked,
      Value<String> category,
      Value<double?> price,
      Value<String> note,
      Value<bool> taxable,
      Value<bool> hasCoupon,
      Value<int> rowid,
    });

final class $$ShoppingItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItem> {
  $$ShoppingItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ShoppingListsTable _listIdTable(_$AppDatabase db) => db.shoppingLists
      .createAlias('shopping_items__list_id__shopping_lists__id');

  $$ShoppingListsTableProcessedTableManager get listId {
    final $_column = $_itemColumn<String>('list_id')!;

    final manager = $$ShoppingListsTableTableManager(
      $_db,
      $_db.shoppingLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get checked => $composableBuilder(
    column: $table.checked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get taxable => $composableBuilder(
    column: $table.taxable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasCoupon => $composableBuilder(
    column: $table.hasCoupon,
    builder: (column) => ColumnFilters(column),
  );

  $$ShoppingListsTableFilterComposer get listId {
    final $$ShoppingListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableFilterComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get checked => $composableBuilder(
    column: $table.checked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get taxable => $composableBuilder(
    column: $table.taxable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasCoupon => $composableBuilder(
    column: $table.hasCoupon,
    builder: (column) => ColumnOrderings(column),
  );

  $$ShoppingListsTableOrderingComposer get listId {
    final $$ShoppingListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableOrderingComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get taxable =>
      $composableBuilder(column: $table.taxable, builder: (column) => column);

  GeneratedColumn<bool> get hasCoupon =>
      $composableBuilder(column: $table.hasCoupon, builder: (column) => column);

  $$ShoppingListsTableAnnotationComposer get listId {
    final $$ShoppingListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.shoppingLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShoppingListsTableAnnotationComposer(
            $db: $db,
            $table: $db.shoppingLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShoppingItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShoppingItemsTable,
          ShoppingItem,
          $$ShoppingItemsTableFilterComposer,
          $$ShoppingItemsTableOrderingComposer,
          $$ShoppingItemsTableAnnotationComposer,
          $$ShoppingItemsTableCreateCompanionBuilder,
          $$ShoppingItemsTableUpdateCompanionBuilder,
          (ShoppingItem, $$ShoppingItemsTableReferences),
          ShoppingItem,
          PrefetchHooks Function({bool listId})
        > {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<bool> checked = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> taxable = const Value.absent(),
                Value<bool> hasCoupon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShoppingItemsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                checked: checked,
                category: category,
                price: price,
                note: note,
                taxable: taxable,
                hasCoupon: hasCoupon,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String listId,
                required String name,
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<bool> checked = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<double?> price = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> taxable = const Value.absent(),
                Value<bool> hasCoupon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShoppingItemsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                checked: checked,
                category: category,
                price: price,
                note: note,
                taxable: taxable,
                hasCoupon: hasCoupon,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShoppingItemsTable, ShoppingItem>(table),
                  $$ShoppingItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.listId,
                        referencedTable: $$ShoppingItemsTableReferences
                            ._listIdTable(db),
                        referencedColumn: $$ShoppingItemsTableReferences
                            ._listIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShoppingItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShoppingItemsTable,
      ShoppingItem,
      $$ShoppingItemsTableFilterComposer,
      $$ShoppingItemsTableOrderingComposer,
      $$ShoppingItemsTableAnnotationComposer,
      $$ShoppingItemsTableCreateCompanionBuilder,
      $$ShoppingItemsTableUpdateCompanionBuilder,
      (ShoppingItem, $$ShoppingItemsTableReferences),
      ShoppingItem,
      PrefetchHooks Function({bool listId})
    >;
typedef $$PantryItemsTableCreateCompanionBuilder =
    PantryItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      required String name,
      Value<double> quantity,
      Value<String> unit,
      Value<DateTime?> expiryDate,
      Value<String> location,
      Value<String> category,
      Value<String> note,
      Value<int> rowid,
    });
typedef $$PantryItemsTableUpdateCompanionBuilder =
    PantryItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> name,
      Value<double> quantity,
      Value<String> unit,
      Value<DateTime?> expiryDate,
      Value<String> location,
      Value<String> category,
      Value<String> note,
      Value<int> rowid,
    });

class $$PantryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PantryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PantryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PantryItemsTable> {
  $$PantryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get expiryDate => $composableBuilder(
    column: $table.expiryDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$PantryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PantryItemsTable,
          PantryItem,
          $$PantryItemsTableFilterComposer,
          $$PantryItemsTableOrderingComposer,
          $$PantryItemsTableAnnotationComposer,
          $$PantryItemsTableCreateCompanionBuilder,
          $$PantryItemsTableUpdateCompanionBuilder,
          (
            PantryItem,
            BaseReferences<_$AppDatabase, $PantryItemsTable, PantryItem>,
          ),
          PantryItem,
          PrefetchHooks Function()
        > {
  $$PantryItemsTableTableManager(_$AppDatabase db, $PantryItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PantryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PantryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PantryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PantryItemsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                quantity: quantity,
                unit: unit,
                expiryDate: expiryDate,
                location: location,
                category: category,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String name,
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<DateTime?> expiryDate = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PantryItemsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                quantity: quantity,
                unit: unit,
                expiryDate: expiryDate,
                location: location,
                category: category,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PantryItemsTable, PantryItem>(table),
                  BaseReferences<_$AppDatabase, $PantryItemsTable, PantryItem>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PantryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PantryItemsTable,
      PantryItem,
      $$PantryItemsTableFilterComposer,
      $$PantryItemsTableOrderingComposer,
      $$PantryItemsTableAnnotationComposer,
      $$PantryItemsTableCreateCompanionBuilder,
      $$PantryItemsTableUpdateCompanionBuilder,
      (
        PantryItem,
        BaseReferences<_$AppDatabase, $PantryItemsTable, PantryItem>,
      ),
      PantryItem,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  required String name,
  required int sortOrder,
  Value<int> rowid,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> name,
  Value<int> sortOrder,
  Value<int> rowid,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                name: name,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  BaseReferences<_$AppDatabase, $CategoriesTable, Category>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$CatalogItemsTableCreateCompanionBuilder =
    CatalogItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      required String name,
      required String category,
      Value<String> defaultUnit,
      Value<bool> isCustom,
      Value<String> parentName,
      Value<int> rowid,
    });
typedef $$CatalogItemsTableUpdateCompanionBuilder =
    CatalogItemsCompanion Function({
      Value<String> id,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String> name,
      Value<String> category,
      Value<String> defaultUnit,
      Value<bool> isCustom,
      Value<String> parentName,
      Value<int> rowid,
    });

class $$CatalogItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CatalogItemsTable> {
  $$CatalogItemsTableFilterComposer({
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

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultUnit => $composableBuilder(
    column: $table.defaultUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatalogItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatalogItemsTable> {
  $$CatalogItemsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultUnit => $composableBuilder(
    column: $table.defaultUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatalogItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatalogItemsTable> {
  $$CatalogItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get defaultUnit => $composableBuilder(
    column: $table.defaultUnit,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<String> get parentName => $composableBuilder(
    column: $table.parentName,
    builder: (column) => column,
  );
}

class $$CatalogItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatalogItemsTable,
          CatalogItem,
          $$CatalogItemsTableFilterComposer,
          $$CatalogItemsTableOrderingComposer,
          $$CatalogItemsTableAnnotationComposer,
          $$CatalogItemsTableCreateCompanionBuilder,
          $$CatalogItemsTableUpdateCompanionBuilder,
          (
            CatalogItem,
            BaseReferences<_$AppDatabase, $CatalogItemsTable, CatalogItem>,
          ),
          CatalogItem,
          PrefetchHooks Function()
        > {
  $$CatalogItemsTableTableManager(_$AppDatabase db, $CatalogItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatalogItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatalogItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatalogItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> defaultUnit = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> parentName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogItemsCompanion(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                category: category,
                defaultUnit: defaultUnit,
                isCustom: isCustom,
                parentName: parentName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                required String name,
                required String category,
                Value<String> defaultUnit = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> parentName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatalogItemsCompanion.insert(
                id: id,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                name: name,
                category: category,
                defaultUnit: defaultUnit,
                isCustom: isCustom,
                parentName: parentName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CatalogItemsTable, CatalogItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CatalogItemsTable,
                    CatalogItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatalogItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatalogItemsTable,
      CatalogItem,
      $$CatalogItemsTableFilterComposer,
      $$CatalogItemsTableOrderingComposer,
      $$CatalogItemsTableAnnotationComposer,
      $$CatalogItemsTableCreateCompanionBuilder,
      $$CatalogItemsTableUpdateCompanionBuilder,
      (
        CatalogItem,
        BaseReferences<_$AppDatabase, $CatalogItemsTable, CatalogItem>,
      ),
      CatalogItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ShoppingListsTableTableManager get shoppingLists =>
      $$ShoppingListsTableTableManager(_db, _db.shoppingLists);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$PantryItemsTableTableManager get pantryItems =>
      $$PantryItemsTableTableManager(_db, _db.pantryItems);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$CatalogItemsTableTableManager get catalogItems =>
      $$CatalogItemsTableTableManager(_db, _db.catalogItems);
}
