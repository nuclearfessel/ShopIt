import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_seed.dart';
import '../../data/category_order.dart';
import '../../data/list_csv.dart';
import '../../services/file_service.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/category_header.dart';
import '../../ui/dialogs.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/choice_field.dart';
import '../../ui/tip.dart';
import '../../ui/undo_snack_bar.dart';
import '../catalog/catalog_suggestions.dart';
import '../catalog/item_editor.dart';
import '../categories/category_color_dialog.dart';
import '../categories/manage_categories_dialog.dart';
import '../lists/manage_lists_dialog.dart';
import '../lists/move_copy_dialog.dart';
import '../settings/settings_dialog.dart';
import 'items_setting_dialog.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  String? _listId;

  Future<void> _newList() async {
    final name = await askNameDialog(context, title: 'New pantry list');
    if (name == null) return;
    final id = await ref.read(databaseProvider).addList(name, kind: 'pantry');
    if (mounted) setState(() => _listId = id);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(pantryListsProvider);
    final settingsButton = IconButton(
      tooltip: 'Settings',
      icon: const KeylineIcon(KeylineIcons.settings),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const SettingsDialog(),
      ),
    );
    return lists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (all.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Pantry'),
              actions: [settingsButton],
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No pantry lists yet'),
                  const SizedBox(height: 12),
                  Tip(
                    'Create your first pantry list',
                    child: FilledButton.icon(
                      onPressed: _newList,
                      icon: const KeylineIcon(KeylineIcons.listPlus),
                      label: const Text('Create a pantry list'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final current = all.firstWhere(
          (l) => l.id == _listId,
          orElse: () => all.first,
        );
        return _PantryBody(
          lists: all,
          current: current,
          onSelect: (id) => setState(() => _listId = id),
          onNewList: _newList,
          onListGone: () => setState(() => _listId = null),
          settingsButton: settingsButton,
        );
      },
    );
  }
}

class _PantryBody extends ConsumerWidget {
  const _PantryBody({
    required this.lists,
    required this.current,
    required this.onSelect,
    required this.onNewList,
    required this.onListGone,
    required this.settingsButton,
  });

  final List<ShoppingList> lists;
  final ShoppingList current;
  final ValueChanged<String> onSelect;
  final Future<void> Function() onNewList;
  final VoidCallback onListGone;
  final Widget settingsButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final items = ref.watch(pantryProvider(current.id));
    // Watched (not read) so they are loaded by the time Move/Copy needs them.
    final shoppingLists =
        ref.watch(listsProvider).value ?? const <ShoppingList>[];
    final allCategories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final order = categoryOrderMap(allCategories);
    final categories = orderedCategoryNames(allCategories);
    final colors = {
      for (final c in allCategories)
        if (c.color != null) c.name: Color(c.color!),
    };

    Future<void> recolor(String name) async {
      final choice = await showCategoryColorDialog(
        context,
        category: name,
        current: allCategories.where((c) => c.name == name).firstOrNull?.color,
      );
      if (choice != null) await db.setCategoryColor(name, choice.argb);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry'),
        actions: [
          settingsButton,
          PopupMenuButton<String>(
            tooltip: 'List options',
            icon: const KeylineIcon(KeylineIcons.moreVertical),
            onSelected: (v) async {
              if (v == 'new') {
                await onNewList();
              } else if (v == 'moveCopy') {
                final outcome = await showPantryMoveCopy(
                  context,
                  db: db,
                  list: current,
                  items: items.value ?? const [],
                  shoppingLists: shoppingLists,
                  pantryLists: lists,
                );
                if (outcome != null && context.mounted) {
                  showUndoSnackBar(
                    context,
                    message: outcome.message,
                    onUndo: outcome.undo,
                  );
                }
              } else if (v == 'export') {
                final rows = items.value ?? const <PantryItem>[];
                final saved = await ref
                    .read(fileServiceProvider)
                    .saveText(
                      fileName: '${safeFileName(current.name)}.csv',
                      text: pantryItemsToCsv(rows),
                    );
                if (saved && context.mounted) {
                  showInfoSnackBar(
                    context,
                    'Exported ${rows.length} '
                    '${rows.length == 1 ? 'item' : 'items'} from '
                    '"${current.name}"',
                  );
                }
              } else if (v == 'import') {
                final picked = await ref.read(fileServiceProvider).pickText();
                if (picked == null || !context.mounted) return;
                final rows = parsePantryCsv(picked.text);
                if (rows.isEmpty) {
                  showInfoSnackBar(
                    context,
                    'No items were found in "${picked.name}"',
                  );
                  return;
                }
                final name = await askNameDialog(
                  context,
                  title: 'Import as a new pantry list',
                  initial: picked.name,
                  confirmLabel: 'Import',
                  confirmTip: 'Create a pantry list from this file',
                );
                if (name == null || !context.mounted) return;
                final id = await db.addList(name, kind: 'pantry');
                await db.importPantryItems(id, rows);
                onSelect(id);
                if (context.mounted) {
                  showInfoSnackBar(
                    context,
                    'Imported ${rows.length} '
                    '${rows.length == 1 ? 'item' : 'items'} into "$name"',
                  );
                }
              } else if (v == 'itemsSetting') {
                await showDialog<void>(
                  context: context,
                  builder: (_) => PantryItemsSettingDialog(list: current),
                );
              } else if (v == 'categories') {
                await showDialog<void>(
                  context: context,
                  builder: (_) => ManageCategoriesDialog(
                    listId: current.id,
                    listName: current.name,
                  ),
                );
              } else if (v == 'manageLists') {
                await showDialog<void>(
                  context: context,
                  builder: (_) => const ManageListsDialog(pantry: true),
                );
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete "${current.name}"?',
                  message: 'The list and all its items will be removed.',
                  confirmTip: 'Delete this pantry list and its items',
                );
                if (ok) {
                  await db.deleteList(current.id);
                  onListGone();
                }
              }
            },
            itemBuilder: (_) => [
              tipMenuItem(
                value: 'new',
                tip: 'Start another pantry list',
                label: 'Create new list',
              ),
              tipMenuItem(
                value: 'moveCopy',
                tip: 'Move or copy items to another list or a shopping list',
                label: 'Move/Copy items',
              ),
              tipMenuItem(
                value: 'itemsSetting',
                tip: 'Show amounts as Low/Full or as numbers',
                label: 'Items setting',
              ),
              tipMenuItem(
                value: 'categories',
                tip: 'Add, recolor or delete categories',
                label: 'Manage categories',
              ),
              tipMenuItem(
                value: 'manageLists',
                tip: 'Rename, reorder or delete your pantry lists',
                label: 'Manage lists',
              ),
              tipMenuItem(
                value: 'export',
                tip: 'Save this list as a CSV file',
                label: 'Export list',
              ),
              tipMenuItem(
                value: 'import',
                tip: 'Make a new pantry list from a CSV file',
                label: 'Import list',
              ),
              tipMenuItem(
                value: 'delete',
                tip: 'Delete this pantry list and its items',
                label: 'Delete this list',
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            // A pull-down only when there is more than one list to pick from.
            child: lists.length > 1
                ? Tip(
                    'Choose a pantry list',
                    child: ChoiceField<String>(
                      value: current.id,
                      choices: [for (final l in lists) Choice(l.id, l.name)],
                      textStyle: Theme.of(context).textTheme.titleMedium,
                      onChanged: onSelect,
                    ),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        current.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('Pantry is empty'));
                }
                final byCategory = <String, List<PantryItem>>{};
                for (final i in rows) {
                  byCategory
                      .putIfAbsent(
                        i.category.isEmpty ? 'Other' : i.category,
                        () => [],
                      )
                      .add(i);
                }
                final names = byCategory.keys.toList()
                  ..sort(
                    (a, b) =>
                        (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20),
                  );
                final today = DateTime.now();
                final start = DateTime(today.year, today.month, today.day);
                final useSoon = [
                  for (final item in rows)
                    if (_dueWithinWeek(item.expiryDate, start)) item,
                ]..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
                return ListView(
                  children: [
                    if (useSoon.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'USE SOON',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        letterSpacing: 0.6,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    for (final item in useSoon)
                                      '${item.name} (${_soonWhen(item.expiryDate!, start)})',
                                  ].join(', '),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    for (final n in names) ...[
                      CategoryHeader(
                        n,
                        color: colors[n],
                        onTap: () => recolor(n),
                      ),
                      for (final i in byCategory[n]!)
                        _PantryTile(item: i, db: db, categories: categories),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add pantry item',
        onPressed: () => _showAddDialog(context, db, categories, current.id),
        child: const KeylineIcon(KeylineIcons.plus),
      ),
    );
  }
}

bool _dueWithinWeek(DateTime? expiry, DateTime startOfToday) {
  if (expiry == null) return false;
  final day = DateTime(expiry.year, expiry.month, expiry.day);
  return !day.isAfter(startOfToday.add(const Duration(days: 7)));
}

String _soonWhen(DateTime expiry, DateTime startOfToday) {
  final day = DateTime(expiry.year, expiry.month, expiry.day);
  final days = day.difference(startOfToday).inDays;
  if (days < 0) return 'expired';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

String _fmt(double q) => q == q.roundToDouble() ? q.toInt().toString() : '$q';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _PantryTile extends StatelessWidget {
  const _PantryTile({
    required this.item,
    required this.db,
    required this.categories,
  });

  /// The user's categories to choose from when editing.
  final List<String> categories;
  final PantryItem item;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final expiry = item.expiryDate;
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final expired = expiry != null && expiry.isBefore(startOfToday);
    final soon =
        expiry != null &&
        !expired &&
        expiry.difference(startOfToday).inDays <= 3;
    final color = expired
        ? Colors.red
        : soon
        ? Colors.orange
        : null;
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(color: Colors.red.shade300),
      onDismissed: (_) => db.deletePantryItem(item.id),
      child: LayoutBuilder(
        builder: (context, box) {
          final theme = Theme.of(context);
          final details = [
            if (item.location.isNotEmpty) item.location,
            if (expiry != null) 'Expires ${_date(expiry)}',
          ].join(' · ');
          final text = Tip(
            'Edit item',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.bodyLarge?.copyWith(color: color),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                if (item.note.isNotEmpty)
                  Text(
                    item.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          );
          final amount = item.quantityMode == 'level'
              ? SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'low',
                      label: Text('Low'),
                      tooltip: 'Running low: time to restock',
                    ),
                    ButtonSegment(
                      value: 'full',
                      label: Text('Full'),
                      tooltip: 'Plenty left',
                    ),
                  ],
                  selected: {item.level == 'low' ? 'low' : 'full'},
                  onSelectionChanged: (s) =>
                      db.setPantryLevel(item.id, s.first),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Decrease',
                      visualDensity: VisualDensity.compact,
                      icon: const KeylineIcon(KeylineIcons.circleMinus),
                      onPressed: item.quantity <= 0
                          ? null
                          : () => db.updatePantryQuantity(
                              item.id,
                              item.quantity - 1,
                            ),
                    ),
                    Flexible(
                      child: Text(
                        '${_fmt(item.quantity)} ${item.unit}'.trim(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Increase',
                      visualDensity: VisualDensity.compact,
                      icon: const KeylineIcon(KeylineIcons.circlePlus),
                      onPressed: () =>
                          db.updatePantryQuantity(item.id, item.quantity + 1),
                    ),
                  ],
                );
          // Narrow windows: put the amount under the text instead of beside it.
          return InkWell(
            onTap: () => _edit(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: box.maxWidth < 380
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        text,
                        const SizedBox(height: 4),
                        Align(alignment: Alignment.centerLeft, child: amount),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: text),
                        amount,
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showItemEditor(
      context,
      title: 'Edit pantry item',
      showPantryFields: true,
      categories: categories.isEmpty ? null : categories,
      initial: ItemEdit(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
        note: item.note,
        location: item.location,
        expiry: item.expiryDate,
        quantityMode: item.quantityMode,
        level: item.level,
      ),
    );
    switch (result) {
      case ItemSaved(:final edit):
        await db.updatePantryItem(
          item.id,
          name: edit.name,
          quantity: edit.quantity,
          unit: edit.unit,
          category: edit.category,
          location: edit.location,
          expiryDate: edit.expiry,
          note: edit.note,
          quantityMode: edit.quantityMode,
          level: edit.level,
        );
        if (edit.category != item.category) {
          await db.assignCategory(edit.name, edit.category);
        }
      case ItemDeleted():
        await db.deletePantryItem(item.id);
      case ItemMoved() || ItemCopied() || null:
        break; // move/copy have their own dialog from the list menu
    }
  }
}

Future<void> _showAddDialog(
  BuildContext context,
  AppDatabase db,
  List<String> categories,
  String listId,
) {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final unit = TextEditingController();
  final location = TextEditingController();
  DateTime? expiry;
  var category = '';
  String? pickedName;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add pantry item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Search or add an item',
                  prefixIcon: KeylineIcon(KeylineIcons.search),
                ),
              ),
              CatalogSuggestions(
                query: pickedName == name.text ? '' : name.text,
                onPick: (i) => setState(() {
                  name.text = i.name;
                  pickedName = i.name;
                  category = i.category;
                  if (unit.text.isEmpty) unit.text = i.defaultUnit;
                }),
              ),
              Tip(
                'Choose a category',
                child: ChoiceField<String>(
                  value: category.isEmpty ? null : category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  choices: [
                    for (final c
                        in categories.isEmpty ? catalogSeed.keys : categories)
                      Choice(c, c),
                  ],
                  onChanged: (v) => setState(() => category = v),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: location,
                decoration: const InputDecoration(
                  labelText: 'Location (fridge, shelf, ...)',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expiry == null
                          ? 'No expiry date'
                          : 'Expires ${_date(expiry!)}',
                    ),
                  ),
                  Tip(
                    'Choose an expiry date',
                    child: TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: expiry ?? now,
                          firstDate: now.subtract(const Duration(days: 365)),
                          lastDate: now.add(const Duration(days: 365 * 10)),
                        );
                        if (d != null) setState(() => expiry = d);
                      },
                      child: const Text('Set date'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          Tip(
            'Close without adding',
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
          Tip(
            'Add to your pantry',
            child: FilledButton(
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) return;
                db.addPantryItem(
                  n,
                  quantity: double.tryParse(qty.text.trim()) ?? 1,
                  unit: unit.text.trim(),
                  expiryDate: expiry,
                  location: location.text.trim(),
                  category: category.isEmpty ? 'Other' : category,
                  listId: listId,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    ),
  );
}
