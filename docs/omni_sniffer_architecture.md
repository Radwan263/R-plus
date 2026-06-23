# Omni-Sniffer Engine: Architecture and Data Models

## 1. Introduction

This document outlines the architectural design and data models for the "Omni-Sniffer" engine, a core component of the R-Plus Android download manager. The engine aims to overcome limitations of existing download solutions by employing advanced traffic sniffing, dynamic scraping, and adaptive stream handling. The primary goal is to reliably capture and download media from platforms like YouTube, Facebook, and private video hosts, even when faced with dynamic tokenization, hidden streams, and custom players.

## 2. Architectural Overview

The Omni-Sniffer engine will be integrated into the existing R-Plus application, primarily extending the `BrowserPage` and `DownloadManager` functionalities. The architecture is modular, allowing for independent development and maintenance of its key components:

### 2.1. Network Traffic Sniffer (Integrated with `InAppWebView`)

This is the central component for real-time request interception. It will reside within the `BrowserPage` and leverage `flutter_inappwebview`'s advanced callbacks. Its responsibilities include:

*   **Comprehensive Request Interception:** Utilizing `shouldInterceptRequest` and `onLoadResource` to monitor all network traffic (XHR, Fetch, WebSockets, standard HTTP requests).
*   **Intelligent Filtering:** Identifying and filtering out advertising trackers and non-media content. Prioritizing requests with video signatures (e.g., `.mp4`, `.m3u8`, `.mpd`, `video/`, `audio/`, `master.json`).
*   **Header & Cookie Mimicking:** Extracting and storing critical session headers (`User-Agent`, `Cookies`, `Referer`, custom authorization headers) from intercepted media requests. These headers are crucial for preventing `403 Forbidden` or `401 Unauthorized` errors during the actual download.
*   **Dynamic JS Injection Trigger:** Coordinating with the Cloud-Driven Dynamic Scrapers to inject JavaScript when specific conditions are met (e.g., `onLoadStop` event for a particular domain).

### 2.2. Cloud-Driven Dynamic Scrapers

To ensure resilience against website layout and API changes, this component introduces a remote-controlled scraping mechanism:

*   **Remote Rule Fetching:** A dedicated service will fetch updated JavaScript scraping rules from a remote server (e.g., Firebase, Supabase, or a custom API endpoint). These rules will be versioned and cached locally.
*   **Dynamic JS Injection:** The fetched JavaScript scripts will be injected into the `InAppWebView`'s DOM using `evaluateJavascript` or `onLoadStop`. These scripts will be designed to programmatically trigger hidden click events, extract Blob URLs, or parse embedded JSON metadata to reveal raw video streams.
*   **Anti-Breaking Architecture:** By externalizing scraping logic, the application can adapt to website changes without requiring a full app update.

### 2.3. Encapsulated Stream Decryption and Muxing Engine

This component addresses adaptive streaming formats where video and audio tracks are delivered separately:

*   **Adaptive Stream Detection:** The `NetworkTrafficSniffer` will identify scenarios where high-definition video and audio tracks are separated (e.g., HLS, DASH).
*   **Background Muxing:** For such cases, a background worker utilizing `ffmpeg_kit_flutter` will be initiated. It will download both the separate video and audio streams and losslessly mux them into a single MP4 container.
*   **Error Handling & Resumption:** Robust error handling and download resumption capabilities will be implemented for both individual stream downloads and the muxing process.

## 3. Data Models

To support the Omni-Sniffer engine's functionalities, the existing `ActiveDownload` model will be enhanced, and a new `ScrapingRule` model will be introduced.

### 3.1. Enhanced `DownloadTask` Model (formerly `ActiveDownload`)

The `ActiveDownload` model will be renamed to `DownloadTask` to better reflect its expanded responsibilities. It will include additional fields to store intercepted headers and manage adaptive streaming components.

```dart
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
```

### 3.2. `ScrapingRule` Model

This model will define the structure for remote JavaScript scraping rules, allowing the application to dynamically adapt its scraping logic.

```dart
class ScrapingRule {
  final String domainPattern; // Regex pattern to match target domains (e.g., ".*youtube\.com.*")
  final String javascriptCode; // The JavaScript code to be injected
  final int version; // Version of the scraping rule
  final bool isActive; // Whether the rule is currently active
  final List<String> triggerEvents; // Events that trigger injection (e.g., ["onLoadStop", "onXhrComplete"])

  ScrapingRule({
    required this.domainPattern,
    required this.javascriptCode,
    required this.version,
    this.isActive = true,
    this.triggerEvents = const ["onLoadStop"],
  });

  factory ScrapingRule.fromJson(Map<String, dynamic> json) => ScrapingRule(
        domainPattern: json["domainPattern"],
        javascriptCode: json["javascriptCode"],
        version: json["version"],
        isActive: json["isActive"] ?? true,
        triggerEvents: List<String>.from(json["triggerEvents"] ?? ["onLoadStop"]),
      );

  Map<String, dynamic> toJson() => {
        "domainPattern": domainPattern,
        "javascriptCode": javascriptCode,
        "version": version,
        "isActive": isActive,
        "triggerEvents": triggerEvents,
      };
}
```

## 4. Conclusion

This architectural design provides a robust framework for the Omni-Sniffer engine, addressing the complex challenges of modern video downloading. The modular approach, combined with dynamic scraping capabilities and adaptive stream handling, will enable the R-Plus application to offer a superior user experience. The next steps involve implementing these components and integrating them into the existing Flutter application.
