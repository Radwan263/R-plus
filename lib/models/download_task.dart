import 'package:dio/dio.dart';

class DownloadTask {
  final String url; // The primary URL of the media to be downloaded
  final String fileName;
  double progress;
  String size;
  bool isCompleted;
  bool isFailed;
  bool isPaused;
  CancelToken? cancelToken;
  int downloadedBytes;
  int totalBytes;
  
  // Omni-Sniffer additions
  final Map<String, String> headers; // Intercepted session headers (User-Agent, Cookie, Referer, Authorization)
  final bool isAdaptiveStream; // True if the download involves separate audio/video streams
  final String? videoStreamUrl; // URL for the video stream (if adaptive)
  final String? audioStreamUrl; // URL for the audio stream (if adaptive)
  final String? mimeType; // Detected MIME type of the media

  DownloadTask({
    required this.url,
    required this.fileName,
    this.progress = 0.0,
    this.size = "...",
    this.isCompleted = false,
    this.isFailed = false,
    this.isPaused = false,
    this.cancelToken,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
    
    // Omni-Sniffer additions
    this.headers = const {},
    this.isAdaptiveStream = false,
    this.videoStreamUrl,
    this.audioStreamUrl,
    this.mimeType,
  });

  // Factory constructor for creating a DownloadTask from JSON (for persistence)
  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        url: json["url"],
        fileName: json["fileName"],
        progress: json["progress"]?.toDouble() ?? 0.0,
        size: json["size"] ?? "...",
        isCompleted: json["isCompleted"] ?? false,
        isFailed: json["isFailed"] ?? false,
        isPaused: json["isPaused"] ?? false,
        downloadedBytes: json["downloadedBytes"] ?? 0,
        totalBytes: json["totalBytes"] ?? -1,
        headers: Map<String, String>.from(json["headers"] ?? {}),
        isAdaptiveStream: json["isAdaptiveStream"] ?? false,
        videoStreamUrl: json["videoStreamUrl"],
        audioStreamUrl: json["audioStreamUrl"],
        mimeType: json["mimeType"],
      );

  // Method for converting a DownloadTask to JSON (for persistence)
  Map<String, dynamic> toJson() => {
        "url": url,
        "fileName": fileName,
        "progress": progress,
        "size": size,
        "isCompleted": isCompleted,
        "isFailed": isFailed,
        "isPaused": isPaused,
        "downloadedBytes": downloadedBytes,
        "totalBytes": totalBytes,
        "headers": headers,
        "isAdaptiveStream": isAdaptiveStream,
        "videoStreamUrl": videoStreamUrl,
        "audioStreamUrl": audioStreamUrl,
        "mimeType": mimeType,
      };
}
