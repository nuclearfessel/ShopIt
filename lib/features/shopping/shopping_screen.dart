import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../catalog/catalog_suggestions.dart';
import '../../data/tax_rules.dart';
import '../../data/totals.dart';
import '../catalog/item_editor.dart';
import '../../data/category_order.dart';
import '../../data/list_csv.dart';
import '../../services/file_service.dart';
import '../categories/category_color_dialog.dart';
import '../categories/manage_categories_dialog.dart';
import '../history/history_dialog.dart';
import '../lists/list_settings_dialog.dart';
import '../lists/move_copy_dialog.dart';
import '../lists/manage_lists_dialog.dart';
import '../settings/settings_dialog.dart';
import 'tax_rates_dialog.dart';
import '../../ui/keyline/keyline_icon.dart';
import '../../ui/category_header.dart';
import '../../ui/dialogs.dart';
import '../../ui/choice_field.dart';
import '../../ui/tip.dart';
import '../../ui/undo_snack_bar.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  String? _listId;
  final _controller = TextEditingController();
  final _searchFocus = FocusNode();
  final _itemKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _revealItem(String id) {
    final target = _itemKeys[id]?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 200),
      alignment: 0.2,
    );
  }

  Future<void> _newList() async {
    final name = await _askName(context, 'New list');
    if (name == null) return;
    await ref.read(databaseProvider).addList(name);
  }

  /// Adds an item. With "Auto-categorize items" off the item goes in without a
  /// category.
  void _add(ShoppingList list, String name, String category) {
    ref
        .read(databaseProvider)
        .addShoppingItem(
          list.id,
          name,
          category: list.autoCategorize ? category : '',
        );
    _dismissSearch();
  }

  /// Deletes the checked items right away, with an Undo in a snack bar.
  Future<void> _deleteChecked(String listId) async {
    final db = ref.read(databaseProvider);
    final ids = await db.clearChecked(listId);
    if (!mounted || ids.isEmpty) return;
    showUndoSnackBar(
      context,
      message:
          'Deleted ${ids.length} ${ids.length == 1 ? 'item' : 'items'} '
          'from your cart',
      onUndo: () => db.restoreItems(ids),
    );
  }

  /// The pencil in the add bar: fill in quantity, price, category and notes
  /// before the item goes on the list.
  Future<void> _addWithDetails(
    ShoppingList list,
    TaxContext? tax,
    List<String> categories,
  ) async {
    final db = ref.read(databaseProvider);
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Start from the category remembered for this name, if there is one.
    final match = (await db.searchCatalog(text))
        .where((i) => i.name.toLowerCase() == text.toLowerCase())
        .toList();
    if (!mounted) return;
    final category = list.autoCategorize
        ? (match.isEmpty ? 'Other' : match.first.category)
        : '';
    final taxed = tax == null
        ? true
        : tax.rateForClass(classifyItem(text, category)) > 0;
    final result = await showItemEditor(
      context,
      title: 'New item',
      isNew: true,
      showPrice: true,
      categories: categories.isEmpty ? null : categories,
      initial: ItemEdit(
        name: text,
        category: category,
        unit: match.isEmpty ? '' : match.first.defaultUnit,
        taxable: taxed,
      ),
      taxHint: tax == null
          ? 'No sales tax rate is set for this list.'
          : describeTax(text, category, tax, manual: false),
    );
    if (result is! ItemSaved || !mounted) return;
    final e = result.edit;
    final id = await db.addShoppingItem(
      list.id,
      e.name,
      quantity: e.quantity,
      unit: e.unit,
      category: e.category,
    );
    await db.updateShoppingItem(
      id,
      name: e.name,
      quantity: e.quantity,
      unit: e.unit,
      category: e.category,
      price: e.price,
      note: e.note,
      taxable: e.taxable,
      hasCoupon: e.hasCoupon,
      taxManual:
          tax != null &&
          e.taxable != (tax.rateForClass(classifyItem(e.name, e.category)) > 0),
    );
    // A category chosen by hand is what this item gets from now on.
    if (e.category.isNotEmpty && e.category != category) {
      await db.assignCategory(e.name, e.category);
    }
    if (mounted) _dismissSearch();
  }

  /// Clears the query and closes the suggestion menu.
  void _dismissSearch() {
    _controller.clear();
    _searchFocus.unfocus();
    setState(() {});
  }

  /// Enter key: jump to an item already on this list or in the pantry, otherwise
  /// use the catalog entry with exactly this name, or add the text under "Other".
  Future<void> _submit(ShoppingList list) async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final rows =
        ref.read(shoppingItemsProvider(list.id)).value ??
        const <ShoppingItem>[];
    final onList = rows.where(
      (i) => i.name.toLowerCase() == name.toLowerCase(),
    );
    if (onList.isNotEmpty) {
      _revealItem(onList.first.id);
      if (mounted) {
        showInfoSnackBar(
          context,
          '${onList.first.name} is already on this list.',
        );
        _dismissSearch();
      }
      return;
    }
    final held = _pantryNow().where(
      (i) => i.name.toLowerCase() == name.toLowerCase(),
    );
    if (held.isNotEmpty) {
      if (mounted) {
        showInfoSnackBar(
          context,
          'You already have ${held.first.name} in the pantry.',
        );
        _dismissSearch();
      }
      return;
    }
    final match = (await ref.read(databaseProvider).searchCatalog(name))
        .where((i) => i.name.toLowerCase() == name.toLowerCase());
    if (!mounted) return;
    _add(
      list,
      match.isEmpty ? name : match.first.name,
      match.isEmpty ? 'Other' : match.first.category,
    );
  }

  List<PantryItem> _pantryNow() {
    final lists = ref.read(pantryListsProvider).value ?? const <ShoppingList>[];
    return [
      for (final list in lists)
        ...ref.read(pantryProvider(list.id)).value ?? const <PantryItem>[],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider);
    return lists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (all.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Shopping'),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  icon: const KeylineIcon(KeylineIcons.settings),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  ),
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No lists yet'),
                  const SizedBox(height: 12),
                  Tip(
                    'Create your first list',
                    child: FilledButton.icon(
                      onPressed: _newList,
                      icon: const KeylineIcon(KeylineIcons.listPlus),
                      label: const Text('Create a list'),
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
        final db = ref.read(databaseProvider);
        final items = ref.watch(shoppingItemsProvider(current.id));
        // Watched (not read) so they are loaded by the time Move/Copy needs them.
        final pantryLists =
            ref.watch(pantryListsProvider).value ?? const <ShoppingList>[];
        final pantryItems = [
          for (final list in pantryLists)
            ...ref.watch(pantryProvider(list.id)).value ?? const <PantryItem>[],
        ];
        final history =
            ref.watch(historyProvider).value ?? const <HistoryEntry>[];
        final rate = ref
            .watch(taxRatesProvider)
            .value
            ?.where((r) => r.id == current.taxRateId)
            .firstOrNull;
        final taxCtx = rate == null ? null : TaxContext.fromRate(rate);
        final allCategories =
            ref.watch(categoriesProvider).value ?? const <Category>[];
        final categoryOrder = categoryOrderMap(allCategories);
        final categoryNames = orderedCategoryNames(allCategories);
        final categoryColors = {
          for (final c in allCategories)
            if (c.color != null) c.name: Color(c.color!),
        };
        Future<void> recolor(String name) async {
          final choice = await showCategoryColorDialog(
            context,
            category: name,
            current: allCategories
                .where((c) => c.name == name)
                .firstOrNull
                ?.color,
          );
          if (choice != null) await db.setCategoryColor(name, choice.argb);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Shopping'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const KeylineIcon(KeylineIcons.settings),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => SettingsDialog(
                    listId: current.id,
                    listName: current.name,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'List options',
                icon: const KeylineIcon(KeylineIcons.moreVertical),
                onSelected: (v) async {
                  if (v == 'new') {
                    await _newList();
                  } else if (v == 'rename') {
                    final name = await askNameDialog(
                      context,
                      title: 'Rename list',
                      initial: current.name,
                      confirmLabel: 'Rename',
                      confirmTip: 'Save the new name',
                    );
                    if (name != null && name != current.name) {
                      await db.renameList(current.id, name);
                    }
                  } else if (v == 'delete') {
                    if (await _confirm(
                      context,
                      'Delete "${current.name}"?',
                      'The list and all its items will be removed.',
                    )) {
                      await db.deleteList(current.id);
                      setState(() => _listId = null);
                    }
                  } else if (v == 'moveCopy') {
                    final outcome = await showShoppingMoveCopy(
                      context,
                      db: db,
                      list: current,
                      items: items.value ?? const [],
                      shoppingLists: all,
                      pantryLists: pantryLists,
                    );
                    if (outcome != null && context.mounted) {
                      showUndoSnackBar(
                        context,
                        message: outcome.message,
                        onUndo: outcome.undo,
                      );
                    }
                  } else if (v == 'export') {
                    final rows = items.value ?? const <ShoppingItem>[];
                    final saved = await ref
                        .read(fileServiceProvider)
                        .saveText(
                          fileName: '${safeFileName(current.name)}.csv',
                          text: shoppingItemsToCsv(rows),
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
                    final picked = await ref
                        .read(fileServiceProvider)
                        .pickText();
                    if (picked == null || !context.mounted) return;
                    final rows = parseShoppingCsv(picked.text);
                    if (rows.isEmpty) {
                      showInfoSnackBar(
                        context,
                        'No items were found in "${picked.name}"',
                      );
                      return;
                    }
                    final name = await askNameDialog(
                      context,
                      title: 'Import as a new list',
                      initial: picked.name,
                      confirmLabel: 'Import',
                      confirmTip: 'Create a list from this file',
                    );
                    if (name == null || !context.mounted) return;
                    final id = await db.addList(name);
                    await db.importShoppingItems(id, rows);
                    setState(() => _listId = id);
                    if (context.mounted) {
                      showInfoSnackBar(
                        context,
                        'Imported ${rows.length} '
                        '${rows.length == 1 ? 'item' : 'items'} into "$name"',
                      );
                    }
                  } else if (v == 'checkAll') {
                    await db.checkAll(current.id);
                  } else if (v == 'uncheckAll') {
                    await db.uncheckAll(current.id);
                  } else if (v == 'categories') {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => ManageCategoriesDialog(
                        listId: current.id,
                        listName: current.name,
                      ),
                    );
                  } else if (v == 'listSettings') {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => ListSettingsDialog(listId: current.id),
                    );
                  } else if (v == 'manageLists') {
                    await showDialog<void>(
                      context: context,
                      builder: (_) => const ManageListsDialog(),
                    );
                  } else if (v == 'deleteAll') {
                    if (await _confirm(
                      context,
                      'Delete all lists?',
                      'Every shopping list and all their items will be '
                          'removed so you can start from scratch. Your '
                          'pantry is not affected.',
                    )) {
                      await db.deleteAllLists();
                      setState(() => _listId = null);
                    }
                  }
                },
                itemBuilder: (_) => [
                  tipMenuItem(
                    value: 'new',
                    tip: 'Start another shopping list',
                    label: 'New list',
                  ),
                  tipMenuItem(
                    value: 'moveCopy',
                    tip: 'Move or copy items to another list or the pantry',
                    label: 'Move/Copy items',
                  ),
                  tipMenuItem(
                    value: 'checkAll',
                    tip: 'Put every item on this list in your cart',
                    label: 'Check all',
                  ),
                  tipMenuItem(
                    value: 'uncheckAll',
                    tip: 'Put everything in your cart back on the list',
                    label: 'Uncheck all',
                  ),
                  tipMenuItem(
                    value: 'categories',
                    tip: 'Add, recolor or delete categories',
                    label: 'Manage categories',
                  ),
                  tipMenuItem(
                    value: 'listSettings',
                    tip: 'Categories and sorting for this list',
                    label: 'List settings',
                  ),
                  tipMenuItem(
                    value: 'manageLists',
                    tip: 'Rename, reorder or delete your lists',
                    label: 'Manage lists',
                  ),
                  tipMenuItem(
                    value: 'export',
                    tip: 'Save this list as a CSV file',
                    label: 'Export list',
                  ),
                  tipMenuItem(
                    value: 'import',
                    tip: 'Make a new list from a CSV file',
                    label: 'Import list',
                  ),
                  tipMenuItem(
                    value: 'rename',
                    tip: 'Rename the list you have open',
                    label: 'Rename this list',
                  ),
                  tipMenuItem(
                    value: 'delete',
                    tip: 'Delete this list and its items',
                    label: 'Delete this list',
                  ),
                  tipMenuItem(
                    value: 'deleteAll',
                    tip: 'Delete every list and start from scratch',
                    label: 'Delete all lists',
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                // A pull-down only makes sense with more than one list to pick
                // from; with a single list just show its name.
                child: all.length > 1
                    ? Tip(
                        'Choose a list',
                        child: ChoiceField<String>(
                          inset: 20,
                          value: current.id,
                          choices: [for (final l in all) Choice(l.id, l.name)],
                          textStyle: Theme.of(context).textTheme.titleMedium,
                          onChanged: (v) => setState(() => _listId = v),
                        ),
                      )
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
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
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  focusNode: _searchFocus,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search or add an item',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: KeylineIcon(KeylineIcons.search),
                    ),
                    border: const OutlineInputBorder(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_controller.text.trim().isNotEmpty)
                            IconButton(
                              tooltip: 'Edit details before adding',
                              icon: const KeylineIcon(KeylineIcons.pen),
                              onPressed: () => _addWithDetails(
                                current,
                                taxCtx,
                                categoryNames,
                              ),
                            ),
                          IconButton(
                            tooltip: 'History',
                            icon: const KeylineIcon(KeylineIcons.history),
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => HistoryDialog(list: current),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Add item',
                            icon: const KeylineIcon(KeylineIcons.plus),
                            onPressed: () => _submit(current),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submit(current),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: items.when(
                        loading: () => const SizedBox.shrink(),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (rows) =>
                            rows.isEmpty && !current.showEmptyCategories
                            ? const Center(child: Text('Nothing to buy'))
                            : ListView(
                                children: [
                                  ..._grouped(
                                    rows,
                                    categoryOrder,
                                    db,
                                    all,
                                    current.id,
                                    taxCtx,
                                    itemKeys: _itemKeys,
                                    onUncheckAll: () =>
                                        db.uncheckAll(current.id),
                                    onDeleteAll: () =>
                                        _deleteChecked(current.id),
                                    useCategories: current.useCategories,
                                    showEmpty: current.showEmptyCategories,
                                    categoryNames: categoryNames,
                                    colors: categoryColors,
                                    onHeaderTap: recolor,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CatalogSuggestions(
                        query: _controller.text,
                        showRecent: _searchFocus.hasFocus,
                        onList: items.value ?? const [],
                        inPantry: pantryItems,
                        history: history,
                        onPick: (i) => _add(current, i.name, i.category),
                        onOpenList: (item) {
                          _revealItem(item.id);
                          showInfoSnackBar(
                            context,
                            '${item.name} is already on this list.',
                          );
                          _dismissSearch();
                        },
                        onPantry: (item) {
                          showInfoSnackBar(
                            context,
                            'You already have ${item.name} in the pantry.',
                          );
                          _dismissSearch();
                        },
                        onHistory: (entry) =>
                            _add(current, entry.name, entry.category),
                      ),
                    ),
                  ],
                ),
              ),
              _TotalBar(rows: items.value ?? const [], tax: taxCtx),
            ],
          ),
        );
      },
    );
  }
}

/// Unchecked items under colour-barred category headers in the list's category
/// order (or as one plain list when categories are off), followed by an
/// "In your cart" section for checked items.
List<Widget> _grouped(
  List<ShoppingItem> rows,
  Map<String, int> order,
  AppDatabase db,
  List<ShoppingList> lists,
  String listId,
  TaxContext? tax, {
  required Map<String, GlobalKey> itemKeys,
  required VoidCallback onUncheckAll,
  required VoidCallback onDeleteAll,
  bool useCategories = true,
  bool showEmpty = false,
  List<String> categoryNames = const [],
  Map<String, Color> colors = const {},
  void Function(String category)? onHeaderTap,
}) {
  final open = rows.where((i) => !i.checked).toList();
  final done = rows.where((i) => i.checked).toList();
  Widget tile(ShoppingItem i) => _ItemTile(
    key: itemKeys.putIfAbsent(i.id, GlobalKey.new),
    item: i,
    db: db,
    lists: lists,
    listId: listId,
    tax: tax,
    categories: categoryNames.isEmpty ? null : categoryNames,
  );
  final cart = done.isEmpty
      ? null
      : _CartSection(
          count: done.length,
          onUncheckAll: onUncheckAll,
          onDeleteAll: onDeleteAll,
          children: [for (final i in done) tile(i)],
        );

  if (!useCategories) {
    open.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [for (final i in open) tile(i), ?cart];
  }

  final byCategory = <String, List<ShoppingItem>>{};
  for (final i in open) {
    byCategory
        .putIfAbsent(i.category.isEmpty ? 'Other' : i.category, () => [])
        .add(i);
  }
  final names = {...byCategory.keys, if (showEmpty) ...categoryNames}.toList()
    ..sort((a, b) => (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20));
  return [
    for (final n in names) ...[
      CategoryHeader(
        n,
        color: colors[n],
        onTap: onHeaderTap == null ? null : () => onHeaderTap(n),
      ),
      for (final i in byCategory[n] ?? const <ShoppingItem>[]) tile(i),
    ],
    ?cart,
  ];
}

/// Checked items in their own, slightly tinted panel. The "Uncheck all" and
/// "Delete all" controls sit compactly in its header: small text buttons when
/// there is room, small icon buttons when the window is narrow.
class _CartSection extends StatelessWidget {
  const _CartSection({
    required this.count,
    required this.onUncheckAll,
    required this.onDeleteAll,
    required this.children,
  });

  final int count;
  final VoidCallback onUncheckAll;
  final VoidCallback onDeleteAll;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const compact = VisualDensity(horizontal: -3, vertical: -3);
    final small = TextButton.styleFrom(
      visualDensity: compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: theme.textTheme.labelMedium,
    );
    // A Material (not a coloured Container) so the items' tap ripples show.
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: scheme.surfaceContainerHigh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
              child: LayoutBuilder(
                builder: (context, box) {
                  final narrow = box.maxWidth < 360;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          'IN YOUR CART ($count)',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            letterSpacing: 0.6,
                            color: scheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      if (narrow) ...[
                        IconButton(
                          tooltip: 'Uncheck all',
                          visualDensity: compact,
                          iconSize: 20,
                          icon: const KeylineIcon(KeylineIcons.listX),
                          onPressed: onUncheckAll,
                        ),
                        IconButton(
                          tooltip: 'Delete all',
                          visualDensity: compact,
                          iconSize: 20,
                          icon: const KeylineIcon(KeylineIcons.bin2),
                          onPressed: onDeleteAll,
                        ),
                      ] else ...[
                        Tip(
                          'Put everything in your cart back on the list',
                          child: TextButton.icon(
                            style: small,
                            onPressed: onUncheckAll,
                            icon: const KeylineIcon(
                              KeylineIcons.listX,
                              size: 16,
                            ),
                            label: const Text('Uncheck all'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tip(
                          'Delete everything in your cart',
                          child: TextButton.icon(
                            style: small,
                            onPressed: onDeleteAll,
                            icon: const KeylineIcon(
                              KeylineIcons.bin2,
                              size: 16,
                            ),
                            label: const Text('Delete all'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.db,
    required this.lists,
    required this.listId,
    required this.tax,
    this.categories,
  });

  /// The categories to offer when editing (null = the built-in ones).
  final List<String>? categories;
  final ShoppingItem item;
  final AppDatabase db;
  final List<ShoppingList> lists;
  final String listId;

  /// The list's tax rate and rules, or null when the list has no tax rate.
  final TaxContext? tax;

  /// The checkbox only becomes a manual override when it differs from what the
  /// tax rules would say, so items keep following the rules otherwise.
  bool _manual(ItemEdit edit) {
    final t = tax;
    if (t == null) return item.taxManual || edit.taxable != item.taxable;
    final c = classifyItem(edit.name, edit.category);
    return edit.taxable != (t.rateForClass(c) > 0);
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showItemEditor(
      context,
      title: 'Edit item',
      showPrice: true,
      initial: ItemEdit(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        category: item.category,
        price: item.price,
        note: item.note,
        taxable: tax?.isTaxed(item) ?? item.taxable,
        hasCoupon: item.hasCoupon,
      ),
      taxHint: tax == null
          ? 'No sales tax rate is set for this list.'
          : describeTax(item.name, item.category, tax!, manual: item.taxManual),
      lists: [for (final l in lists) (id: l.id, name: l.name)],
      currentListId: listId,
      categories: categories,
    );
    Future<void> save(ItemEdit edit) async {
      await db.updateShoppingItem(
        item.id,
        name: edit.name,
        quantity: edit.quantity,
        unit: edit.unit,
        category: edit.category,
        price: edit.price,
        note: edit.note,
        taxable: edit.taxable,
        hasCoupon: edit.hasCoupon,
        taxManual: _manual(edit),
      );
      // Changing the category is permanent: adding the item again (typing it or
      // from history) files it there.
      if (edit.category != item.category) {
        await db.assignCategory(edit.name, edit.category);
      }
    }

    switch (result) {
      case ItemSaved(:final edit):
        await save(edit);
      case ItemDeleted():
        await db.deleteShoppingItem(item.id);
      case ItemMoved(:final edit, :final listId):
        await save(edit);
        await db.moveShoppingItem(item.id, listId);
      case ItemCopied(:final edit, :final listId):
        await save(edit);
        await db.copyShoppingItem(
          item.copyWith(
            name: edit.name,
            quantity: edit.quantity,
            unit: edit.unit,
            category: edit.category,
            price: Value(edit.price),
            note: edit.note,
            taxable: edit.taxable,
            hasCoupon: edit.hasCoupon,
            taxManual: _manual(edit),
          ),
          listId,
        );
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = (item.quantity != 1 || item.unit.isNotEmpty)
        ? '${formatQuantity(item.quantity)} ${item.unit}'.trim()
        : null;
    final details = [
      if (qty != null)
        item.price != null && item.quantity != 1
            ? '$qty x ${formatMoney(item.price!)}'
            : qty,
      if (item.hasCoupon) 'coupon',
      if (tax?.isTaxed(item) ?? false) 'tax',
    ].join(' · ');
    return Dismissible(
      key: ValueKey(item.id),
      background: Container(color: Colors.red.shade300),
      onDismissed: (_) => db.deleteShoppingItem(item.id),
      child: ListTile(
        onTap: () => _edit(context),
        leading: Tip(
          item.checked ? 'Move back to the list' : 'Put in your cart',
          child: Checkbox(
            value: item.checked,
            onChanged: (v) => db.setChecked(item.id, v ?? false),
          ),
        ),
        title: Tip(
          'Edit item',
          child: Text(
            item.name,
            style: item.checked
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
        ),
        subtitle: (details.isEmpty && item.note.isEmpty)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.isNotEmpty) Text(details),
                  if (item.note.isNotEmpty)
                    Text(
                      item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
        trailing: item.price == null
            ? null
            : Text(
                formatMoney(item.price! * item.quantity),
                style: Theme.of(context).textTheme.titleSmall,
              ),
      ),
    );
  }
}

/// Out-of-Milk-style bottom bar: cart and list totals (with tax at the list's
/// rate and rules) on the left, item counts on the right.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.rows, required this.tax});
  final List<ShoppingItem> rows;
  final TaxContext? tax;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final t = computeTotals(rows, tax);
    final theme = Theme.of(context);
    final ctx = tax;
    final inCart = rows.where((i) => i.checked).length;
    // A rate is chosen but nothing priced is taxed: say why tax is 0.
    final noneTaxed = ctx != null && t.hasPrices && !t.anyTaxed;
    final rulesName = ctx == null || ctx.rules.id == 'everything'
        ? 'this rate'
        : '${ctx.rules.title} rules';
    final bold = theme.textTheme.titleSmall;
    return Material(
      // The palette's deepest tone: distinct from the navigation
      // (surfaceContainer) and the cart panel (surfaceContainerHigh).
      color: theme.colorScheme.surfaceContainerHighest,
      shape: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          // Never take more than a fifth of the window; scroll if it must.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * 0.2).clamp(
                72.0,
                160.0,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cart total: ${formatMoney(t.cartTotal)}',
                                style: bold,
                              ),
                              Text(
                                'List total: ${formatMoney(t.total)}',
                                style: bold,
                              ),
                              if (ctx != null && t.hasPrices)
                                Text(
                                  'Tax ${formatPercent(ctx.percent)}%: '
                                  '${formatMoney(t.tax)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Items in cart: $inCart', style: bold),
                              Text(
                                'Items in list: ${rows.length}',
                                style: bold,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (noneTaxed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'None of the priced items are taxed under $rulesName, '
                        'so no tax is added. Tap an item to see why or change '
                        'it.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) =>
    confirmDialog(context, title: title, message: message);

Future<String?> _askName(BuildContext context, String title) =>
    askNameDialog(context, title: title);
