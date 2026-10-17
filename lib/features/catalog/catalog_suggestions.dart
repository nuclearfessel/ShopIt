import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/tip.dart';

/// Moves the highlighted search result by [delta] rows, wrapping at the ends.
class CycleSuggestionsIntent extends Intent {
  const CycleSuggestionsIntent(this.delta);

  final int delta;
}

/// Handles [CycleSuggestionsIntent] for the suggestion list identified by [key].
class CycleSuggestionsAction extends Action<CycleSuggestionsIntent> {
  CycleSuggestionsAction(this.key);

  final GlobalKey<CatalogSuggestionsState> key;

  CatalogSuggestionsState? get _state => key.currentState;

  @override
  bool isEnabled(CycleSuggestionsIntent intent) => _state?.canCycle ?? false;

  @override
  bool consumesKey(CycleSuggestionsIntent intent) => isEnabled(intent);

  @override
  void invoke(CycleSuggestionsIntent intent) => _state?.cycle(intent.delta);
}

/// Matches for [query]: items already on this list, pantry hits, recent
/// history, then catalog rows. Renders nothing when there is nothing to show.
class CatalogSuggestions extends ConsumerStatefulWidget {
  const CatalogSuggestions({
    super.key,
    required this.query,
    required this.onPick,
    this.keyboardCycling = false,
    this.showRecent = false,
    this.onList = const [],
    this.inPantry = const [],
    this.history = const [],
    this.onOpenList,
    this.onPantry,
    this.onHistory,
  });

  final String query;
  final bool keyboardCycling;
  final bool showRecent;
  final List<ShoppingItem> onList;
  final List<PantryItem> inPantry;
  final List<HistoryEntry> history;
  final ValueChanged<CatalogItem> onPick;
  final ValueChanged<ShoppingItem>? onOpenList;
  final ValueChanged<PantryItem>? onPantry;
  final ValueChanged<HistoryEntry>? onHistory;

  @override
  ConsumerState<CatalogSuggestions> createState() => CatalogSuggestionsState();
}

class CatalogSuggestionsState extends ConsumerState<CatalogSuggestions> {
  final _highlightKey = GlobalKey();
  var _highlight = -1;
  List<_SuggestionRow> _rows = const [];

  /// True when arrow keys should move through the rows on screen.
  bool get canCycle =>
      widget.keyboardCycling &&
      widget.query.trim().isNotEmpty &&
      _rows.isNotEmpty;

  /// Moves the highlight by [delta], wrapping from the last row to the first.
  void cycle(int delta) {
    if (!canCycle || delta == 0) return;
    setState(() {
      if (_highlight < 0 || _highlight >= _rows.length) {
        _highlight = delta > 0 ? 0 : _rows.length - 1;
      } else {
        _highlight = (_highlight + delta) % _rows.length;
        if (_highlight < 0) _highlight += _rows.length;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(target, alignment: 0.5);
    });
  }

  /// Runs the highlighted row. Returns false when nothing is highlighted.
  bool activateHighlighted() {
    if (!canCycle || _highlight < 0 || _highlight >= _rows.length) {
      return false;
    }
    final tap = _rows[_highlight].onTap;
    if (tap == null) return false;
    tap();
    return true;
  }

  @override
  void didUpdateWidget(CatalogSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query.trim() != widget.query.trim()) _highlight = -1;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _matches(ref);
    _rows = rows;
    final highlight = _highlight >= 0 && _highlight < rows.length
        ? _highlight
        : -1;

    if (rows.isEmpty) return const SizedBox.shrink();

    final small = Theme.of(context).textTheme.bodySmall;
    final selectedColor = Theme.of(context).colorScheme.secondaryContainer;
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
            for (var i = 0; i < rows.length; i++)
              _tile(
                rows[i],
                trailingStyle: small,
                selected: i == highlight,
                selectedColor: selectedColor,
                rowKey: i == highlight ? _highlightKey : null,
              ),
          ],
        ),
      ),
    );
  }

  List<_SuggestionRow> _matches(WidgetRef ref) {
    final q = widget.query.trim().toLowerCase();
    if (q.isEmpty && !widget.showRecent) return const [];

    final listHits = q.isEmpty
        ? const <ShoppingItem>[]
        : [
            for (final item in widget.onList)
              if (item.name.toLowerCase().contains(q)) item,
          ];
    final listNames = {for (final item in listHits) item.name.toLowerCase()};
    final pantryHits = q.isEmpty
        ? const <PantryItem>[]
        : [
            for (final item in widget.inPantry)
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
    for (final entry in widget.history) {
      final name = entry.name.toLowerCase();
      if (taken.contains(name) || !seenHistory.add(name)) continue;
      if (q.isEmpty || name.contains(q)) historyHits.add(entry);
      if (historyHits.length == 6) break;
    }

    final results = q.isEmpty
        ? const AsyncData<List<CatalogItem>>([])
        : ref.watch(catalogSearchProvider(widget.query.trim()));
    final catalog = [
      for (final item in results.value ?? const <CatalogItem>[])
        if (!taken.contains(item.name.toLowerCase()) &&
            !historyHits.any(
              (h) => h.name.toLowerCase() == item.name.toLowerCase(),
            ))
          item,
    ];

    return [
      for (final item in listHits)
        _SuggestionRow(
          title: item.name,
          tip: 'Already on this list',
          trailing: 'On this list',
          onTap: widget.onOpenList == null
              ? null
              : () => widget.onOpenList!(item),
        ),
      for (final item in pantryHits)
        _SuggestionRow(
          title: item.name,
          tip: 'You already have this in the pantry',
          trailing: 'In pantry',
          onTap: widget.onPantry == null ? null : () => widget.onPantry!(item),
        ),
      for (final entry in historyHits)
        _SuggestionRow(
          title: entry.name,
          tip: 'Add "${entry.name}" again',
          trailing: 'Recent',
          onTap: widget.onHistory == null
              ? null
              : () => widget.onHistory!(entry),
        ),
      for (final item in catalog)
        _SuggestionRow(
          title: item.name,
          tip: 'Use "${item.name}"',
          trailing: item.parentName.isEmpty ? item.category : item.parentName,
          indent: item.parentName.isNotEmpty,
          strong: item.parentName.isEmpty,
          onTap: () => widget.onPick(item),
        ),
    ];
  }

  Widget _tile(
    _SuggestionRow row, {
    required TextStyle? trailingStyle,
    required bool selected,
    required Color selectedColor,
    required Key? rowKey,
  }) {
    return ListTile(
      key: rowKey,
      selected: selected,
      selectedTileColor: selectedColor,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: EdgeInsets.only(left: row.indent ? 36 : 16, right: 16),
      title: Tip(
        row.tip,
        child: Text(
          row.title,
          style: row.strong
              ? const TextStyle(fontWeight: FontWeight.w600)
              : null,
        ),
      ),
      trailing: Text(row.trailing, style: trailingStyle),
      onTap: row.onTap,
    );
  }
}

class _SuggestionRow {
  const _SuggestionRow({
    required this.title,
    required this.tip,
    required this.trailing,
    required this.onTap,
    this.indent = false,
    this.strong = true,
  });

  final String title;
  final String tip;
  final String trailing;
  final VoidCallback? onTap;
  final bool indent;
  final bool strong;
}
