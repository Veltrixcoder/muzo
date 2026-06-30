import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muzo/services/muzo_api_service.dart';
import 'package:muzo/models/muzo_item.dart';

/// A single syllable/word within a karaoke lyric line
class KaraokeSyllable {
  final Duration time;
  final Duration duration;
  final String text;
  const KaraokeSyllable({required this.time, required this.duration, required this.text});
}

/// A complete lyric line with optional word-level timing for karaoke
class KaraokeLine {
  final Duration lineStart;
  final String fullText;
  final List<KaraokeSyllable> syllables;
  const KaraokeLine({required this.lineStart, required this.fullText, required this.syllables});
}

class Lyrics {
  final int id;
  final String name;
  final String trackName;
  final String artistName;
  final String albumName;
  final int duration;
  final bool instrumental;
  final String plainLyrics;
  final String syncedLyrics;
  /// Non-null when Atomix returns type:Word — enables karaoke word highlighting
  final List<KaraokeLine>? karaokeLines;

  Lyrics({
    required this.id,
    required this.name,
    required this.trackName,
    required this.artistName,
    required this.albumName,
    required this.duration,
    required this.instrumental,
    required this.plainLyrics,
    required this.syncedLyrics,
    this.karaokeLines,
  });

  factory Lyrics.fromJson(Map<String, dynamic> json) {
    return Lyrics(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      trackName: json['trackName'] ?? '',
      artistName: json['artistName'] ?? '',
      albumName: json['albumName'] ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      instrumental: json['instrumental'] ?? false,
      plainLyrics: json['plainLyrics'] ?? '',
      syncedLyrics: json['syncedLyrics'] ?? '',
    );
  }
}

final lyricsServiceProvider = Provider((ref) => LyricsService(ref));

class LyricsService {
  final Ref ref;
  LyricsService(this.ref);

  Future<Lyrics?> fetchLyrics(
    String trackName,
    String artistName,
    int duration, {
    String? videoId,
  }) async {
    debugPrint('LyricsService: fetchLyrics called with trackName="$trackName", artistName="$artistName", videoId="$videoId"');
    
    var queryArtist = artistName;
    if (!queryArtist.contains(',') && videoId != null && videoId.isNotEmpty) {
      try {
        final searchRes = await ref.read(muzoApiServiceProvider).search(trackName, filter: 'songs');
        final matchingSong = searchRes.results.cast<MuzoItem?>().firstWhere(
          (s) => s?.videoId == videoId,
          orElse: () => null,
        );
        if (matchingSong != null && matchingSong.artists != null && matchingSong.artists!.length > 1) {
          final fullArtist = matchingSong.artists!.map((a) => a.name).join(', ');
          debugPrint('LyricsService: Resolved multiple artists from search API: "$fullArtist"');
          queryArtist = fullArtist;
        }
      } catch (e) {
        debugPrint('LyricsService: Failed to resolve multiple artists: $e');
      }
    }

    final cleanTrack = _cleanTrack(trackName);
    final cleanArtist = _cleanArtist(queryArtist);
    debugPrint('LyricsService: cleaned: cleanTrack="$cleanTrack", cleanArtist="$cleanArtist"');

    try {
      final idPart = (videoId == null || videoId.isEmpty) ? 'unknown' : videoId;
      final nameEncoded = _customUrlEncode(cleanTrack);
      final artistEncoded = _customUrlEncode(cleanArtist);
      final urlString = 'https://allnewuser-lyrics.hf.space/api/lyrics/$idPart?name=$nameEncoded&artist=$artistEncoded';
      final uri = Uri.parse(urlString);

      debugPrint('LyricsService: Requesting unified lyrics: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('LyricsService: Unified response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String source = data['source'] ?? '';

        // Case 1: lrclib source or contains plainLyrics/syncedLyrics
        if (source == 'lrclib' || data['plainLyrics'] != null || data['syncedLyrics'] != null) {
          if (data['plainLyrics'] != null || data['syncedLyrics'] != null) {
            debugPrint('LyricsService: Found lyrics via LRCLIB source');
            return Lyrics.fromJson(data);
          }
        } 
        // Case 2: atomix/apple/line-based structures (lyrics != null)
        else if (data['lyrics'] != null) {
          final String responseType = data['type'] ?? 'Line';
          final List<dynamic> lines = data['lyrics'];
          
          final StringBuffer syncedBuffer = StringBuffer();
          final StringBuffer plainBuffer = StringBuffer();
          final List<KaraokeLine>? karaokeLines = responseType == 'Word' ? [] : null;

          for (var line in lines) {
            final int rawMs = line['time'] ?? 0;
            final String text = (line['text'] as String? ?? '').trim();
            if (text.isEmpty) continue;

            final lineDuration = Duration(milliseconds: rawMs);
            final minutes = lineDuration.inMinutes.toString().padLeft(2, '0');
            final seconds = (lineDuration.inSeconds % 60).toString().padLeft(2, '0');
            final hundredths = ((lineDuration.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');

            syncedBuffer.writeln('[$minutes:$seconds.$hundredths] $text');
            plainBuffer.writeln(text);

            // Parse syllable-level data for Word-type
            if (responseType == 'Word') {
              final List<dynamic> syllabi = (line['syllabus'] as List<dynamic>?) ?? [];
              final List<KaraokeSyllable> syllables = syllabi.map((s) {
                return KaraokeSyllable(
                  time: Duration(milliseconds: (s['time'] as num?)?.toInt() ?? rawMs),
                  duration: Duration(milliseconds: (s['duration'] as num?)?.toInt() ?? 300),
                  text: s['text'] as String? ?? '',
                );
              }).toList();
              
              karaokeLines!.add(KaraokeLine(
                lineStart: Duration(milliseconds: rawMs),
                fullText: text,
                syllables: syllables.isEmpty
                    ? [KaraokeSyllable(time: Duration(milliseconds: rawMs), duration: const Duration(milliseconds: 2000), text: text)]
                    : syllables,
              ));
            }
          }

          if (plainBuffer.isNotEmpty) {
             debugPrint('LyricsService: Found lyrics via $source source (type: $responseType)');
             return Lyrics(
               id: 0,
               name: cleanTrack,
               trackName: cleanTrack,
               artistName: cleanArtist,
               albumName: data['albumName'] ?? '',
               duration: duration,
               instrumental: data['instrumental'] ?? false,
               plainLyrics: plainBuffer.toString(),
               syncedLyrics: syncedBuffer.toString(),
               karaokeLines: karaokeLines,
             );
          }
        }
      }
    } catch (e) {
      debugPrint('LyricsService: Error fetching unified lyrics: $e');
    }
    return null;
  }

  String _cleanTrack(String text) {
    debugPrint('LyricsService: Cleaning track: "$text"');
    if (text.isEmpty) return text;

    try {
      // Remove common patterns
      var clean = text;

      // Remove (Official Video), [Official Audio], etc.
      // Using standard Dart RegExp constructor for case insensitivity
      final videoPattern = RegExp(
        r'\s*[\(\[](official|video|audio|lyrics|lyric|hd|hq|4k|mv|music video|full audio)[\)\]]',
        caseSensitive: false,
      );
      clean = clean.replaceAll(videoPattern, '');

      // Remove "ft.", "feat."
      final featPattern = RegExp(
        r'\s+(ft\.|feat\.|featuring)\s+',
        caseSensitive: false,
      );
      if (featPattern.hasMatch(clean)) {
        clean = clean.split(featPattern).first;
      }

      // Remove " - Topic" from artist strings
      clean = clean.replaceAll(' - Topic', '');

      final result = clean.trim();
      debugPrint('LyricsService: Cleaned track: "$result"');
      return result;
    } catch (e) {
      debugPrint('LyricsService: Error cleaning track "$text": $e');
      return text; // Return original if cleaning fails
    }
  }

  String _cleanArtist(String text) {
    debugPrint('LyricsService: Cleaning artist: "$text"');
    if (text.isEmpty) return text;

    try {
      var clean = text.replaceAll(' - Topic', '');

      // Split by common separators: ",", "&", "/", "and", "feat.", "ft.", "featuring"
      final separatorPattern = RegExp(
        r'(?:\s*,\s*|\s*&\s*|\s*/\s*|\s+(?:and|feat\.?|ft\.?|featuring)\s+)',
        caseSensitive: false,
      );
      
      final parts = clean.split(separatorPattern);
      final cleanParts = parts
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      final result = cleanParts.isNotEmpty ? cleanParts.join(', ') : clean.trim();
      debugPrint('LyricsService: Cleaned artist: "$result"');
      return result;
    } catch (e) {
      debugPrint('LyricsService: Error cleaning artist "$text": $e');
      return text;
    }
  }

  String _customUrlEncode(String input) {
    // Uri.encodeComponent encodes spaces as %20.
    // It also encodes commas as %2C. We want commas to remain unencoded.
    return Uri.encodeComponent(input).replaceAll('%2C', ',');
  }
}
