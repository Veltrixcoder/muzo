import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/providers/download_provider.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/services/download_service.dart';
import 'package:muzo/widgets/playlist_selection_dialog.dart';
import 'package:muzo/widgets/glass_snackbar.dart';
import 'package:muzo/services/navigator_key.dart';
import 'package:muzo/providers/overlay_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:muzo/widgets/sleep_timer_dialog.dart';
import 'package:muzo/screens/artist_screen.dart';
import 'package:muzo/screens/album_screen.dart';
import 'package:muzo/widgets/glass_container.dart';

class SongOptionsMenu extends ConsumerWidget {
  final MuzoItem result;
  final bool fromHistory;
  final bool fromPlayer;
  final VoidCallback? onClose;

  const SongOptionsMenu({
    super.key,
    required this.result,
    this.fromHistory = false,
    this.fromPlayer = false,
    this.onClose,
  });

  static DateTime? _lastShowTime;

  static void show(
    BuildContext context,
    WidgetRef ref,
    MuzoItem result, {
    bool fromHistory = false,
    bool fromPlayer = false,
  }) {
    final now = DateTime.now();
    if (_lastShowTime != null &&
        now.difference(_lastShowTime!) < const Duration(milliseconds: 500)) {
      return; // Debounce rapid taps
    }
    _lastShowTime = now;

    final RenderBox? button = context.findRenderObject() as RenderBox?;
    if (button == null) return;

    final rootContext = navigatorKey.currentContext;
    if (rootContext == null) return;

    final RenderBox? overlay = Navigator.of(rootContext).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final double bottomPadding = MediaQuery.of(rootContext).padding.bottom;
    final bool isDesktop = MediaQuery.of(rootContext).size.width > 600;

    // Calculate bottom padding space occupied by player and navigation bars
    double occupiedBottom = 0.0;
    if (isDesktop) {
      occupiedBottom = 66.0; // Mini player at bottom
    } else {
      final hasActiveTrack = ref.read(currentMediaItemProvider).value != null;
      if (hasActiveTrack) {
        occupiedBottom = 130.0 + bottomPadding; // Bottom nav + mini player
      } else {
        occupiedBottom = 76.0 + bottomPadding; // Bottom nav only
      }
    }

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & Size(overlay.size.width, overlay.size.height - occupiedBottom),
    );

    showMenu<void>(
      context: rootContext,
      position: position,
      color: Colors.transparent,
      elevation: 0,
      constraints: const BoxConstraints(
        maxWidth: 270,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      items: [
        _CustomPopupMenuContent(
          child: SongOptionsMenu(
            result: result,
            fromHistory: fromHistory,
            fromPlayer: fromPlayer,
            onClose: () => navigatorKey.currentState?.pop(),
          ),
        ),
      ],
    );
  }

  static void hide(WidgetRef ref) {
    ref.read(globalBottomSheetProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ValueListenableBuilder<List<MuzoItem>>(
      valueListenable: storage.favoritesListenable,
      builder: (context, favorites, _) {
        final isFav =
            result.videoId != null && storage.isFavorite(result.videoId!);
        final isDownloaded =
            result.videoId != null && storage.isDownloaded(result.videoId!);

        // Get Thumbnail URL
        String imageUrl = '';
        if (result.thumbnails.isNotEmpty) {
          imageUrl = result.thumbnails.last.url;
        }

        // Build vertical options
        final List<Widget> verticalOptions = [];

        // 1. Go to Album
        if (result.album != null && result.album!.id.isNotEmpty) {
          verticalOptions.add(
            _buildVerticalItem(
              context,
              icon: CupertinoIcons.square_stack,
              title: 'Go to album',
              subtitle: result.album!.name,
              onTap: () {
                onClose?.call();
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (context) => AlbumScreen(
                        albumId: result.album!.id,
                        albumName: result.album!.name,
                        thumbnailUrl: imageUrl,
                      ),
                    ),
                  );
                }
              },
            ),
          );
        }

        // 2. Go to Artist
        if (result.artists != null && result.artists!.isNotEmpty) {
          final artist = result.artists!.first;
          if (artist.id != null && artist.id!.isNotEmpty) {
            verticalOptions.add(
              _buildVerticalItem(
                context,
                icon: CupertinoIcons.person_crop_circle,
                title: 'Go to artist',
                subtitle: artist.name,
                onTap: () {
                  onClose?.call();
                  final ctx = navigatorKey.currentContext;
                  if (ctx != null) {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (context) => ArtistScreen(
                          browseId: artist.id!,
                          artistName: artist.name,
                          thumbnailUrl: imageUrl,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }
        }

        // 3. Play Next
        verticalOptions.add(
          _buildVerticalItem(
            context,
            icon: CupertinoIcons.play_circle,
            title: 'Play next',
            onTap: () {
              onClose?.call();
              ref.read(audioHandlerProvider).playNext(result);
            },
          ),
        );

        // 4. Add to queue
        verticalOptions.add(
          _buildVerticalItem(
            context,
            icon: CupertinoIcons.list_bullet,
            title: 'Add to queue',
            onTap: () {
              onClose?.call();
              ref.read(audioHandlerProvider).addToQueue(result);
              final ctx = navigatorKey.currentContext;
              if (ctx != null) showGlassSnackBar(ctx, 'Added to queue');
            },
          ),
        );

        // 5. Add to playlist
        verticalOptions.add(
          _buildVerticalItem(
            context,
            icon: CupertinoIcons.music_note_list,
            title: 'Add to playlist',
            onTap: () {
              onClose?.call();
              final ctx = navigatorKey.currentContext;
              if (ctx != null) {
                showCupertinoDialog(
                  context: ctx,
                  barrierDismissible: true,
                  builder: (context) => PlaylistSelectionDialog(song: result),
                );
              }
            },
          ),
        );

        // 6. Sleep Timer (Player specific)
        if (fromPlayer) {
          verticalOptions.add(
            _buildVerticalItem(
              context,
              icon: CupertinoIcons.timer,
              title: 'Sleep Timer',
              onTap: () {
                onClose?.call();
                final ctx = navigatorKey.currentContext;
                if (ctx != null) {
                  showDialog(
                    context: ctx,
                    builder: (context) => const SleepTimerDialog(),
                  );
                }
              },
            ),
          );

          // 7. Lofi Mode (Player specific)
          verticalOptions.add(
            ValueListenableBuilder<bool>(
              valueListenable: ref.watch(audioHandlerProvider).isLofiModeNotifier,
              builder: (context, isLofi, _) {
                return _buildVerticalItem(
                  context,
                  icon: CupertinoIcons.wand_stars,
                  title: 'Lofi Mode',
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: CupertinoSwitch(
                      value: isLofi,
                      onChanged: (val) {
                        HapticFeedback.lightImpact();
                        ref.read(audioHandlerProvider).toggleLofiMode();
                      },
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                    ),
                  ),
                  onTap: () {
                    ref.read(audioHandlerProvider).toggleLofiMode();
                  },
                );
              },
            ),
          );
        }

        // 8. Remove from History
        if (fromHistory) {
          verticalOptions.add(
            _buildVerticalItem(
              context,
              icon: CupertinoIcons.trash,
              title: 'Remove from history',
              iconColor: Colors.red,
              onTap: () {
                onClose?.call();
                if (result.videoId != null) {
                  storage.removeFromHistory(result.videoId!);
                  final ctx = navigatorKey.currentContext;
                  if (ctx != null) {
                    showGlassSnackBar(ctx, 'Removed from history');
                  }
                }
              },
            ),
          );
        }

        return SizedBox(
          width: 270,
          child: GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Song Info Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 40,
                                        height: 40,
                                        color: isDark ? Colors.grey[900] : Colors.grey[300],
                                        child: Icon(
                                          CupertinoIcons.music_note,
                                          color: theme.colorScheme.onSurface,
                                          size: 18,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 40,
                                  height: 40,
                                  color: isDark ? Colors.grey[900] : Colors.grey[300],
                                  child: Icon(
                                    CupertinoIcons.music_note,
                                    color: theme.colorScheme.onSurface,
                                    size: 18,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                result.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.displayArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    height: 0.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.12 : 0.20),
                  ),

                  // Quick Action Horizontal Row
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        // Download Column
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              onClose?.call();
                              final downloadService = DownloadService();
                              final ctx = navigatorKey.currentContext;
                              if (result.videoId != null) {
                                  if (storage.isDownloaded(result.videoId!)) {
                                    await downloadService.deleteDownload(result.videoId!);
                                    if (ctx != null && ctx.mounted) {
                                      showGlassSnackBar(ctx, 'Removed from downloads');
                                    }
                                  } else {
                                    if (ctx != null) {
                                      showGlassSnackBar(ctx, 'Downloading...');
                                    }

                                    final success = await ref
                                        .read(downloadProvider.notifier)
                                        .startDownload(result);

                                    final ctxAfter = navigatorKey.currentContext;
                                    if (ctxAfter != null && ctxAfter.mounted) {
                                      if (success) {
                                        showGlassSnackBar(ctxAfter, 'Download complete');
                                      } else {
                                        showGlassSnackBar(
                                          ctxAfter,
                                          'Download failed - Please try again',
                                        );
                                      }
                                    }
                                  }
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isDownloaded
                                        ? CupertinoIcons.checkmark_circle_fill
                                        : CupertinoIcons.arrow_down_circle,
                                    color: isDownloaded ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isDownloaded ? 'Remove' : 'Download',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Favorite Column
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                onClose?.call();
                                storage.toggleFavorite(result);
                                final ctx = navigatorKey.currentContext;
                                if (ctx != null) {
                                  showGlassSnackBar(
                                    ctx,
                                    isFav ? 'Removed from favorites' : 'Added to favorites',
                                  );
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isFav
                                        ? CupertinoIcons.star_fill
                                        : CupertinoIcons.star,
                                    color: isFav ? Colors.orange : theme.colorScheme.onSurface,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isFav ? 'Unfavorite' : 'Favorite',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Share Column
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                onClose?.call();
                                if (result.videoId != null) {
                                  Share.share('https://youtube.com/watch?v=${result.videoId}');
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.share,
                                    color: theme.colorScheme.onSurface,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Divider
                  Container(
                    height: 0.5,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: isDark ? 0.12 : 0.20),
                  ),

                  // Vertical options
                  Column(
                    children: [
                      for (int i = 0; i < verticalOptions.length; i++) ...[
                        verticalOptions[i],
                        if (i < verticalOptions.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 44),
                            child: Container(
                              height: 0.5,
                              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
        child: Row(
          children: [
            Icon(icon, color: effectiveIconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

class _CustomPopupMenuContent extends PopupMenuEntry<void> {
  final Widget child;
  const _CustomPopupMenuContent({required this.child});

  @override
  double get height => 0;

  @override
  bool represents(void value) => false;

  @override
  State<_CustomPopupMenuContent> createState() => _CustomPopupMenuContentState();
}

class _CustomPopupMenuContentState extends State<_CustomPopupMenuContent> {
  @override
  Widget build(BuildContext context) => widget.child;
}
