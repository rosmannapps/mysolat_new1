import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

class YouTubeChannel {
  final String displayName;
  final String url;
  final String assetName;

  const YouTubeChannel({
    required this.displayName,
    required this.url,
    required this.assetName,
  });

  factory YouTubeChannel.fromJson(Map<String, dynamic> json) {
    return YouTubeChannel(
      displayName: json['displayName'] as String,
      url: json['url'] as String,
      assetName: json['assetName'] as String,
    );
  }
}

Future<List<YouTubeChannel>> loadYouTubeChannels() async {
  try {
    final jsonStr =
    await rootBundle.loadString('assets/youtube/youtube_channels.json');
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => YouTubeChannel.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e, st) {
    debugPrint('❌ Failed to load YouTube channels: $e\n$st');
    return [];
  }
}