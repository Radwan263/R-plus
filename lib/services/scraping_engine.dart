import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scraping_rule.dart';

class ScrapingEngine {
  static final ScrapingEngine _instance = ScrapingEngine._internal();
  factory ScrapingEngine() => _instance;
  ScrapingEngine._internal();

  List<ScrapingRule> _rules = [];
  static const String _rulesKey = 'scraping_rules';
  static const String _remoteRulesUrl = 'https://raw.githubusercontent.com/Radwan263/R-plus/main/rules/dynamic_rules.json';

  Future<void> init() async {
    await _loadLocalRules();
    _fetchRemoteRules(); 
  }

  Future<void> _loadLocalRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getString(_rulesKey);
    if (rulesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(rulesJson);
        _rules = decoded.map((item) => ScrapingRule.fromJson(item)).toList();
      } catch (e) {
        _rules = [];
      }
    }
  }

  Future<void> _fetchRemoteRules() async {
    try {
      final response = await http.get(Uri.parse(_remoteRulesUrl));
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        final remoteRules = decoded.map((item) => ScrapingRule.fromJson(item)).toList();
        
        if (_rules.isEmpty || remoteRules.first.version > _rules.first.version) {
          _rules = remoteRules;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_rulesKey, jsonEncode(_rules.map((r) => r.toJson()).toList()));
        }
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> injectRules(InAppWebViewController controller, WebUri? url, String event) async {
    if (url == null) return;
    
    final currentUrl = url.toString();
    
    // 1. Inject Universal Finder first
    await controller.evaluateJavascript(source: universalMediaFinderJs);

    // 2. Inject Domain Specific Rules
    for (var rule in _rules) {
      if (rule.isActive && 
          rule.triggerEvents.contains(event) && 
          RegExp(rule.domainPattern).hasMatch(currentUrl)) {
        await controller.evaluateJavascript(source: rule.javascriptCode);
      }
    }
  }

  // Advanced JS script to bypass dynamic tokenization and find hidden streams
  static const String universalMediaFinderJs = """
    (function() {
      const DEBUG = true;
      function log(msg) { if(DEBUG) console.log('[OmniSniffer-JS] ' + msg); }

      function findMedia() {
        const media = [];
        
        // A. Standard Video/Audio Elements
        document.querySelectorAll('video, audio, source').forEach(el => {
          const src = el.src || el.getAttribute('src');
          if (src && src.startsWith('http')) {
            media.push({url: src, type: el.tagName.toLowerCase(), method: 'DOM_SCAN'});
          }
        });

        // B. Intercepting Blob URLs (Complex but effective)
        // We look for any video element with a blob: src
        document.querySelectorAll('video').forEach(v => {
          if(v.src && v.src.startsWith('blob:')) {
            log('Found Blob URL: ' + v.src);
            // Blob URLs can't be downloaded directly, but we signal their presence
            // to trigger more aggressive traffic sniffing.
            media.push({url: v.src, type: 'blob', method: 'BLOB_DETECT'});
          }
        });

        // C. Site-Specific JSON Metadata Extraction
        // 1. YouTube Initial Player Response
        if (window.ytInitialPlayerResponse) {
          try {
            const streamingData = window.ytInitialPlayerResponse.streamingData;
            if (streamingData && streamingData.formats) {
              streamingData.formats.forEach(f => {
                if(f.url) media.push({url: f.url, type: 'video/youtube', method: 'YT_JSON'});
              });
            }
          } catch(e) {}
        }

        // 2. Generic JSON-LD or Metadata
        document.querySelectorAll('script[type="application/ld+json"]').forEach(s => {
          try {
            const data = JSON.parse(s.innerText);
            if(data.contentUrl) media.push({url: data.contentUrl, type: 'json-ld', method: 'LD_JSON'});
          } catch(e) {}
        });

        // D. Lulu Video & Custom Players (Looking for window-level variables)
        const customVars = ['player', 'jwplayer', 'vjs', 'videojs', 'config', 'flashvars'];
        customVars.forEach(v => {
          if (window[v] && typeof window[v] === 'object') {
            // Attempt to stringify and find URLs inside
            const str = JSON.stringify(window[v]);
            const m3u8Match = str.match(/https?:\/\/[^"']+\.m3u8[^"']*/);
            if(m3u8Match) media.push({url: m3u8Match[0], type: 'hls', method: 'VAR_SCAN'});
          }
        });

        return media;
      }

      // Communication with Flutter
      function reportMedia(mediaList) {
        if (mediaList.length > 0) {
          window.flutter_inappwebview.callHandler('onMediaFound', JSON.stringify(mediaList));
        }
      }

      // Monitor DOM changes for dynamic players
      const observer = new MutationObserver((mutations) => {
        const found = findMedia();
        reportMedia(found);
      });
      
      observer.observe(document.body, { childList: true, subtree: true });
      
      // Initial scan
      reportMedia(findMedia());

      // E. Hooking into XHR to catch manifests (Advanced)
      const oldXHR = window.XMLHttpRequest.prototype.open;
      window.XMLHttpRequest.prototype.open = function() {
        this.addEventListener('load', function() {
          const url = this.responseURL;
          if (url.includes('.m3u8') || url.includes('.mpd') || url.includes('playlist')) {
            log('XHR Manifest Detected: ' + url);
            reportMedia([{url: url, type: 'manifest', method: 'XHR_HOOK'}]);
          }
        });
        return oldXHR.apply(this, arguments);
      };
    })();
  """;
}
