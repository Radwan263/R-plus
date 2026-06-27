import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/download_task.dart';

class NetworkTrafficSniffer {
  static final NetworkTrafficSniffer _instance = NetworkTrafficSniffer._internal();
  factory NetworkTrafficSniffer() => _instance;
  NetworkTrafficSniffer._internal();

  final StreamController<DownloadTask> _snifferStreamController = StreamController<DownloadTask>.broadcast();
  Stream<DownloadTask> get snifferStream => _snifferStreamController.stream;

  // Comprehensive media signatures for interception
  final List<String> _mediaSignatures = [
    '.mp4', '.m3u8', '.mpd', '.mkv', '.webm', '.avi', '.mov', '.flv',
    'video/', 'audio/', 'application/x-mpegURL', 'application/dash+xml', 
    'master.json', 'playlist.m3u8', 'manifest.mpd', 'init.mp4', 'chunk-stream'
  ];

  // Tracker and AD domains to filter out
  final List<String> _trackerDomains = [
    'google-analytics.com', 'doubleclick.net', 'facebook.net', 
    'scorecardresearch.com', 'adnxs.com', 'amazon-adsystem.com',
    'ads.pubmatic.com', 'taboola.com', 'outbrain.com'
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
    // 1. Aggressive Tracker Filtering
    if (_trackerDomains.any((domain) => url.contains(domain))) return;

    // 2. Advanced Media Detection Logic
    bool isMedia = _mediaSignatures.any((sig) => url.toLowerCase().contains(sig.toLowerCase()));
    
    // Additional check for XHR/Fetch that might be media manifests without clear extensions
    if (!isMedia && (url.contains('api/v1/play') || url.contains('get_video_info'))) {
      isMedia = true; 
    }

    if (isMedia) {
      // 3. Dynamic Header & Cookie Mimicking
      // We capture the EXACT session state to bypass 403/401
      Map<String, String> sessionHeaders = {
        'User-Agent': headers['User-Agent'] ?? 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Cookie': headers['Cookie'] ?? '',
        'Referer': headers['Referer'] ?? url,
        'Accept': headers['Accept'] ?? '*/*',
        'Accept-Language': headers['Accept-Language'] ?? 'en-US,en;q=0.9',
        'Origin': headers['Origin'] ?? '',
      };

      // Extract security tokens and custom auth headers
      headers.forEach((key, value) {
        String k = key.toLowerCase();
        if (k.contains('auth') || k.contains('token') || k.contains('key') || k.startsWith('x-')) {
          sessionHeaders[key] = value;
        }
      });

      // 4. Adaptive Stream Identification
      bool isAdaptive = url.contains('.m3u8') || url.contains('.mpd') || url.contains('manifest') || url.contains('playlist');

      // 5. Create and emit a robust DownloadTask
      final task = DownloadTask(
        url: url,
        fileName: _extractFileName(url),
        headers: sessionHeaders,
        isAdaptiveStream: isAdaptive,
        mimeType: _detectMimeType(url),
        // If it's a known adaptive format, we might need to further parse it later
        videoStreamUrl: isAdaptive ? url : null, 
      );

      _snifferStreamController.add(task);
    }
  }

  String _extractFileName(String url) {
    try {
      Uri uri = Uri.parse(url);
      String path = uri.path;
      String fileName = path.split('/').last;
      
      // Remove query params if any in the filename
      if (fileName.contains('?')) {
        fileName = fileName.split('?').first;
      }

      if (fileName.isEmpty || !fileName.contains('.')) {
        String ext = url.contains('.m3u8') ? '.m3u8' : (url.contains('.mpd') ? '.mpd' : '.mp4');
        return "media_${DateTime.now().millisecondsSinceEpoch}$ext";
      }
      return fileName;
    } catch (e) {
      return "media_${DateTime.now().millisecondsSinceEpoch}.mp4";
    }
  }

  String _detectMimeType(String url) {
    String lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8') || lowerUrl.contains('playlist')) return 'application/x-mpegURL';
    if (lowerUrl.contains('.mpd') || lowerUrl.contains('manifest')) return 'application/dash+xml';
    if (lowerUrl.contains('.mp4')) return 'video/mp4';
    if (lowerUrl.contains('.mp3')) return 'audio/mpeg';
    if (lowerUrl.contains('.webm')) return 'video/webm';
    return 'video/unknown';
  }

  void dispose() {
    _snifferStreamController.close();
  }
}
