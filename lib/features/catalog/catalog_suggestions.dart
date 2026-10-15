import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Matching catalog items for [query], shown as tappable rows with their
/// category. Renders nothing for an empty query or no matches.
class CatalogSuggestions extends ConsumerWidget {
  const CatalogSuggestions(
      {super.key, required this.query, required this.onPick});

  final String query;
  final ValueChanged<CatalogItem> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final results = ref.watch(catalogSearchProvider(query.trim()));
    final items = results.value ?? const <CatalogItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final i in items)
          ListTile(
            dense: true,
            title: Text(i.name),
            trailing: Text(i.category,
                style: Theme.of(context).textTheme.bodySmall),
            onTap: () => onPick(i),
          ),
      ]),
    );
  }
}
