import 'package:flutter_riverpod/flutter_riverpod.dart';

class _CategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => 'todos';
  void update(String value) => state = value;
}

/// The currently selected category filter.
/// 'todos' means no filter applied.
final categoryFilterProvider =
    NotifierProvider<_CategoryFilterNotifier, String>(_CategoryFilterNotifier.new);

/// All available categories, including the catch-all 'todos'.
const List<String> kCategories = [
  'todos',
  'comida',
  'bebidas',
  'postres',
  'snacks',
  'otros',
];
