import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/tip.dart';

/// Matches for [query]: items already on this list, pantry hits, recent
/// history, then catalog rows. Renders nothing when there is nothing to show.
class CatalogSuggestions extends ConsumerWidget {
  const CatalogSuggestions({
    super.key,
    required this.query,
    required this.onPick,
    this.showRecent = false,
    this.onList = const [],
    this.inPantry = const [],
    this.history = const [],
    this.onOpenList,
    this.onPantry,
    this.onHistory,
  });

  final String query;
  final bool showRecent;
  final List<ShoppingItem> onList;
  final List<PantryItem> inPantry;
  final List<HistoryEntry> history;
  final ValueChanged<CatalogItem> onPick;
  final ValueChanged<ShoppingItem>? onOpenList;
  final ValueChanged<PantryItem>? onPantry;
  final ValueChanged<HistoryEntry>? onHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty && !showRecent) return const SizedBox.shrink();

    final listHits = q.isEmpty
        ? const <ShoppingItem>[]
        : [
            for (final item in onList)
              if (item.name.toLowerCase().contains(q)) item,
          ];
    final listNames = {for (final item in listHits) item.name.toLowerCase()};
    final pantryHits = q.isEmpty
        ? const <PantryItem>[]
        : [
            for (final item in inPantry)
              if (item.name.toLowerCase().contains(q) &&
                  !listNames.contains(item.name.toLowerCase()))
                item,
          ];
    final taken = {
      ...listNames,
      for (final item in pantryHits) item.name.toLowerCase(),
    };
    final historyHits = <HistoryEntry>[];
    final seenHistory = <String>{};
    for (final entry in history) {
      final name = entry.name.toLowerCase();
      if (taken.contains(name) || !seenHistory.add(name)) continue;
      if (q.isEmpty || name.contains(q)) historyHits.add(entry);
      if (historyHits.length == 6) break;
    }

    final results = q.isEmpty
        ? const AsyncData<List<CatalogItem>>([])
        : ref.watch(catalogSearchProvider(query.trim()));
    final catalog = [
      for (final item in results.value ?? const <CatalogItem>[])
        if (!taken.contains(item.name.toLowerCase()) &&
            !historyHits.any(
              (h) => h.name.toLowerCase() == item.name.toLowerCase(),
            ))
          item,
    ];

    if (listHits.isEmpty &&
        pantryHits.isEmpty &&
        historyHits.isEmpty &&
        catalog.isEmpty) {
      return const SizedBox.shrink();
    }

    final small = Theme.of(context).textTheme.bodySmall;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: (MediaQuery.sizeOf(context).height * 0.3).clamp(
          120.0,
          320.0,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final item in listHits)
              _row(
                title: item.name,
                tip: 'Already on this list',
                trailing: 'On this list',
                trailingStyle: small,
                onTap: onOpenList == null ? null : () => onOpenList!(item),
              ),
            for (final item in pantryHits)
              _row(
                title: item.name,
                tip: 'You already have this in the pantry',
                trailing: 'In pantry',
                trailingStyle: small,
                onTap: onPantry == null ? null : () => onPantry!(item),
              ),
            for (final entry in historyHits)
              _row(
                title: entry.name,
                tip: 'Add "${entry.name}" again',
                trailing: 'Recent',
                trailingStyle: small,
                onTap: onHistory == null ? null : () => onHistory!(entry),
              ),
            for (final item in catalog)
              _row(
                title: item.name,
                tip: 'Use "${item.name}"',
                trailing: item.parentName.isEmpty
                    ? item.category
                    : item.parentName,
                trailingStyle: small,
                indent: item.parentName.isNotEmpty,
                strong: item.parentName.isEmpty,
                onTap: () => onPick(item),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required String tip,
    required String trailing,
    required TextStyle? trailingStyle,
    required VoidCallback? onTap,
    bool indent = false,
    bool strong = true,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.only(left: indent ? 36 : 16, right: 16),
      title: Tip(
        tip,
        child: Text(
          title,
          style: strong ? const TextStyle(fontWeight: FontWeight.w600) : null,
        ),
      ),
      trailing: Text(trailing, style: trailingStyle),
      onTap: onTap,
    );
  }
}
