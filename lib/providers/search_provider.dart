import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/muzo_api_service.dart';

final searchControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

final searchFocusNodeProvider = Provider<FocusNode>((ref) {
  final focusNode = FocusNode();
  ref.onDispose(() => focusNode.dispose());
  return focusNode;
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFilterProvider = StateProvider<String>((ref) => 'all');

final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, AsyncValue<List<MuzoItem>>>(
      (ref) {
        return SearchResultsNotifier(ref);
      },
    );

class SearchResultsNotifier
    extends StateNotifier<AsyncValue<List<MuzoItem>>> {
  final Ref ref;
  late final MuzoApiService _api = ref.read(muzoApiServiceProvider);
  String? _continuationToken;
  bool _isLoadingMore = false;

  /// Cancellation token: every new search increments this. Callbacks check
  /// if their generation still matches before writing state, preventing stale
  /// results from an older query overwriting a newer one.
  int _searchGen = 0;

  /// Debounce timer — waits 300 ms after last query change before firing.
  Timer? _debounceTimer;

  SearchResultsNotifier(this.ref) : super(const AsyncValue.data([])) {
    // Listen to query and filter changes
    ref.listen(searchQueryProvider, (previous, next) {
      if (next.isNotEmpty) {
        _scheduleSearch(next, ref.read(searchFilterProvider));
      } else {
        _cancelDebounce();
        state = const AsyncValue.data([]);
      }
    });
    ref.listen(searchFilterProvider, (previous, next) {
      final query = ref.read(searchQueryProvider);
      // Filter changes should be instant (user explicitly tapped a chip)
      if (query.isNotEmpty) _search(query, next);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Debounces the search — waits 300 ms of inactivity before firing so we
  /// don't hammer the API on every single keystroke.
  void _scheduleSearch(String query, String filter) {
    _cancelDebounce();
    // Show loading immediately so the UI feels responsive
    state = const AsyncValue.loading();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(query, filter);
    });
  }

  Future<void> _search(String query, String filter) async {
    // Increment generation — any in-flight call with an older gen will discard results.
    final gen = ++_searchGen;
    state = const AsyncValue.loading();
    _continuationToken = null;
    try {
      if (filter == 'all') {
        final futures = [
          _api.search(query, filter: 'songs').then((res) => res.results.map((r) => r.copyWith(category: 'Songs')).toList()).catchError((e) {
            debugPrint('Search songs error: $e');
            return <MuzoItem>[];
          }),
          _api.search(query, filter: 'videos').then((res) => res.results.map((r) => r.copyWith(category: 'Videos')).toList()).catchError((e) {
            debugPrint('Search videos error: $e');
            return <MuzoItem>[];
          }),
          _api.search(query, filter: 'albums').then((res) => res.results.map((r) => r.copyWith(category: 'Albums')).toList()).catchError((e) {
            debugPrint('Search albums error: $e');
            return <MuzoItem>[];
          }),
          _api.search(query, filter: 'artists').then((res) => res.results.map((r) => r.copyWith(category: 'Artists')).toList()).catchError((e) {
            debugPrint('Search artists error: $e');
            return <MuzoItem>[];
          }),
          _api.search(query, filter: 'playlists').then((res) => res.results.map((r) => r.copyWith(category: 'Playlists')).toList()).catchError((e) {
            debugPrint('Search playlists error: $e');
            return <MuzoItem>[];
          }),
        ];
        final resultsArray = await Future.wait(futures);
        // Discard if a newer search was started while we were awaiting
        if (gen != _searchGen || !mounted) return;
        _continuationToken = null;
        state = AsyncValue.data(resultsArray.expand((i) => i).toList());
      } else {
        final response = await _api.search(query, filter: filter);
        // Discard if a newer search was started while we were awaiting
        if (gen != _searchGen || !mounted) return;
        _continuationToken = response.continuationToken;
        state = AsyncValue.data(response.results);
      }
    } catch (e, st) {
      if (gen != _searchGen || !mounted) return;
      state = AsyncValue.error(e, st);
    }
  }


  Future<void> loadMore() async {
    if (_continuationToken == null || _isLoadingMore) return;

    _isLoadingMore = true;
    final currentResults = state.value ?? [];
    final query = ref.read(searchQueryProvider);
    final filter = ref.read(searchFilterProvider);

    try {
      final response = await _api.search(
        query,
        filter: filter,
        continuationToken: _continuationToken,
      );
      _continuationToken = response.continuationToken;
      state = AsyncValue.data([...currentResults, ...response.results]);
    } catch (e) {
      debugPrint('Error loading more search results: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _continuationToken != null;
}

final searchSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) return [];
  final apiService = ref.read(muzoApiServiceProvider);
  return await apiService.getSearchSuggestions(query);
});
