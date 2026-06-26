import 'package:muzo/screens/profile_screen.dart';
import 'package:muzo/screens/user_tracks_screen.dart';
import 'package:muzo/screens/about_screen.dart';
import 'package:muzo/screens/auth_screen.dart';
import 'package:muzo/services/auth_service.dart';
import 'package:muzo/widgets/app_alert_dialog.dart';
import 'package:muzo/screens/search_screen.dart';
import 'package:muzo/widgets/glass_menu_content.dart';
import 'package:muzo/widgets/fade_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/providers/navigation_provider.dart';
import 'package:muzo/screens/library_screen.dart';
import 'package:muzo/screens/community_screen.dart';
import 'package:muzo/models/muzo_item.dart';
import 'package:muzo/models/user_data.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:muzo/services/update_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:muzo/utils/page_routes.dart';
import 'package:muzo/screens/playlist_details_screen.dart';
import 'package:muzo/screens/settings_screen.dart';
import 'package:muzo/providers/player_provider.dart';
import 'package:muzo/widgets/quick_picks_section.dart';
import 'package:muzo/widgets/top_on_muzo_section.dart';
import 'package:muzo/providers/explore_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storage = ref.read(storageServiceProvider);
      storage.refreshAll(silent: true);
      storage.fetchAndCacheUserAvatar();
      UpdateService().checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: FadeIndexedStack(
          index: selectedIndex,
          children: [
            _buildHomeTab(context, ref),
            const SearchScreen(),
            const LibraryScreen(),
            const SettingsScreen(),
            const CommunityScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, WidgetRef ref) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Theme.of(context).colorScheme.onSurface,
        backgroundColor: (Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardColor
            : Colors.white),
        onRefresh: () async {
          ref.invalidate(topOnMuzoProvider);
          await ref.read(storageServiceProvider).refreshAll();
        },
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(context, ref)),

            // Quick Picks
            const SliverToBoxAdapter(child: QuickPicksSection()),

            // Top on Muzo (Trending)
            const SliverToBoxAdapter(child: TopOnMuzoSection()),

            // Recently Played
            _buildRecentlyPlayedSection(context, ref),

            // Favourites
            _buildFavoritesSection(context, ref),

            // Your Playlists
            _buildYourPlaylistsSection(context, ref),

            // Bottom padding for mini player + nav bar
            const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    final username = storage.username ?? 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo + Muzo branding
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/logo.png',
                  height: 32,
                  width: 32,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Muzo',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),

          // Avatar with popup menu
          PopupMenuButton<String>(
            onOpened: () => HapticFeedback.lightImpact(),
            offset: const Offset(0, 54),
            color: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (BuildContext context) {
              final authService = ref.read(authServiceProvider);
              final isAuthenticated = authService.isAuthenticated;

              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  child: GlassMenuContent(
                    width: 260,
                    children: [
                      // Profile Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                                  width: 1.0,
                                ),
                              ),
                              child: ClipOval(
                                child: Builder(
                                  builder: (context) {
                                    final avatarUrl = storage.avatarUrl;
                                    final cachedSvg = storage.getUserAvatar();
                                    final isSvg = avatarUrl == null ||
                                        avatarUrl.contains('.svg') ||
                                        avatarUrl.contains('dicebear');
                                    if (isSvg && cachedSvg != null) {
                                      return SvgPicture.string(cachedSvg,
                                          height: 38, width: 38, fit: BoxFit.cover);
                                    }
                                    if (avatarUrl != null && !isSvg) {
                                      return CachedNetworkImage(
                                        imageUrl: avatarUrl,
                                        height: 38,
                                        width: 38,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Icon(
                                            FluentIcons.person_24_filled,
                                            size: 22,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                      );
                                    }
                                    return SvgPicture.network(
                                      'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                                      height: 38,
                                      width: 38,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    username,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isAuthenticated
                                              ? const Color(0xFF34C759)
                                              : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isAuthenticated ? 'Cloud Synced' : 'Offline / Guest',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.5),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 6),

                      // Menu Options
                      _ProfileMenuItem(
                        icon: FluentIcons.person_24_regular,
                        title: 'Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const ProfileScreen()),
                          );
                        },
                      ),
                      _ProfileMenuItem(
                        icon: FluentIcons.cloud_arrow_up_24_regular,
                        title: 'My Uploads',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const UserTracksScreen()),
                          );
                        },
                      ),
                      _ProfileMenuItem(
                        icon: FluentIcons.settings_24_regular,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const SettingsScreen()),
                          );
                        },
                      ),
                      _ProfileMenuItem(
                        icon: FluentIcons.info_24_regular,
                        title: 'About Muzo',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            SlidePageRoute(page: const AboutScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Divider(
                        height: 1,
                        thickness: 0.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 4),
                      if (isAuthenticated)
                        _ProfileMenuItem(
                          icon: FluentIcons.sign_out_24_regular,
                          title: 'Logout',
                          color: Colors.redAccent,
                          onTap: () {
                            Navigator.pop(context);
                            showAppAlertDialog(
                              context: context,
                              title: 'Logout?',
                              content: const Text('Are you sure you want to log out of your account?'),
                              actionsBuilder: (dialogContext) => [
                                TextButton(
                                  child: const Text('Cancel'),
                                  onPressed: () => Navigator.pop(dialogContext),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);
                                    await ref.read(authServiceProvider).logout();
                                  },
                                  child: const Text('Logout', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            );
                          },
                        )
                      else
                        _ProfileMenuItem(
                          icon: Icons.login_rounded,
                          title: 'Login / Sign Up',
                          color: Theme.of(context).colorScheme.primary,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              SlidePageRoute(page: const AuthScreen()),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ];
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ValueListenableBuilder(
                  valueListenable: storage.userAvatarListenable,
                  builder: (context, box, _) {
                    final avatarUrl = storage.avatarUrl;
                    final cachedSvg = storage.getUserAvatar();
                    final isSvg = avatarUrl == null ||
                        avatarUrl.contains('.svg') ||
                        avatarUrl.contains('dicebear');
  
                    if (isSvg && cachedSvg != null) {
                      return SvgPicture.string(cachedSvg,
                          height: 36, width: 36, fit: BoxFit.cover);
                    }
                    if (avatarUrl != null) {
                      if (isSvg) {
                        return SvgPicture.network(
                          avatarUrl,
                          height: 36,
                          width: 36,
                          fit: BoxFit.cover,
                          placeholderBuilder: (context) => Container(
                              padding: const EdgeInsets.all(10),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2)),
                        );
                      } else {
                        return CachedNetworkImage(
                          imageUrl: avatarUrl,
                          height: 36,
                          width: 36,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                              padding: const EdgeInsets.all(10),
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2)),
                          errorWidget: (context, url, error) =>
                              Icon(FluentIcons.person_24_filled, size: 20),
                        );
                      }
                    }
                    return SvgPicture.network(
                      'https://api.dicebear.com/9.x/rings/svg?seed=$username',
                      height: 36,
                      width: 36,
                      fit: BoxFit.cover,
                      placeholderBuilder: (context) => Container(
                          padding: const EdgeInsets.all(10),
                          child: const CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
      ),
    );
  }

  // ── Horizontal music card ──────────────────────────────────────────────────

  /// A square-ish card (width ~130) with a thumbnail and a single-line title.
  Widget _buildMusicCard({
    required BuildContext context,
    required String title,
    required String? imageUrl,
    required VoidCallback onTap,
  }) {
    const double cardWidth = 152;
    const double borderRadius = 8.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholderTile(context),
                        )
                      : _placeholderTile(context),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderTile(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        FluentIcons.music_note_2_24_filled,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  // ── Recently Played ────────────────────────────────────────────────────────

  Widget _buildRecentlyPlayedSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);

    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<MuzoItem>>(
        valueListenable: storage.historyListenable,
        builder: (context, history, _) {
          // Deduplicate and filter to square-thumbnail items only
          final uniqueItems = <String, MuzoItem>{};
          for (final item in history) {
            if (item.videoId == null) continue;
            if (uniqueItems.containsKey(item.videoId)) continue;
            final thumb = item.thumbnails.lastOrNull;
            if (thumb == null) continue;
            bool isSquare = true;
            if (thumb.width > 0 && thumb.height > 0) {
              if (thumb.width != thumb.height) isSquare = false;
            } else {
              if (thumb.url.contains('i.ytimg.com')) isSquare = false;
            }
            if (isSquare) uniqueItems[item.videoId!] = item;
          }

          if (uniqueItems.isEmpty) return const SizedBox.shrink();

          final items = uniqueItems.values.toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Recently Played'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final imageUrl = item.thumbnails.lastOrNull?.url;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: item.title,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(audioHandlerProvider).playVideo(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Favourites ─────────────────────────────────────────────────────────────

  Widget _buildFavoritesSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<MuzoItem>>(
        valueListenable: storage.favoritesListenable,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Favourites'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    final imageUrl = item.thumbnails.isNotEmpty
                        ? item.thumbnails.last.url
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: item.title,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          ref.read(audioHandlerProvider).playVideo(item);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Your Playlists ─────────────────────────────────────────────────────────

  Widget _buildYourPlaylistsSection(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(storageServiceProvider);
    return SliverToBoxAdapter(
      child: ValueListenableBuilder<List<Playlist>>(
        valueListenable: storage.playlistsListenable,
        builder: (context, playlists, _) {
          if (playlists.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, 'Your Playlists'),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final firstSong = playlist.songs.isNotEmpty
                        ? playlist.songs.first
                        : null;
                    final imageUrl =
                        firstSong?.thumbnails.isNotEmpty == true
                            ? firstSong!.thumbnails.last.url
                            : null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _buildMusicCard(
                        context: context,
                        title: playlist.name,
                        imageUrl: imageUrl,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            SlidePageRoute(
                              page: PlaylistDetailsScreen(
                                  playlistName: playlist.name),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final effectiveColor = color ?? cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(icon, color: effectiveColor.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: effectiveColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
