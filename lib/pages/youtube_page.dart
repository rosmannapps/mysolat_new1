import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simple model for a YouTube channel, matching your JSON structure.
class YouTubeChannel {
  final String displayName;
  final String url;
  final String assetName;

  YouTubeChannel({
    required this.displayName,
    required this.url,
    required this.assetName,
  });

  factory YouTubeChannel.fromJson(Map<String, dynamic> json) {
    return YouTubeChannel(
      displayName: json['displayName'] as String? ?? '',
      url: json['url'] as String? ?? '',
      assetName: json['assetName'] as String? ?? '',
    );
  }
}

/// Fetch and decode the channels list from assets.
Future<List<YouTubeChannel>> _loadChannels(BuildContext context) async {
  final jsonStr = await DefaultAssetBundle.of(context)
      .loadString('assets/youtube/youtube_channels.json');

  final List<dynamic> raw = json.decode(jsonStr) as List<dynamic>;
  return raw
      .map((e) => YouTubeChannel.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Main YouTube page, with iOS-style big title + 3-column grid.
class YouTubePage extends StatelessWidget {
  const YouTubePage({super.key});

  static const _titleTextStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: Colors.black,
  );

  static const _channelNameStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Colors.black,
  );

  static const _bgColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tetapan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<YouTubeChannel>>(
          future: _loadChannels(context),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Ralat memuatkan senarai YouTube.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final channels = snapshot.data ?? [];
            if (channels.isEmpty) {
              return const Center(
                child: Text('Tiada saluran YouTube buat masa ini.'),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text('YouTube', style: _titleTextStyle),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return _YouTubeChannelTile(channel: channel);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Single tile: rounded square image + channel name below, 2-line max.
class _YouTubeChannelTile extends StatelessWidget {
  const _YouTubeChannelTile({required this.channel});

  final YouTubeChannel channel;

  @override
  Widget build(BuildContext context) {
    final String imagePath = 'assets/youtube/${channel.assetName}.png';

    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => _openChannelInApp(context, channel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Image tile
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Container(
                color: const Color(0xFFE5E7EB),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.play_circle_fill,
                          size: 40, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            channel.displayName.trim(),
            style: YouTubePage._channelNameStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Open channel in-app (WebView) so back returns to your channel list.
Future<void> _openChannelInApp(BuildContext context, YouTubeChannel channel) async {
  final url = channel.url.trim();
  if (url.isEmpty) return;

  final uri = Uri.tryParse(url);
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL YouTube tidak sah.')),
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => YouTubeWebViewPage(
        title: channel.displayName.trim().isEmpty ? 'YouTube' : channel.displayName.trim(),
        url: uri.toString(),
      ),
    ),
  );
}

/// In-app WebView page with proper Android back handling.
class YouTubeWebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const YouTubeWebViewPage({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<YouTubeWebViewPage> createState() => _YouTubeWebViewPageState();
}

class _YouTubeWebViewPageState extends State<YouTubeWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _handleBack() async {
    final canGoBack = await _controller.canGoBack();
    if (canGoBack) {
      await _controller.goBack();
      return false; // don't pop flutter page
    }
    return true; // pop flutter page (back to list)
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87),
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) Navigator.of(context).pop();
            },
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}