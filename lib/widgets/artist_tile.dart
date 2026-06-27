import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:muzo/services/muzo_api_service.dart'; // Ensure valid import
import 'package:muzo/widgets/library_tile.dart';
import 'package:muzo/screens/artist_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/storage_service.dart';
import 'package:muzo/utils/page_routes.dart';

class ArtistTile extends ConsumerStatefulWidget {
  final String artistName;
  final String artistId;
  final String? avatarUrl;

  const ArtistTile({
    super.key,
    required this.artistName,
    required this.artistId,
    this.avatarUrl,
  });

  @override
  ConsumerState<ArtistTile> createState() => _ArtistTileState();
}

class _ArtistTileState extends ConsumerState<ArtistTile> {
  late final _muzoService = ref.read(muzoApiServiceProvider);
  String? _avatarUrl;
  late String _navChannelId;

  @override
  void initState() {
    super.initState();
    _navChannelId = widget.artistId;
    _avatarUrl = widget.avatarUrl;
    _fetchAvatar();
  }

  @override
  void didUpdateWidget(ArtistTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artistId != widget.artistId ||
        oldWidget.artistName != widget.artistName) {
      _navChannelId = widget.artistId;
      _avatarUrl = widget.avatarUrl;
      _fetchAvatar();
    }
  }

  Future<void> _fetchAvatar() async {
    final storage = ref.read(storageServiceProvider);

    // Cache is keyed by artistId
    final cacheKey = widget.artistId.isNotEmpty ? widget.artistId : widget.artistName;
    final cachedUrl = storage.getArtistImage(cacheKey);
    if (cachedUrl != null) {
      if (mounted) {
        setState(() {
          _avatarUrl = cachedUrl;
        });
      }
    }

    // If we have both ID and Image, no need to fetch
    if (_avatarUrl != null && _navChannelId.isNotEmpty) return;

    if (mounted) {
      try {
        if (_navChannelId.isNotEmpty) {
          final details = await _muzoService.getArtistDetails(_navChannelId);
          if (mounted && details != null && details.artistAvatar.isNotEmpty) {
            final highResUrl = details.artistAvatar.replaceAll(
              RegExp(r'=[sw]\d+(-h\d+)?'),
              '=s800',
            );
            setState(() {
              _avatarUrl = highResUrl;
              storage.setArtistImage(_navChannelId, highResUrl);
            });
          }
        } else {
          // Fallback: search by artistName
          final _apiService = ref.read(muzoApiServiceProvider);
          final response = await _apiService.search(
            widget.artistName,
            filter: 'artists',
          );
          if (mounted && response.results.isNotEmpty) {
            final result = response.results.first;
            final newChannelId = result.browseId ?? '';
            setState(() {
              if (result.thumbnails.isNotEmpty) {
                final highResUrl = result.thumbnails.last.url.replaceAll(
                  RegExp(r'=[sw]\d+(-h\d+)?'),
                  '=s800',
                );
                _avatarUrl = highResUrl;
                final cacheKey = newChannelId.isNotEmpty ? newChannelId : widget.artistName;
                storage.setArtistImage(cacheKey, highResUrl);
              }
              if (_navChannelId.isEmpty && newChannelId.isNotEmpty) {
                _navChannelId = newChannelId;
              }
            });
          }
        }
      } catch (e) {
        // Ignore error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LibraryTile(
      title: widget.artistName,
      subtitle: 'Artist',
      imageUrl: _avatarUrl,
      isRound: true,
      placeholderIcon: FluentIcons.person_24_regular,
      onTap: () {
        final id = _navChannelId.isNotEmpty ? _navChannelId : widget.artistId;
        final nav = Navigator.of(context);
        if (id.isNotEmpty) {
          nav.push(
            SlidePageRoute(
              page: ArtistScreen(
                browseId: id,
                artistName: widget.artistName,
                thumbnailUrl: _avatarUrl,
              ),
            ),
          );
        }
      },
    );
  }
}
