import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/global_background.dart';
import 'package:muzo/widgets/glass_container.dart';
import 'package:muzo/widgets/skeleton_loader.dart';
import 'package:muzo/widgets/result_tile.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final List<MuzoItem> _tracks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 30;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTracks(isRefresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _loadMoreTracks();
      }
    }
  }

  Future<void> _loadTracks({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _offset = 0;
        _isLoading = true;
        _errorMessage = null;
        _tracks.clear();
      });
    }

    try {
      final api = ref.read(muzoApiServiceProvider);
      final result = await api.getCommunityFeed(
        limit: _limit,
        offset: _offset,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      final List<MuzoItem> newTracks = List<MuzoItem>.from(result['tracks'] ?? []);
      final bool newHasMore = result['hasMore'] as bool? ?? false;

      if (mounted) {
        setState(() {
          _tracks.addAll(newTracks);
          _hasMore = newHasMore;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMoreTracks() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });
    await _loadTracks(isRefresh: false);
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _loadTracks(isRefresh: true);
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final currentMediaItem = ref.watch(currentMediaItemProvider).value;
    final isPlaying = ref.watch(isPlayingProvider).value ?? false;

    return GlobalBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Premium Frosted Header and Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.people_community_24_regular,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Community Feed',
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _onSearchChanged,
                          style: TextStyle(color: cs.onSurface, fontSize: 14),
                          cursorColor: theme.primaryColor,
                          decoration: InputDecoration(
                            hintText: 'Search community music...',
                            hintStyle: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 0, right: 8),
                              child: Icon(
                                FluentIcons.search_24_regular,
                                color: cs.onSurface.withValues(alpha: 0.6),
                                size: 18,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 18,
                            ),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                if (value.text.isEmpty) return const SizedBox.shrink();
                                return IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: Icon(
                                    FluentIcons.dismiss_circle_24_filled,
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    _searchFocusNode.requestFocus();
                                  },
                                );
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Tracks List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadTracks(isRefresh: true),
                  color: theme.primaryColor,
                  backgroundColor: theme.cardColor,
                  child: _buildContent(currentMediaItem, isPlaying, theme, cs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    dynamic currentMediaItem,
    bool isPlaying,
    ThemeData theme,
    ColorScheme cs,
  ) {
    if (_isLoading && _tracks.isEmpty) {
      return _buildSkeletonLoader();
    }

    if (_errorMessage != null && _tracks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.warning_24_regular,
                size: 48,
                color: cs.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadTracks(isRefresh: true),
                icon: const Icon(FluentIcons.arrow_sync_24_regular),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_tracks.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.music_note_2_24_regular,
                size: 72,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No public tracks found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later or search for something else!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _tracks.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _tracks.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CupertinoActivityIndicator(),
            ),
          );
        }

        final item = _tracks[index];
        return ResultTile(result: item);
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(10),
            child: const Row(
              children: [
                SkeletonLoader(width: 52, height: 52, borderRadius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 160, height: 16, borderRadius: 3),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          SkeletonLoader(width: 16, height: 16, borderRadius: 8),
                          SizedBox(width: 6),
                          SkeletonLoader(width: 80, height: 12, borderRadius: 3),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
