import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/download_task.dart';

class NetworkTrafficSniffer {
  static final NetworkTrafficSniffer _instance = NetworkTrafficSniffer._internal();
  factory NetworkTrafficSniffer() => _instance;
  NetworkTrafficSniffer._internal();

  final StreamController<DownloadTask> _snifferStreamController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get snifferStream => _snifferStreamController.stream;

  // List of media extensions and MIME types to look for
  final List<String> _mediaSignatures = [
    '.mp4', '.m3u8', '.mpd', '.mkv', '.webm', '.avi', '.mov', '.flv',
    'video/', 'audio/', 'application/x-mpegURL', 'application/dash+xml', 'master.json'
  ];

  // List of tracker domains to ignore
  final List<String> _trackerDomains = [
    'google-analytics.com', 'doubleclick.net', 'facebook.net', 'scorecardresearch.com'
  ];

  void handleRequest(WebResourceRequest request) {
    _analyzeResource(
      url: request.url.toString(),
      headers: request.headers ?? {},
      method: request.method,
    );
  }

  void handleResource(LoadedResource resource) {
    _analyzeResource(
      url: resource.url.toString(),
      headers: {}, // LoadedResource doesn't provide headers directly
      method: 'GET',
    );
  }

  void _analyzeResource({required String url, required Map<String, String> headers, String? method}) {
    // 1. Filter out trackers
    if (_trackerDomains.any((domain) => url.contains(domain))) return;

    // 2. Check for media signatures
    bool isMedia = _mediaSignatures.any((sig) => url.toLowerCase().contains(sig.toLowerCase()));

    if (isMedia) {
      // 3. Extract critical headers
      Map<String, String> sessionHeaders = {
        'User-Agent': headers['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Cookie': headers['Cookie'] ?? '',
        'Referer': headers['Referer'] ?? '',
      };

      // Add any custom authorization headers if present
      headers.forEach((key, value) {
        if (key.toLowerCase().contains('auth') || key.toLowerCase().contains('token')) {
          sessionHeaders[key] = value;
        }
      });

      // 4. Create and emit a DownloadTask
      final task = DownloadTask(
        url: url,
        fileName: _extractFileName(url),
        headers: sessionHeaders,
        isAdaptiveStream: url.contains('.m3u8') || url.contains('.mpd'),
        mimeType: _detectMimeType(url),
      );

      _snifferStreamController.add(task);
    }
  }

  String _extractFileName(String url) {
    try {
      Uri uri = Uri.parse(url);
      String path = uri.path;
      String fileName = path.split('/').last;
      if (fileName.isEmpty || !fileName.contains('.')) {
        return "video_${DateTime.now().millisecondsSinceEpoch}.mp4";
      }
      return fileName;
    } catch (e) {
      return "video_${DateTime.now().millisecondsSinceEpoch}.mp4";
    }
  }

  String _detectMimeType(String url) {
    if (url.contains('.m3u8')) return 'application/x-mpegURL';
    if (url.contains('.mpd')) return 'application/dash+xml';
    if (url.contains('.mp4')) return 'video/mp4';
    if (url.contains('.mp3')) return 'audio/mpeg';
    return 'video/unknown';
  }

  void dispose() {
    _snifferStreamController.close();
  }
}
