import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:muzo/widgets/glass_container.dart';

enum StartupPopupType {
  spotify,
  discord,
  telegram,
  download,
  starRepo,
}

class StartupPopupDialog extends StatefulWidget {
  final StartupPopupType type;

  const StartupPopupDialog({
    super.key,
    required this.type,
  });

  @override
  State<StartupPopupDialog> createState() => _StartupPopupDialogState();
}

class _StartupPopupDialogState extends State<StartupPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    final List<Color> gradientColors;

    switch (widget.type) {
      case StartupPopupType.spotify:
        title = 'Spotify Import';
        description =
            'Easily bring your favorite Spotify playlists into Muzo. Head to the Library tab and paste any public playlist link to get started!';
        url = null;
        brandColor = const Color(0xFF1DB954);
        gradientColors = [const Color(0xFF1DB954), const Color(0xFF1ED760)];
        actionText = 'Awesome!';
        ignoreText = 'Dismiss';
        iconWidget = Image.asset(
          'assets/Spotify.png',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) => const Icon(
            CupertinoIcons.music_note_2,
            color: Colors.white,
            size: 24,
          ),
        );

      case StartupPopupType.discord:
        title = 'Join Our Discord';
        description =
            'Be part of a growing community — share feedback, get instant support, vote on features, and chat with Muzo users around the world.';
        url = 'https://discord.gg/6JFEV2Bqq';
        brandColor = const Color(0xFF5865F2);
        gradientColors = [const Color(0xFF5865F2), const Color(0xFF7289DA)];
        actionText = 'Join Discord';
        ignoreText = 'Not Now';
        iconWidget = const Icon(
          CupertinoIcons.bubble_left_bubble_right_fill,
          color: Colors.white,
          size: 24,
        );

      case StartupPopupType.telegram:
        title = 'Join Telegram';
        description =
            'Get the latest Muzo updates the moment they drop, request features directly, and stay connected with our active Telegram community.';
        url = 'https://t.me/muzoapp';
        brandColor = const Color(0xFF24A1DE);
        gradientColors = [const Color(0xFF0088CC), const Color(0xFF24A1DE)];
        actionText = 'Join Channel';
        ignoreText = 'Not Now';
        iconWidget = const Icon(
          CupertinoIcons.paperplane_fill,
          color: Colors.white,
          size: 24,
        );

      case StartupPopupType.download:
        title = 'Offline Downloads';
        description =
            'Save any song for offline listening! Tap the ⋯ menu on any track and choose Download. Your music is always with you, even without internet.';
        url = null;
        brandColor = theme.colorScheme.primary;
        gradientColors = [theme.colorScheme.primary, theme.colorScheme.secondary];
        actionText = 'Got it!';
        ignoreText = 'Dismiss';
        iconWidget = const Icon(
          CupertinoIcons.arrow_down_circle_fill,
          color: Colors.white,
          size: 24,
        );

      case StartupPopupType.starRepo:
        title = 'Loving Muzo? ⭐';
        description =
            'If Muzo has made your music experience better, consider giving it a star on GitHub. It helps a ton and motivates further development!';
        url = 'https://github.com/Shashwat-CODING/Muzo';
        brandColor = const Color(0xFFFFBB00);
        gradientColors = [const Color(0xFFFF8C00), const Color(0xFFFFBB00)];
        actionText = 'Take me there';
        ignoreText = 'Ignore';
        iconWidget = const Icon(
          CupertinoIcons.star_fill,
          color: Colors.white,
          size: 24,
        );
    }

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Dialog(
          alignment: Alignment.topCenter,
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          elevation: 0,
          child: GlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand icon bubble with glow
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: brandColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: iconWidget,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              height: 1.35,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Pill buttons row
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(
                            ignoreText,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () async {
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
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          child: Text(
                            actionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
