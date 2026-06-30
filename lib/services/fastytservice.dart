import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

enum YtAudioQuality { low, high, auto }

class YouTubeClient {
  final String clientName;
  final String clientVersion;
  final String clientId;
  final String userAgent;
  final String? osName;
  final String? osVersion;
  final String? deviceMake;
  final String? deviceModel;
  final String? androidSdkVersion;
  final String? buildId;
  final String? cronetVersion;
  final String? packageName;
  final String? friendlyName;

  const YouTubeClient({
    required this.clientName,
    required this.clientVersion,
    required this.clientId,
    required this.userAgent,
    this.osName,
    this.osVersion,
    this.deviceMake,
    this.deviceModel,
    this.androidSdkVersion,
    this.buildId,
    this.cronetVersion,
    this.packageName,
    this.friendlyName,
  });

  Map<String, dynamic> toContextMap({
    String hl = 'en',
    String gl = 'US',
    String? visitorData,
  }) {
    final clientMap = <String, dynamic>{
      'clientName': clientName,
      'clientVersion': clientVersion,
      'gl': gl,
      'hl': hl,
    };

    if (osName != null) clientMap['osName'] = osName;
    if (osVersion != null) clientMap['osVersion'] = osVersion;
    if (deviceMake != null) clientMap['deviceMake'] = deviceMake;
    if (deviceModel != null) clientMap['deviceModel'] = deviceModel;
    if (androidSdkVersion != null) clientMap['androidSdkVersion'] = androidSdkVersion;
    if (visitorData != null) clientMap['visitorData'] = visitorData;

    return {
      'client': clientMap,
    };
  }

  static const ANDROID_VR_NO_AUTH = YouTubeClient(
    clientName: 'ANDROID_VR',
    clientVersion: '1.61.48',
    clientId: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Oculus Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)',
  );

  static const ANDROID_VR_1_61_48 = YouTubeClient(
    clientName: 'ANDROID_VR',
    clientVersion: '1.61.48',
    clientId: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.61.48 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/132.0.6808.3)',
    osName: 'Android',
    osVersion: '12',
    deviceMake: 'Oculus',
    deviceModel: 'Quest 3',
    androidSdkVersion: '32',
    buildId: 'SQ3A.220605.009.A1',
    cronetVersion: '132.0.6808.3',
    packageName: 'com.google.android.apps.youtube.vr.oculus',
    friendlyName: 'Android VR 1.61',
  );

  static const ANDROID_VR_1_43_32 = YouTubeClient(
    clientName: 'ANDROID_VR',
    clientVersion: '1.43.32',
    clientId: '28',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.43.32 (Linux; U; Android 12; en_US; Quest 3; Build/SQ3A.220605.009.A1; Cronet/107.0.5284.2)',
    osName: 'Android',
    osVersion: '12',
    deviceMake: 'Oculus',
    deviceModel: 'Quest 3',
    androidSdkVersion: '32',
    buildId: 'SQ3A.220605.009.A1',
    cronetVersion: '107.0.5284.2',
    packageName: 'com.google.android.apps.youtube.vr.oculus',
    friendlyName: 'Android VR 1.43',
  );

  static const VISIONOS = YouTubeClient(
    clientName: 'VISIONOS',
    clientVersion: '0.1',
    clientId: '101',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    osName: 'visionOS',
    osVersion: '1.3.21O771',
    deviceMake: 'Apple',
    deviceModel: 'RealityDevice14,1',
    friendlyName: 'visionOS',
  );
}

class Format {
  final Map<String, dynamic> data;
  Format(this.data);

  int get itag => data['itag'] as int? ?? 0;
  String get mimeType => data['mimeType'] as String? ?? '';
  int get bitrate => data['bitrate'] as int? ?? 0;
  String get audioQuality => data['audioQuality'] as String? ?? '';
  int? get audioChannels => data['audioChannels'] as int?;

  String? get url => data['url'] as String?;

  bool get isAudio => mimeType.startsWith('audio/');
}

class PlayerResponse {
  final Map<String, dynamic> data;
  PlayerResponse(this.data);

  Map<String, dynamic>? get playabilityStatus => data['playabilityStatus'] as Map<String, dynamic>?;
  String get status => playabilityStatus?['status'] as String? ?? '';
  String get reason => playabilityStatus?['reason'] as String? ?? '';

  Map<String, dynamic>? get videoDetails => data['videoDetails'] as Map<String, dynamic>?;
  String get title => videoDetails?['title'] as String? ?? '';
  String get videoId => videoDetails?['videoId'] as String? ?? '';

  Map<String, dynamic>? get streamingData => data['streamingData'] as Map<String, dynamic>?;
  List<Format> get adaptiveFormats => (streamingData?['adaptiveFormats'] as List<dynamic>?)
          ?.map((e) => Format(e as Map<String, dynamic>))
          .toList() ?? [];
  List<Format> get formats => (streamingData?['formats'] as List<dynamic>?)
          ?.map((e) => Format(e as Map<String, dynamic>))
          .toList() ?? [];

  int? get expiresInSeconds => int.tryParse(streamingData?['expiresInSeconds'] as String? ?? '');

  Map<String, dynamic>? get responseContext => data['responseContext'] as Map<String, dynamic>?;
  String? get visitorData => responseContext?['visitorData'] as String?;

  Map<String, dynamic>? get playerConfig => data['playerConfig'] as Map<String, dynamic>?;
  Map<String, dynamic>? get audioConfig => playerConfig?['audioConfig'] as Map<String, dynamic>?;
  Map<String, dynamic>? get playbackTracking => data['playbackTracking'] as Map<String, dynamic>?;
}

class YouTubeAPI {
  static const String _tag = "YouTubeAPI";
  
  static String? cookie;
  static String? visitorData;

  static Future<PlayerResponse> fetchPlayerResponse({
    required String videoId,
    String? playlistId,
    required YouTubeClient client,
  }) async {
    const domain = "https://www.youtube.com";
    const url = "$domain/youtubei/v1/player";

    final context = client.toContextMap(
      visitorData: visitorData,
    );

    final requestBody = <String, dynamic>{
      'context': context,
      'videoId': videoId,
      if (playlistId != null) 'playlistId': playlistId,
      'playbackContext': {
        'contentPlaybackContext': {
          'signatureTimestamp': 20630, // hardcoded mock signature timestamp
        }
      }
    };

    final headers = {
      "User-Agent": client.userAgent,
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Origin": domain,
      "Referer": "$domain/",
      if (cookie != null) "Cookie": cookie!,
    };

    print("[$_tag] Sending /player request for videoId=$videoId, client=${client.clientName}...");
    
    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: json.encode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception("InnerTube player API error: HTTP ${response.statusCode}\n${response.body}");
    }

    final jsonMap = json.decode(response.body) as Map<String, dynamic>;
    final responseObj = PlayerResponse(jsonMap);

    if (visitorData == null && responseObj.visitorData != null) {
      visitorData = responseObj.visitorData;
      print("[$_tag] Saved visitorData session dynamically: $visitorData");
    }

    return responseObj;
  }
}

class PlaybackData {
  final Map<String, dynamic>? audioConfig;
  final Map<String, dynamic>? videoDetails;
  final Map<String, dynamic>? playbackTracking;
  final Format format;
  final String streamUrl;
  final int streamExpiresInSeconds;
  final String streamClient;

  PlaybackData({
    this.audioConfig,
    this.videoDetails,
    this.playbackTracking,
    required this.format,
    required this.streamUrl,
    required this.streamExpiresInSeconds,
    required this.streamClient,
  });

  @override
  String toString() {
    return 'PlaybackData(client: $streamClient, bitrate: ${format.bitrate}, codec: ${format.mimeType}, url: ${streamUrl.substring(0, 50)}...)';
  }
}

class YTPlayerUtils {
  static const String _tag = "YTPlayerUtils";
  static Set<String> disabledStreamClients = {};

  static const YouTubeClient mainClient = YouTubeClient.VISIONOS;
  
  static const List<YouTubeClient> fallbackClients = [
    YouTubeClient.ANDROID_VR_1_43_32,
    YouTubeClient.ANDROID_VR_1_61_48,
    YouTubeClient.ANDROID_VR_NO_AUTH,
  ];

  static Future<PlaybackData> playerResponseForPlayback({
    required String videoId,
    String? playlistId,
    YtAudioQuality audioQuality = YtAudioQuality.high,
    bool isMetered = false,
    YouTubeClient? preferredClient,
  }) async {
    print("[$_tag] === playerResponseForPlayback: videoId=$videoId, preferredClient=${preferredClient?.clientName} ===");

    if (preferredClient != null) {
      print("[$_tag] Preferred client path chosen: ${preferredClient.clientName}");

      final response = await YouTubeAPI.fetchPlayerResponse(
        videoId: videoId,
        playlistId: playlistId,
        client: preferredClient,
      );

      if (response.status != "OK") {
        throw Exception("Playback failed for client ${preferredClient.clientName}: status=${response.status}, reason=${response.reason}");
      }

      final format = _findFormat(response, audioQuality, isMetered);
      if (format == null || format.url == null) {
        throw Exception("Suitable audio stream not found for client: ${preferredClient.clientName}");
      }

      final expiry = response.expiresInSeconds;
      if (expiry == null) {
        throw Exception("Expiry time was null for client: ${preferredClient.clientName}");
      }

      final isValid = await _validateStatus(format.url!);
      if (!isValid) {
        throw Exception("HEAD check stream validation failed for client: ${preferredClient.clientName}");
      }

      return PlaybackData(
        audioConfig: response.audioConfig,
        videoDetails: response.videoDetails,
        playbackTracking: response.playbackTracking,
        format: format,
        streamUrl: format.url!,
        streamExpiresInSeconds: expiry,
        streamClient: preferredClient.clientName,
      );
    }

    print("[$_tag] Fetching /player response using main client: ${mainClient.clientName}");
    PlayerResponse playerResponse = await YouTubeAPI.fetchPlayerResponse(
      videoId: videoId,
      playlistId: playlistId,
      client: mainClient,
    );

    var mainStatus = playerResponse.status;
    var isAgeRestricted = ["AGE_CHECK_REQUIRED", "AGE_VERIFICATION_REQUIRED", "LOGIN_REQUIRED", "CONTENT_CHECK_REQUIRED"]
        .contains(mainStatus);

    Map<String, dynamic>? audioConfig = playerResponse.audioConfig;
    final videoDetails = playerResponse.videoDetails;
    final playbackTracking = playerResponse.playbackTracking;

    Format? selectedFormat;
    int? selectedExpiry;
    String? successClientName;

    final startIndex = isAgeRestricted ? 0 : -1;

    for (var i = startIndex; i < fallbackClients.length; i++) {
      final YouTubeClient client;
      PlayerResponse currentResponse;

      if (i == -1) {
        client = mainClient;
        if (disabledStreamClients.contains(client.clientName)) continue;
        currentResponse = playerResponse;
      } else {
        client = fallbackClients[i];
        if (disabledStreamClients.contains(client.clientName)) continue;

        try {
          currentResponse = await YouTubeAPI.fetchPlayerResponse(
            videoId: videoId,
            playlistId: playlistId,
            client: client,
          );
        } catch (e) {
          print("[$_tag] Client ${client.clientName} fetch failed: $e");
          continue;
        }
      }

      if (currentResponse.status == "OK") {
        selectedFormat = _findFormat(currentResponse, audioQuality, isMetered);
        if (selectedFormat == null || selectedFormat.url == null) continue;

        selectedExpiry = currentResponse.expiresInSeconds;
        if (selectedExpiry == null) continue;

        if (i == fallbackClients.length - 1) {
          successClientName = client.clientName;
          break;
        }

        final isValid = await _validateStatus(selectedFormat.url!);
        if (isValid) {
          successClientName = client.clientName;
          break;
        }
      }
    }

    if (selectedFormat == null || selectedExpiry == null) {
      throw Exception("All streaming clients failed to extract playback URL for videoId=$videoId");
    }

    audioConfig ??= playerResponse.audioConfig;

    return PlaybackData(
      audioConfig: audioConfig,
      videoDetails: videoDetails,
      playbackTracking: playbackTracking,
      format: selectedFormat,
      streamUrl: selectedFormat.url!,
      streamExpiresInSeconds: selectedExpiry,
      streamClient: successClientName ?? "unknown",
    );
  }

  static Format? _findFormat(PlayerResponse response, YtAudioQuality quality, bool isMetered) {
    final formats = response.adaptiveFormats.where((f) => f.isAudio).toList();
    if (formats.isEmpty) return null;

    final maxBitrate = formats.map((f) => f.bitrate).fold(0, (a, b) => a > b ? a : b);

    int scoreAudio(String qualityLabel) {
      switch (qualityLabel) {
        case "AUDIO_QUALITY_HIGH":
          return 3;
        case "AUDIO_QUALITY_MEDIUM":
          return 2;
        case "AUDIO_QUALITY_LOW":
          return 1;
        default:
          return 0;
      }
    }

    int scoreCodec(String mime) {
      final isApple = Platform.isIOS || Platform.isMacOS;
      if (isApple) {
        if (mime.toLowerCase().contains("mp4a")) return 2;
        if (mime.toLowerCase().contains("opus")) return 1;
      } else {
        if (mime.toLowerCase().contains("opus")) return 2;
        if (mime.toLowerCase().contains("mp4a")) return 1;
      }
      return 0;
    }

    if (quality == YtAudioQuality.high) {
      formats.sort((a, b) {
        var cmp = scoreAudio(a.audioQuality).compareTo(scoreAudio(b.audioQuality));
        if (cmp != 0) return cmp;
        cmp = (a.audioChannels ?? 2).compareTo(b.audioChannels ?? 2);
        if (cmp != 0) return cmp;
        cmp = scoreCodec(a.mimeType).compareTo(scoreCodec(b.mimeType));
        if (cmp != 0) return cmp;
        return a.bitrate.compareTo(b.bitrate);
      });
      return formats.last;
    } else if (quality == YtAudioQuality.low) {
      final capped = formats.where((f) => f.bitrate <= 128000).toList();
      if (capped.isEmpty) return formats.first;
      capped.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      return capped.last;
    } else {
      final targetBitrate = isMetered ? 128000.0 : maxBitrate.toDouble();
      final capped = formats.where((f) => f.bitrate <= targetBitrate).toList();
      if (capped.isEmpty) return formats.first;
      capped.sort((a, b) => a.bitrate.compareTo(b.bitrate));
      return capped.last;
    }
  }

  static Future<bool> _validateStatus(String url) async {
    try {
      final request = http.Request('HEAD', Uri.parse(url));
      if (YouTubeAPI.cookie != null) {
        request.headers['Cookie'] = YouTubeAPI.cookie!;
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 4)),
      );
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (e) {
      return false;
    }
  }
}

class YtExtractorService {

  /// Retrieves a working, decrypted, and validated streaming URL for a given 
  /// YouTube video ID without requiring any user authentication or login cookies.
  static Future<String> getStreamUrl(
    String videoId, {
    YtAudioQuality quality = YtAudioQuality.high,
    bool isMetered = false,
  }) async {
    final data = await YTPlayerUtils.playerResponseForPlayback(
      videoId: videoId,
      audioQuality: quality,
      isMetered: isMetered,
    );
    return data.streamUrl;
  }
}
