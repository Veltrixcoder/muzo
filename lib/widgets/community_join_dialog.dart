import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:muzo/widgets/glass_container.dart';

enum StartupPopupType {
  spotify,
  discord,
  telegram,
}

class StartupPopupDialog extends StatelessWidget {
  final StartupPopupType type;

  const StartupPopupDialog({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String title;
    final String description;
    final String? url;
    final Color brandColor;
    final Widget iconWidget;
    final String actionText;
    final String ignoreText;

    switch (type) {
      case StartupPopupType.spotify:
        title = 'Spotify Import';
        description = 'Easily bring your favorite Spotify playlists to Muzo. Head over to the Library to get started!';
        url = null; // No url to open, just dismisses
        brandColor = const Color(0xFF1DB954); // Spotify Green
        actionText = 'Awesome';
        ignoreText = 'Dismiss';
        iconWidget = Image.asset(
          'assets/Spotify.png',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) => Icon(
            CupertinoIcons.music_note_2,
            color: const Color(0xFF1DB954),
            size: 24,
          ),
        );
        break;
      case StartupPopupType.discord:
        title = 'Join Discord';
        description = 'Connect with other users, request features, and get instant support.';
        url = 'https://discord.gg/6JFEV2Bqq';
        brandColor = const Color(0xFF5865F2); // Discord Blurple
        actionText = 'Join';
        ignoreText = 'Ignore';
        iconWidget = Icon(
          CupertinoIcons.bubble_left_bubble_right_fill,
          color: brandColor,
          size: 24,
        );
        break;
      case StartupPopupType.telegram:
        title = 'Join Telegram';
        description = 'Get the latest updates, request features, and chat with Muzo community.';
        url = 'https://t.me/muzoapp';
        brandColor = const Color(0xFF24A1DE); // Telegram Blue
        actionText = 'Join';
        ignoreText = 'Ignore';
        iconWidget = Icon(
          CupertinoIcons.paperplane_fill,
          color: brandColor,
          size: 24,
        );
        break;
    }

    final ignoreBg = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06);
    final ignoreFg = theme.colorScheme.onSurface;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: brandColor.withValues(alpha: 0.24),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: iconWidget,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.35,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 20),
            // Actions
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: Material(
                      color: brandColor,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () async {
                          if (url != null) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        },
                        child: Center(
                          child: Text(
                            actionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: Material(
                      color: ignoreBg,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(false);
                        },
                        child: Center(
                          child: Text(
                            ignoreText,
                            style: TextStyle(
                              color: ignoreFg,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
