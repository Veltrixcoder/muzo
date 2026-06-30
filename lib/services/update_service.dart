import 'dart:ui';
import 'package:muzo/services/abi_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/widgets/glass_container.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';


class UpdateService {
  // Current app version - Update this when releasing a new version
  static const String currentAppVersion = '4.1';

  static const String _repoOwner = 'Shashwat-CODING';
  static const String _repoName = 'Muzo';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String latestVersion = data['tag_name'] ?? '';
        final String htmlUrl = data['html_url'] ?? '';

        if (_isNewerVersion(latestVersion, currentAppVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, htmlUrl, latestVersion);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      debugPrint('Update Check: Remote Version: "$latest" vs Local Version: "$current"');
      
      // Remove everything except numbers and dots to ensure clean comparison
      final latestClean = latest.replaceAll(RegExp(r'[^0-9.]'), '');
      final currentClean = current.replaceAll(RegExp(r'[^0-9.]'), '');

      debugPrint('Cleaned Versions: Remote: "$latestClean" vs Local: "$currentClean"');

      if (latestClean == currentClean) return false;

      List<String> latestParts = latestClean.split('.');
      List<String> currentParts = currentClean.split('.');

      int maxLength = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        int l = i < latestParts.length ? int.tryParse(latestParts[i]) ?? 0 : 0;
        int c = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;

        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      debugPrint('Error comparing versions: $e');
    }
    return false;
  }

  void _showUpdateDialog(BuildContext context, String version, String url, String tag) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -1.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack));

        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: anim1,
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.system_update_alt_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                'Update Available',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Version $version',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'A new version of Muzo is available. Update now for the latest features and improvements.',
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
                              onPressed: () => Navigator.pop(context),
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
                                'Later',
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
                                colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _downloadApk(tag, url);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                              child: const Text(
                                'Download',
                                style: TextStyle(
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
      },
    );
  }

  /// Returns the APK filename matching the current device ABI.
  /// Returns null on web or unrecognised platforms.
  String? _apkFilename() => detectApkFilename();

  Future<void> _downloadApk(String tag, String fallbackUrl) async {
    final filename = _apkFilename();
    final Uri uri;
    if (filename != null) {
      // Direct asset download URL from the GitHub release
      uri = Uri.parse(
        'https://github.com/$_repoOwner/$_repoName/releases/download/$tag/$filename',
      );
    } else {
      // Non-Android platform — open the release page
      uri = Uri.parse(fallbackUrl);
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $uri');
    }
  }
}
