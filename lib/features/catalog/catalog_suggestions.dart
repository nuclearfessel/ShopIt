import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../../ui/tip.dart';

/// Matching catalog items for [query], shown as tappable rows. A group such as
/// "Onions" is followed by its indented types/cuts. Renders nothing for an
/// empty query or no matches.
class CatalogSuggestions extends ConsumerWidget {
  const CatalogSuggestions({
    super.key,
    required this.query,
    required this.onPick,
  });

  final String query;
  final ValueChanged<CatalogItem> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final results = ref.watch(catalogSearchProvider(query.trim()));
    final items = results.value ?? const <CatalogItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final small = Theme.of(context).textTheme.bodySmall;
    return ConstrainedBox(
      // Scale with the window so the suggestions never squeeze the rest of the
      // screen into an overflow on short windows.
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
            for (final i in items)
              ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.only(
                  left: i.parentName.isEmpty ? 16 : 36,
                  right: 16,
                ),
                title: Tip(
                  'Use "${i.name}"',
                  child: Text(
                    i.name,
                    style: i.parentName.isEmpty
                        ? const TextStyle(fontWeight: FontWeight.w600)
                        : null,
                  ),
                ),
                trailing: Text(
                  i.parentName.isEmpty ? i.category : i.parentName,
                  style: small,
                ),
                onTap: () => onPick(i),
              ),
          ],
        ),
      ),
    );
  }
}
