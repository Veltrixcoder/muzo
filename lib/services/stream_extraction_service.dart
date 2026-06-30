import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'fastytservice.dart';

class StreamExtractionService {
  static final Map<String, bool> isSaavnCache = {};

  /// Shared Dio instance — reuses TCP connections across calls (avoids 200–500ms
  /// connection setup per song play).
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Connection': 'keep-alive',
      },
    ),
  );

  static String _cleanArtist(String artist) {
    String cleaned = artist;
    
    // Remove " - Topic" suffix common in YouTube uploads
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '');

    // Remove featuring info from artist name
    final featPattern = RegExp(
      r'\s*\b(?:feat\.?|ft\.?|featuring)\b.*$',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(featPattern, '');

    // Take only the first artist if there are separators like "," or "&" or "and"
    final primaryArtistPattern = RegExp(r'^([^,&]+)');
    final match = primaryArtistPattern.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!;
    }

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : artist;
  }

  static String _cleanTitle(String title, String artist) {
    String cleaned = title;
    
    // 1. Remove content inside brackets/parentheses that contain music video noise
    final bracketNoise = RegExp(
      r'\s*[([][^\])]*(?:video|audio|lyric|lyrics|mv|hd|4k|live|remix|official|music)[^\])]*[\])]',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(bracketNoise, '');

    // 2. Remove standalone noise phrases
    final standaloneNoise = RegExp(
      r'\s*\b(?:official video|official audio|music video|lyric video|lyrics|official|mv)\b',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(standaloneNoise, '');

    // 3. Remove featuring info (e.g. feat. / ft. / featuring ...)
    final featPattern = RegExp(
      r'\s*\b(?:feat\.?|ft\.?|featuring)\b.*$',
      caseSensitive: false,
    );
    cleaned = cleaned.replaceAll(featPattern, '');

    // 4. Remove artist prefix/suffix separated by a dash "-" if the artist name is present
    if (artist.isNotEmpty) {
      final cleanedArtist = _cleanArtist(artist);
      if (cleaned.contains('-')) {
        final parts = cleaned.split('-');
        final firstPart = parts[0].trim();
        if (firstPart.toLowerCase() == cleanedArtist.toLowerCase() || 
            cleanedArtist.toLowerCase().contains(firstPart.toLowerCase()) ||
            firstPart.toLowerCase().contains(cleanedArtist.toLowerCase())) {
          cleaned = parts.skip(1).join('-').trim();
        } else {
          final lastPart = parts.last.trim();
          if (lastPart.toLowerCase() == cleanedArtist.toLowerCase() ||
              cleanedArtist.toLowerCase().contains(lastPart.toLowerCase()) ||
              lastPart.toLowerCase().contains(cleanedArtist.toLowerCase())) {
            cleaned = parts.take(parts.length - 1).join('-').trim();
          }
        }
      }
    }

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isNotEmpty ? cleaned : title;
  }

  static Future<String?> getSaavnStreamUrl(String title, String artist, {int? durationSeconds}) async {
    try {

      final cleanTitle = _cleanTitle(title, artist);
      final cleanArtist = _cleanArtist(artist);

      String? durationString;
      if (durationSeconds != null && durationSeconds > 0) {
        final minutes = durationSeconds ~/ 60;
        final seconds = durationSeconds % 60;
        durationString = "$minutes:${seconds.toString().padLeft(2, '0')}";
      }

      final queryParams = {
        'title': cleanTitle,
        'artist': cleanArtist,
        if (durationString != null) 'duration': durationString,
      };
      debugPrint('SaavnExtraction: Requesting stream for "$cleanTitle" by "$cleanArtist" (${durationString ?? "unknown"})');
      
      final response = await _dio.get<String>(
        'https://fast-saavn.vercel.app/',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => true,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final path = response.data!.trim();
        if (path.isNotEmpty && !path.toLowerCase().contains('error') && !path.toLowerCase().contains('fail')) {
          final fullUrl = 'https://aac.saavncdn.com/${path}_320.mp4';
          debugPrint('SaavnExtraction: Found stream - $fullUrl');
          return fullUrl;
        }
      }
      debugPrint('SaavnExtraction: Empty or error response from Saavn API');
    } catch (e) {
      debugPrint('SaavnExtraction Error: $e');
    }
    return null;
  }

  static Future<YtAudioQuality> _getAudioQuality() async {
    int qualityIndex = 0;
    try {
      final box = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
      qualityIndex = box.get('audioQuality', defaultValue: 0);
    } catch (e) {
      debugPrint('StreamExtraction: Error reading audio quality from Hive: $e');
    }
    if (qualityIndex == 0) return YtAudioQuality.high;
    if (qualityIndex == 2) return YtAudioQuality.low;
    return YtAudioQuality.auto;
  }

  /// Race Saavn and YouTube (FastYt) to find the fastest stream URL
  static Future<String?> _raceFastExtractions({
    required String videoId,
    required String? title,
    required String? artist,
    required int? durationSeconds,
    required YtAudioQuality quality,
  }) async {
    final completer = Completer<String?>();
    int completedCount = 0;
    const totalCount = 2;
    final stopwatch = Stopwatch()..start();

    debugPrint('StreamExtraction: Starting race [Saavn vs FastYt] for $videoId');

    void handleSuccess(String? url, bool isSaavn) {
      if (completer.isCompleted) return;
      final providerName = isSaavn ? "Saavn" : "FastYt";
      if (url != null) {
        isSaavnCache[videoId] = isSaavn;
        debugPrint('StreamExtraction: [Race Winner] $providerName won the race in ${stopwatch.elapsedMilliseconds}ms');
        completer.complete(url);
      } else {
        debugPrint('StreamExtraction: [Race Status] $providerName completed with no stream in ${stopwatch.elapsedMilliseconds}ms');
        completedCount++;
        if (completedCount >= totalCount) {
          debugPrint('StreamExtraction: [Race Over] Both Saavn and FastYt failed to resolve a stream in ${stopwatch.elapsedMilliseconds}ms');
          completer.complete(null);
        }
      }
    }

    // Task 1: Saavn Extraction
    if (title != null && artist != null) {
      debugPrint('StreamExtraction: [Saavn] Dispatching fetch for "$title" by "$artist"');
      getSaavnStreamUrl(title, artist, durationSeconds: durationSeconds).then((url) {
        handleSuccess(url, true);
      }).catchError((e) {
        debugPrint('StreamExtraction: [Saavn] Threw error: $e');
        handleSuccess(null, true);
      });
    } else {
      debugPrint('StreamExtraction: [Saavn] Skipping (missing title/artist)');
      completedCount++;
    }

    // Task 2: FastYt Extraction
    debugPrint('StreamExtraction: [FastYt] Dispatching fetch for videoId: $videoId');
    YtExtractorService.getStreamUrl(videoId, quality: quality).then((url) {
      handleSuccess(url, false);
    }).catchError((e) {
      debugPrint('StreamExtraction: [FastYt] Threw error: $e');
      handleSuccess(null, false);
    });

    return completer.future;
  }

  /// Extracts the best audio stream URL, checking Saavn and FastYt in parallel first.
  ///
  /// Set [forceFresh] to true to skip Saavn entirely (e.g. when recovering from a
  /// -1008 / resource-unavailable error — Saavn CDN URLs expire quickly).
  static Future<String?> getStreamUrl(
    String videoId, {
    String? title,
    String? artist,
    int? durationSeconds,
    bool forceFresh = false,
  }) async {
    final overallStopwatch = Stopwatch()..start();
    debugPrint('StreamExtraction: --- getStreamUrl started for $videoId (forceFresh=$forceFresh) ---');

    final quality = await _getAudioQuality();

    if (!forceFresh) {
      // 1. Race Saavn and FastYt
      final fastUrl = await _raceFastExtractions(
        videoId: videoId,
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
        quality: quality,
      );

      if (fastUrl != null) {
        final provider = isSaavnCache[videoId] == true ? 'Saavn' : 'FastYt';
        debugPrint('StreamExtraction: SUCCESS -> Using FAST EXTRACTION ($provider) in ${overallStopwatch.elapsedMilliseconds}ms');
        return fastUrl;
      }
      debugPrint('StreamExtraction: Fast extraction failed after ${overallStopwatch.elapsedMilliseconds}ms.');
    } else {
      debugPrint('StreamExtraction: forceFresh=true — skipping Saavn, going straight to FastYt...');
      // Try FastYt directly when force-fresh
      try {
        final fastYtUrl = await YtExtractorService.getStreamUrl(videoId, quality: quality);
        isSaavnCache[videoId] = false;
        debugPrint('StreamExtraction: SUCCESS -> Using FAST EXTRACTION (FastYt force-fresh) in ${overallStopwatch.elapsedMilliseconds}ms');
        return fastYtUrl;
      } catch (e) {
        debugPrint('StreamExtraction: [FastYt] Failed force-fresh fetch: $e');
      }
    }

    isSaavnCache[videoId] = false;
    debugPrint('StreamExtraction: FAILURE -> Could not extract stream URL via any source. Duration: ${overallStopwatch.elapsedMilliseconds}ms');
    return null;
  }
}
