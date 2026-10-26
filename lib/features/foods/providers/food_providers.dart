import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:my_meal/features/foods/models/food_item.dart';
import 'package:my_meal/features/foods/repositories/food_repository.dart';

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository();
});

class FoodSearchQueryNotifier extends StateNotifier<String> {
  FoodSearchQueryNotifier() : super('');

  void updateQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final foodSearchQueryProvider = StateNotifierProvider<FoodSearchQueryNotifier, String>((ref) {
  return FoodSearchQueryNotifier();
});

class FoodListNotifier extends StateNotifier<AsyncValue<List<FoodItem>>> {
  final FoodRepository _repository;
  String _currentQuery = '';

  FoodListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadFoods();
  }

  Future<void> loadFoods([String? query]) async {
    _currentQuery = query ?? _currentQuery;
    state = const AsyncValue.loading();
    try {
      final foods = await _repository.getAllFoods(query: _currentQuery);
      state = AsyncValue.data(foods);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addFood(FoodItem food) async {
    await _repository.insertFood(food);
    await loadFoods();
  }

  Future<void> updateFood(FoodItem food) async {
    await _repository.updateFood(food);
    await loadFoods();
  }

  Future<void> deleteFood(String id) async {
    await _repository.deleteFood(id);
    await loadFoods();
  }
}

final foodListProvider = StateNotifierProvider<FoodListNotifier, AsyncValue<List<FoodItem>>>((ref) {
  final repo = ref.watch(foodRepositoryProvider);
  return FoodListNotifier(repo);
});
