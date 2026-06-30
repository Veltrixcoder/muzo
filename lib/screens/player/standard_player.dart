import 'dart:ui';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/song_options_menu.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:audio_service/audio_service.dart';
import 'package:widget_marquee/widget_marquee.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/lyrics_service.dart';
import 'package:muzo/widgets/lyrics_view.dart';

class StandardPlayer extends ConsumerStatefulWidget {
  const StandardPlayer({super.key});

  @override
  ConsumerState<StandardPlayer> createState() => _StandardPlayerState();
}

class _StandardPlayerState extends ConsumerState<StandardPlayer> {
  late PageController _pageController;
  int _currentPage = 1;
  bool _isLyricsExpanded = false;
  Timer? _lyricsInactivityTimer;
  Drag? _drag;
  bool _showQueueOnRight = false;

  // Lyrics state
  bool _isLoadingLyrics = false;

  MuzoItem _getMuzoItemFromMediaItem(MediaItem mediaItem) {
    return MuzoItem(
      videoId: mediaItem.id,
      title: mediaItem.title,
      thumbnails: [
        MuzoThumbnail(
          url: mediaItem.artUri?.toString() ?? '',
          width: 0,
          height: 0,
        ),
      ],
      artists: (mediaItem.artist ?? '')
          .split(RegExp(r'\s*,\s*'))
          .map((name) => MuzoArtist(
                name: name.trim(),
                id: mediaItem.extras?['artistId'] ?? '',
              ))
          .where((a) => a.name.isNotEmpty)
          .toList(),
      resultType: mediaItem.extras?['resultType'] ?? 'video',
      isExplicit: false,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lyricsInactivityTimer?.cancel();
    super.dispose();
  }

  void _startLyricsInactivityTimer() {
    _lyricsInactivityTimer?.cancel();
    if (_currentPage == 0 && !_isLyricsExpanded) {
      _lyricsInactivityTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _currentPage == 0) {
          setState(() {
            _isLyricsExpanded = true;
          });
        }
      });
    }
  }

  void _resetLyricsInactivityTimer() {
    if (_currentPage != 0) return;
    if (_isLyricsExpanded) {
      setState(() {
        _isLyricsExpanded = false;
      });
    }
    _startLyricsInactivityTimer();
  }

  Future<void> _fetchLyrics(MediaItem mediaItem) async {
    debugPrint('standard_player: _fetchLyrics: mediaItem.title="${mediaItem.title}", mediaItem.artist="${mediaItem.artist}", mediaItem.extras=${mediaItem.extras}');
    final cachedTitle = ref.read(cachedLyricsTitleProvider);
    if (cachedTitle == mediaItem.title) return;
    if (_isLoadingLyrics) return;
    if (!mounted) return;
    setState(() {
      _isLoadingLyrics = true;
    });
    try {
      final lyrics = await ref
          .read(lyricsServiceProvider)
          .fetchLyrics(
            mediaItem.title,
            mediaItem.artist ?? '',
            mediaItem.duration?.inSeconds ??
                ref.read(audioHandlerProvider).player.duration?.inSeconds ??
                0,
            videoId: mediaItem.id,
          );
      if (mounted) {
        ref.read(cachedLyricsProvider.notifier).state = lyrics;
        ref.read(cachedLyricsTitleProvider.notifier).state = mediaItem.title;
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ref.read(cachedLyricsProvider.notifier).state = null;
        ref.read(cachedLyricsTitleProvider.notifier).state = mediaItem.title;
        setState(() {
          _isLoadingLyrics = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final mediaItemAsync = ref.watch(currentMediaItemProvider);

    final mediaItem = mediaItemAsync.value;
    final artUri = mediaItem?.artUri;

    final cachedLyricsTitle = ref.watch(cachedLyricsTitleProvider);

    // Listen to track changes to fetch lyrics
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (previous, next) {
      next.whenData((item) {
        if (item != null) {
          _fetchLyrics(item);
        }
      });
    });

    // Initial lyrics fetch if mediaItem is already loaded
    if (mediaItem != null && cachedLyricsTitle != mediaItem.title && !_isLoadingLyrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchLyrics(mediaItem);
      });
    }

    // Responsive artwork calculation (uses percentage of width and capping at height percentage)
    double playerArtImageSize = size.width * 0.88;
    final double maxArtSize = size.height * 0.42;
    if (playerArtImageSize > maxArtSize) {
      playerArtImageSize = maxArtSize;
    }
    if (playerArtImageSize < 150) playerArtImageSize = 150; // Safeguard

    final backgroundStack = artUri != null
        ? SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: artUri.toString().replaceAll(RegExp(r'w\d+-h\d+'), 'w400-h400'),
              fit: BoxFit.cover,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const ColoredBox(color: Colors.black54),
            ),
          )
        : const ColoredBox(color: Colors.black54);



    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic Blurred background — full screen
          // Scaled up to 1.2x to push the blurred edges (which fade to transparent) completely off-screen,
          // preventing the underlying background color from bleeding in at the edges.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: Transform.scale(
                scale: 1.2,
                child: backgroundStack,
              ),
            ),
          ),

          // Main contents — NOT wrapped in SafeArea so portrait art is edge-to-edge
          LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = size.width > size.height;
              final isTabletOrDesktop = size.shortestSide >= 600;

              if (isTabletOrDesktop || isLandscape) {
                return SafeArea(
                  bottom: false,
                  child: _buildDesktopLayout(context, ref, mediaItem),
                );
              } else {
                // Portrait — no SafeArea so art goes behind status bar
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) {
                    _resetLyricsInactivityTimer();
                  },
                  child: Stack(
                    children: [
                      // Swipeable PageView
                      Positioned.fill(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (page) {
                            setState(() {
                              _currentPage = page;
                              if (page != 0) {
                                _isLyricsExpanded = false;
                                _lyricsInactivityTimer?.cancel();
                              } else {
                                _startLyricsInactivityTimer();
                              }
                            });
                          },
                          children: [
                            _buildLyricsPage(context, ref, mediaItem),
                            _buildMainPage(context, ref, mediaItem, playerArtImageSize),
                            _buildQueuePage(context, ref, mediaItem),
                          ],
                        ),
                      ),

                      // Sticky pull-down handle — overlaid at top
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        top: _isLyricsExpanded
                            ? -40
                            : MediaQuery.of(context).padding.top + 8,
                        left: 0,
                        right: 0,
                        height: 24,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => Navigator.of(context).pop(),
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Sticky Controls overlayed at bottom
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        right: 0,
                        bottom: _isLyricsExpanded ? -300 : 0,
                        child: _buildStickyBottomControls(context, ref, mediaItem),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainPage(BuildContext context, WidgetRef ref, MediaItem? mediaItem, double playerArtSize) {
    final screenHeight = MediaQuery.of(context).size.height;
    final controlsHeight = screenHeight * 0.34;
    // Art fills from the very top of the screen down to the controls area
    final artHeight = screenHeight - controlsHeight;

    return Stack(
      children: [
        // Full-bleed album art — edge-to-edge from top, fading into the blurred background below
        // This avoids any black/white tinting, keeping the blur pure in both modes.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: artHeight + controlsHeight * 0.15,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.65, 1.0],
              colors: [Colors.white, Colors.white, Colors.transparent],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (details) {
                if (_pageController.hasClients) {
                  _drag = _pageController.position.drag(details, () => _drag = null);
                }
              },
              onHorizontalDragUpdate: (details) => _drag?.update(details),
              onHorizontalDragEnd: (details) => _drag?.end(details),
              onHorizontalDragCancel: () => _drag?.cancel(),
              child: mediaItem?.artUri != null
                  ? CachedNetworkImage(
                      imageUrl: mediaItem!.artUri.toString().replaceAll(
                        RegExp(r'w\d+-h\d+'),
                        'w800-h800',
                      ),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const SizedBox.shrink(),
                      errorWidget: (context, url, error) => const ColoredBox(color: Colors.transparent),
                    )
                  : const ColoredBox(color: Colors.transparent),
            ),
          ),
        ),

        // Title & artist overlay — sits just above the controls area
        if (mediaItem != null)
          Positioned(
            left: 22,
            right: 22,
            bottom: controlsHeight + 12,
            child: _buildSongMetaRow(context, ref, mediaItem),
          ),
      ],
    );
  }


  Widget _buildSongMetaRow(BuildContext context, WidgetRef ref, MediaItem mediaItem) {
    final storage = ref.watch(storageServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Artist
        Text(
          mediaItem.artist ?? "Unknown Artist",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Title
            Expanded(
              child: SizedBox(
                height: 34,
                child: Marquee(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(seconds: 10),
                  child: Text(
                    mediaItem.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Options button (circular, translucent background)
            _buildCircularIconButton(
              context,
              icon: const Icon(
                Icons.more_horiz,
                color: Colors.white,
                size: 18,
              ),
              onPressed: () {
                final result = _getMuzoItemFromMediaItem(mediaItem);
                SongOptionsMenu.show(context, ref, result, fromPlayer: true);
              },
            ),

            const SizedBox(width: 10),

            // Favorite button (circular, translucent background)
            ValueListenableBuilder(
              valueListenable: storage.favoritesListenable,
              builder: (context, favorites, _) {
                final isFav = storage.isFavorite(mediaItem.id);
                return _buildCircularIconButton(
                  context,
                  icon: Icon(
                    isFav ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
                    color: isFav ? Colors.red[400] : Colors.white,
                    size: 18,
                  ),
                  onPressed: () {
                    final result = _getMuzoItemFromMediaItem(mediaItem);
                    storage.toggleFavorite(result);
                    showGlassSnackBar(
                      context,
                      isFav ? 'Removed from favorites' : 'Added to favorites',
                    );
                  },
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularIconButton(BuildContext context, {required Widget icon, required VoidCallback onPressed}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    if (mediaItem == null) return const SizedBox.shrink();
    final storage = ref.watch(storageServiceProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        if (_pageController.hasClients) {
          _drag = _pageController.position.drag(details, () {
            _drag = null;
          });
        }
      },
      onHorizontalDragUpdate: (details) {
        _drag?.update(details);
      },
      onHorizontalDragEnd: (details) {
        _drag?.end(details);
      },
      onHorizontalDragCancel: () {
        _drag?.cancel();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Album Art thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: mediaItem.artUri.toString(),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            const SizedBox(width: 12),
            // Title / Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mediaItem.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mediaItem.artist ?? "Unknown Artist",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Favorite button (circular, translucent background)
            ValueListenableBuilder(
              valueListenable: storage.favoritesListenable,
              builder: (context, favorites, _) {
                final isFav = storage.isFavorite(mediaItem.id);
                return IconButton(
                  icon: Icon(
                    isFav ? FluentIcons.star_24_filled : FluentIcons.star_24_regular,
                    color: isFav ? Colors.yellow[600] : Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    final result = _getMuzoItemFromMediaItem(mediaItem);
                    storage.toggleFavorite(result);
                  },
                );
              },
            ),
            // Options button
            IconButton(
              icon: Icon(Icons.more_horiz, color: Colors.white, size: 20),
              onPressed: () {
                final result = _getMuzoItemFromMediaItem(mediaItem);
                SongOptionsMenu.show(context, ref, result, fromPlayer: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsPage(BuildContext context, WidgetRef ref, MediaItem? mediaItem, {bool hasBottomSpacer = true}) {
    if (mediaItem == null) return const SizedBox.shrink();
    final screenHeight = MediaQuery.of(context).size.height;
    final cachedLyrics = ref.watch(cachedLyricsProvider);
    
    return Column(
      children: [
        if (hasBottomSpacer) ...[
          // Spacing for top handle / safe area
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          
          // Compact song header (always visible)
          _buildCompactHeader(context, ref, mediaItem),
          
          const SizedBox(height: 8),
        ],

        // Lyrics scroll container
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _isLoadingLyrics
                ? Center(child: CircularProgressIndicator(color: Colors.white))
                : cachedLyrics == null
                    ? Center(
                        child: Text(
                          "No lyrics found",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16),
                        ),
                      )
                    : LyricsView(
                        lyrics: cachedLyrics,
                        onClose: () {},
                        positionStream: ref.watch(audioHandlerProvider).player.positionStream,
                        totalDuration: mediaItem.duration ?? ref.watch(audioHandlerProvider).player.duration ?? Duration.zero,
                        isEmbedded: false,
                        scrollable: true,
                        accentColor: Colors.white,
                      ),
          ),
        ),
        
        if (hasBottomSpacer)
          // Offset spacer for controls - proportional to screen size
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            height: _isLyricsExpanded ? screenHeight * 0.05 : screenHeight * 0.33,
          ),
      ],
    );
  }

  Widget _buildQueuePage(BuildContext context, WidgetRef ref, MediaItem? mediaItem, {bool hasBottomSpacer = true}) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return StreamBuilder<SequenceState?>(
      stream: audioHandler.player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final sequence = state?.sequence ?? [];
        final currentIndex = state?.currentIndex ?? 0;
        
        // Items after current index
        final nextItems = currentIndex + 1 < sequence.length 
            ? sequence.sublist(currentIndex + 1) 
            : [];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              if (hasBottomSpacer) ...[
                // Header spacing
                SizedBox(height: MediaQuery.of(context).padding.top + 8),
                
                // Compact header
                _buildCompactHeader(context, ref, mediaItem),
              ],

              // Queue Controls Row
              _buildQueueControlsRow(context, ref),

              // Playing Next Row
              _buildPlayingNextRow(context, ref, sequence.length),

              // Queue List
              Expanded(
                child: nextItems.isEmpty
                    ? Center(
                        child: Text(
                          "No upcoming songs",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                        ),
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: nextItems.length,
                        onReorder: (oldIndex, newIndex) {
                          audioHandler.reorderQueue(
                            currentIndex + 1 + oldIndex,
                            currentIndex + 1 + newIndex,
                          );
                        },
                        itemBuilder: (context, index) {
                          final audioSource = nextItems[index];
                          final item = audioSource.tag as MediaItem;

                          return _buildQueueItemTile(
                            context,
                            ref,
                            item,
                            currentIndex + 1 + index,
                            onTap: () {
                              audioHandler.player.seek(Duration.zero, index: currentIndex + 1 + index);
                              audioHandler.player.play();
                            },
                            onRemove: () {
                              audioHandler.removeQueueItem(currentIndex + 1 + index);
                            },
                          );
                        },
                      ),
              ),

              if (hasBottomSpacer)
                // Spacer to ensure queue items are only in the part above controls
                SizedBox(height: screenHeight * 0.33),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueControlsRow(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;
    final storage = ref.watch(storageServiceProvider);

    return StreamBuilder<bool>(
      stream: player.shuffleModeEnabledStream,
      builder: (context, shuffleSnapshot) {
        final shuffleEnabled = shuffleSnapshot.data ?? false;
        return StreamBuilder<LoopMode>(
          stream: player.loopModeStream,
          builder: (context, loopSnapshot) {
            final loopMode = loopSnapshot.data ?? LoopMode.off;
            final isRepeatEnabled = loopMode != LoopMode.off;

            return ValueListenableBuilder<bool>(
              valueListenable: audioHandler.isLofiModeNotifier,
              builder: (context, isLofi, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Shuffle
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          FluentIcons.arrow_shuffle_24_regular,
                          color: shuffleEnabled ? Colors.black : Colors.white,
                          size: 20,
                        ),
                        isActive: shuffleEnabled,
                        onPressed: () => player.setShuffleModeEnabled(!shuffleEnabled),
                      ),
                      // Repeat
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          loopMode == LoopMode.one
                              ? FluentIcons.arrow_repeat_1_24_regular
                              : FluentIcons.arrow_repeat_all_24_regular,
                          color: isRepeatEnabled ? Colors.black : Colors.white,
                          size: 20,
                        ),
                        isActive: isRepeatEnabled,
                        onPressed: () async {
                          if (loopMode == LoopMode.off) {
                            await player.setLoopMode(LoopMode.all);
                          } else if (loopMode == LoopMode.all) {
                            await player.setLoopMode(LoopMode.one);
                          } else {
                            await player.setLoopMode(LoopMode.off);
                          }
                        },
                      ),
                      // Auto-queue / Infinity
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          Icons.all_inclusive,
                          color: storage.isAutoQueueEnabled ? Colors.black : Colors.white.withValues(alpha: 0.8),
                          size: 20,
                        ),
                        isActive: storage.isAutoQueueEnabled,
                        onPressed: () async {
                          await storage.setAutoQueueEnabled(!storage.isAutoQueueEnabled);
                          setState(() {});
                        },
                      ),
                      // Lofi mode
                      _buildQueuePillButton(
                        context,
                        icon: Icon(
                          Icons.waves_rounded,
                          color: isLofi ? Colors.black : Colors.white,
                          size: 20,
                        ),
                        isActive: isLofi,
                        onPressed: () => audioHandler.toggleLofiMode(),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQueuePillButton(BuildContext context, {required Widget icon, required bool isActive, required VoidCallback onPressed}) {
    final activeBg = Colors.white;
    final inactiveBg = Colors.white.withValues(alpha: 0.15);

    return Container(
      width: 58,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Center(child: icon),
        ),
      ),
    );
  }

  Widget _buildPlayingNextRow(BuildContext context, WidgetRef ref, int queueLength) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final currentItem = ref.watch(currentMediaItemProvider).value;
    final albumName = currentItem?.album ?? "Muzo";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Playing Next",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "From $albumName",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: queueLength <= 1
                ? null
                : () {
                    audioHandler.clearQueue();
                    showGlassSnackBar(context, 'Queue cleared');
                  },
            child: Text(
              "Clear",
              style: TextStyle(
                color: queueLength <= 1 ? Colors.white.withValues(alpha: 0.3) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemTile(
    BuildContext context,
    WidgetRef ref,
    MediaItem item,
    int index, {
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Dismissible(
      key: ValueKey('dismiss_queue_${item.id}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) => onRemove(),
      child: GestureDetector(
        key: ValueKey('tile_queue_${item.id}_$index'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: item.artUri.toString(),
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist ?? 'Unknown Artist',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyBottomControls(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding > 0 ? bottomPadding : screenHeight * 0.028),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Bar — custom Slider with rounded-rect thumb matching reference
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = mediaItem?.duration ?? player.duration ?? Duration.zero;
              final maxMs = duration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
              final posMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      thumbShape: const _PlayerRoundedRectThumb(width: 6, height: 26, radius: 3),
                      trackHeight: 14,
                      activeTrackColor: Colors.white.withValues(alpha: 0.80),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                      trackShape: const _PlayerSliderTrackShape(),
                    ),
                    child: Slider(
                      value: posMs,
                      max: maxMs,
                      onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          duration != Duration.zero ? _formatDuration(duration) : '0:00',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          SizedBox(height: screenHeight * 0.028),

          // Playback controls: Prev | Play/Pause | Next
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous
              IconButton(
                iconSize: 44,
                icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white),
                onPressed: () => audioHandler.skipToPrevious(),
              ),

              // Play / Pause
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (context, snapshot) {
                  final state = snapshot.data;
                  final playing = state?.playing ?? false;
                  final isLoading = state?.processingState == ProcessingState.loading ||
                      state?.processingState == ProcessingState.buffering;

                  if (isLoading) {
                    return const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      ),
                    );
                  }

                  return IconButton(
                    iconSize: 56,
                    icon: Icon(
                      playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (playing) player.pause();
                      else player.play();
                    },
                  );
                },
              ),

              // Next
              IconButton(
                iconSize: 44,
                icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white),
                onPressed: () => audioHandler.skipToNext(),
              ),
            ],
          ),

          SizedBox(height: screenHeight * 0.032),

          // Bottom nav: Lyrics | Player | Queue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Lyrics
              IconButton(
                iconSize: 24,
                icon: Icon(
                  FluentIcons.chat_24_regular,
                  color: _currentPage == 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                onPressed: () => _pageController.animateToPage(
                  _currentPage == 0 ? 1 : 0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                ),
              ),

              // Player (main)
              IconButton(
                iconSize: 24,
                icon: Icon(
                  Icons.album_rounded,
                  color: _currentPage == 1
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                onPressed: () => _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                ),
              ),

              // Queue
              IconButton(
                iconSize: 24,
                icon: Icon(
                  FluentIcons.list_24_regular,
                  color: _currentPage == 2
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
                onPressed: () => _pageController.animateToPage(
                  _currentPage == 2 ? 1 : 2,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanelTab(BuildContext context, String label, bool isActive, VoidCallback onTap) {

    
    return SizedBox(
      height: 32,
      child: Material(
        color: isActive 
            ? Colors.white 
            : Colors.white.withValues(alpha: 0.15),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive 
                      ? Colors.black 
                      : Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBarOnly(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    final player = ref.watch(audioHandlerProvider).player;
    final screenHeight = MediaQuery.of(context).size.height;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = mediaItem?.duration ?? player.duration ?? Duration.zero;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderThemeData(
                thumbShape: const _PlayerRoundedRectThumb(width: 0, height: 0, radius: 0),
                trackHeight: 8,
                activeTrackColor: Colors.white.withValues(alpha: 0.85),
                inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                thumbColor: Colors.transparent,
                overlayShape: SliderComponentShape.noOverlay,
                trackShape: const _PlayerSliderTrackShape(),
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(0.0, duration.inMilliseconds.toDouble().clamp(1.0, double.infinity)),
                max: duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
                onChanged: (v) => player.seek(Duration(milliseconds: v.round())),
              ),
            ),
            SizedBox(height: screenHeight * 0.008),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w400),
                ),
                Text(
                  duration != Duration.zero
                      ? "-${_formatDuration(duration - position)}"
                      : "0:00",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaybackControlsOnly(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final player = audioHandler.player;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(CupertinoIcons.backward_fill, color: Colors.white, size: 38),
          onPressed: () => audioHandler.skipToPrevious(),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing ?? false;
            final isLoading = processingState == ProcessingState.loading || processingState == ProcessingState.buffering;

            if (isLoading) {
              return SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              );
            }

            return IconButton(
              icon: Icon(
                playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                color: Colors.white,
                size: 54,
              ),
              onPressed: () {
                if (playing) {
                  player.pause();
                } else {
                  player.play();
                }
              },
            );
          },
        ),
        IconButton(
          icon: Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 38),
          onPressed: () => audioHandler.skipToNext(),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref, MediaItem? mediaItem) {
    final size = MediaQuery.of(context).size;

    // Calculate responsive sizes based on available height to prevent vertical overflow
    final double leftPaneHeight = size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 40;
    double albumArtSize = leftPaneHeight * 0.40;
    if (albumArtSize > 280) albumArtSize = 280;
    if (albumArtSize < 100) albumArtSize = 100;

    double spacing1 = (leftPaneHeight * 0.03).clamp(4.0, 24.0);
    double spacing2 = (leftPaneHeight * 0.02).clamp(4.0, 16.0);
    double spacing3 = (leftPaneHeight * 0.015).clamp(4.0, 12.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Left: Normal Player view as in mobile
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Large Album Art
                              Center(
                                child: StreamBuilder<bool>(
                                  stream: ref.read(audioHandlerProvider).player.playingStream,
                                  initialData: ref.read(audioHandlerProvider).player.playing,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data ?? false;
                                    final double artSize = isPlaying ? albumArtSize : albumArtSize * 0.88;

                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 350),
                                      curve: Curves.easeOutCubic,
                                      width: artSize,
                                      height: artSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(isPlaying ? 12 : 20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isPlaying ? 0.45 : 0.3),
                                            blurRadius: isPlaying ? 32 : 16,
                                            spreadRadius: isPlaying ? -4 : -2,
                                            offset: Offset(0, isPlaying ? 16 : 8),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(isPlaying ? 12 : 20),
                                        child: mediaItem?.artUri != null
                                            ? CachedNetworkImage(
                                                imageUrl: mediaItem!.artUri.toString().replaceAll(
                                                  RegExp(r'w\d+-h\d+'),
                                                  'w800-h800',
                                                ),
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(color: Colors.white.withValues(alpha: 0.1)),
                                                errorWidget: (context, url, error) => Container(color: Colors.white.withValues(alpha: 0.1)),
                                              )
                                            : Container(
                                                color: Colors.white.withValues(alpha: 0.1),
                                                child: Icon(Icons.music_note, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(height: spacing1),
                              // Title, Artist, Favorite, Options row
                              if (mediaItem != null)
                                _buildSongMetaRow(context, ref, mediaItem),
                              SizedBox(height: spacing2),
                              // Progress Slider
                              _buildProgressBarOnly(context, ref, mediaItem),
                              SizedBox(height: spacing3),
                              // Play/Pause / Prev / Next controls
                              _buildPlaybackControlsOnly(context, ref),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Vertical Divider
          Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(vertical: 32),
          ),

          // Right: Lyrics / Queue panel
          Expanded(
            flex: 6,
            child: Column(
              children: [
                // Option Tabs (Lyrics / Queue)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildRightPanelTab(context, 'Lyrics', !_showQueueOnRight, () {
                        setState(() {
                          _showQueueOnRight = false;
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildRightPanelTab(context, 'Queue', _showQueueOnRight, () {
                        setState(() {
                          _showQueueOnRight = true;
                        });
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: _showQueueOnRight
                      ? _buildQueuePage(context, ref, mediaItem, hasBottomSpacer: false)
                      : _buildLyricsPage(context, ref, mediaItem, hasBottomSpacer: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom rounded-rectangle thumb for the player slider.
/// Matches the reference image: a small rounded-rect bar at the playback position.
class _PlayerRoundedRectThumb extends SliderComponentShape {
  final double width;
  final double height;
  final double radius;

  const _PlayerRoundedRectThumb({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.white
      ..style = PaintingStyle.fill;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), paint);
  }
}

/// Custom track shape: active fill has flat right end, inactive has flat left end.
/// This eliminates the rounded cap at the thumb position on the fill side.
class _PlayerSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _PlayerSliderTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final double r = trackRect.height / 2;

    // Active track: rounded left cap, flat right end (at thumb)
    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.white;
    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        trackRect.left,
        trackRect.top,
        thumbCenter.dx,
        trackRect.bottom,
        topLeft: Radius.circular(r),
        bottomLeft: Radius.circular(r),
        topRight: Radius.zero,
        bottomRight: Radius.zero,
      ),
      activePaint,
    );

    // Inactive track: flat left end (at thumb), rounded right cap
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white.withValues(alpha: 0.2);
    context.canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        thumbCenter.dx,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
        topLeft: Radius.zero,
        bottomLeft: Radius.zero,
        topRight: Radius.circular(r),
        bottomRight: Radius.circular(r),
      ),
      inactivePaint,
    );
  }
}
