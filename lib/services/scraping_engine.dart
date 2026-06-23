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
    _fetchRemoteRules(); // Fetch in background
  }

  Future<void> _loadLocalRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getString(_rulesKey);
    if (rulesJson != null) {
      final List<dynamic> decoded = jsonDecode(rulesJson);
      _rules = decoded.map((item) => ScrapingRule.fromJson(item)).toList();
    }
  }

  Future<void> _fetchRemoteRules() async {
    try {
      final response = await http.get(Uri.parse(_remoteRulesUrl));
      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        final remoteRules = decoded.map((item) => ScrapingRule.fromJson(item)).toList();
        
        // Basic versioning check
        if (_rules.isEmpty || remoteRules.first.version > _rules.first.version) {
          _rules = remoteRules;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_rulesKey, jsonEncode(_rules.map((r) => r.toJson()).toList()));
        }
      }
    } catch (e) {
      // Silently fail or log to ErrorHunter
    }
  }

  Future<void> injectRules(InAppWebViewController controller, WebUri? url, String event) async {
    if (url == null) return;
    
    final currentUrl = url.toString();
    for (var rule in _rules) {
      if (rule.isActive && 
          rule.triggerEvents.contains(event) && 
          RegExp(rule.domainPattern).hasMatch(currentUrl)) {
        await controller.evaluateJavascript(source: rule.javascriptCode);
      }
    }
  }

  // Robust JS script to find media sources
  static const String universalMediaFinderJs = """
    (function() {
      function findMedia() {
        const media = [];
        
        // 1. Search in standard HTML elements
        document.querySelectorAll('video, audio, source').forEach(el => {
          if (el.src && el.src.startsWith('http')) {
            media.push({url: el.src, type: el.tagName.toLowerCase()});
          }
        });

        // 2. Search for Blob URLs
        // Note: Intercepting createObjectURL is more complex, 
        // but we can look for existing blob: urls in src
        
        // 3. Search for common window-level variables (stubborn sites)
        const commonVars = ['playerConfig', 'videoData', 'ytInitialPlayerResponse', '__NEXT_DATA__'];
        commonVars.forEach(v => {
          if (window[v]) {
            // Logic to parse these would be specific to the site rule
          }
        });

        return JSON.stringify(media);
      }
      
      // Periodically check for dynamic elements
      const observer = new MutationObserver((mutations) => {
        const found = findMedia();
        if (found !== '[]') {
          window.flutter_inappwebview.callHandler('onMediaFound', found);
        }
      });
      
      observer.observe(document.body, { childList: true, subtree: true });
      
      // Initial check
      const initialFound = findMedia();
      if (initialFound !== '[]') {
        window.flutter_inappwebview.callHandler('onMediaFound', initialFound);
      }
    })();
  """;
}
