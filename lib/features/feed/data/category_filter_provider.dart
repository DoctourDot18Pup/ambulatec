import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The currently selected category filter.
/// 'todos' means no filter applied.
final categoryFilterProvider = StateProvider<String>((ref) => 'todos');

/// All available categories, including the catch-all 'todos'.
const List<String> kCategories = [
  'todos',
  'comida',
  'bebidas',
  'postres',
  'snacks',
  'otros',
];
