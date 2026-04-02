import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  
  runApp(const RCimaApp());
}

class RCimaApp extends StatelessWidget {
  const RCimaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R-Plus Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        useMaterial3: true,
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(onDownloadStarted: () => setState(() => _selectedIndex = 2)),
          const BrowserPage(),
          const DownloadsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: const Color(0xFF1A1A1A),
        indicatorColor: Colors.blueAccent.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: Colors.blueAccent), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.travel_explore), selectedIcon: Icon(Icons.explore, color: Colors.blueAccent), label: 'المتصفح'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download, color: Colors.blueAccent), label: 'التحميلات'),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onDownloadStarted;
  const HomePage({super.key, required this.onDownloadStarted});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  Future<void> _analyzeUrl(String url) async {
    if (url.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final cleanUrl = url.trim();
      
      if (cleanUrl.contains("youtube.com") || cleanUrl.contains("youtu.be")) {
        final ytInstance = yt.YoutubeExplode();
        try {
          final video = await ytInstance.videos.get(cleanUrl);
          final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
          final streamInfo = manifest.muxed.withHighestBitrate();
          final size = streamInfo.size.totalMegaBytes.toStringAsFixed(2);
          _showDownloadSheet(video.title, "$size MB", isYoutube: true, videoUrl: streamInfo.url.toString());
        } finally {
          ytInstance.close();
        }
      } else {
        // Generic analysis for other social media
        final response = await http.get(Uri.parse(cleanUrl), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36'
        });
        
        if (response.statusCode == 200) {
          // Simple regex to find video tags or common patterns if direct link fails
          if (response.headers['content-type']?.contains("video") ?? false) {
             _showDownloadSheet("فيديو مكتشف", "رابط مباشر", isYoutube: false, videoUrl: cleanUrl);
          } else {
            // Check for Open Graph video tags
            final metaMatch = RegExp(r'property="og:video" content="([^"]+)"').firstMatch(response.body);
            if (metaMatch != null) {
              final videoUrl = metaMatch.group(1)!;
              _showDownloadSheet("فيديو من السوشيال ميديا", "مكتشف", isYoutube: false, videoUrl: videoUrl);
            } else {
               throw Exception("لم يتم العثور على محتوى فيديو مباشر. جرب استخدام المتصفح الداخلي.");
            }
          }
        } else {
          throw Exception("فشل الوصول للرابط. كود الحالة: ${response.statusCode}");
        }
      }
    } catch (e) {
      debugPrint("Analysis Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("فشل التحليل: ${e.toString().replaceAll("Exception: ", "")}"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        )
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDownloadSheet(String title, String size, {required bool isYoutube, required String videoUrl}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text("الحجم التقريبي: $size", style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _choiceChip("فيديو MP4", Icons.movie, Colors.blueAccent),
                _choiceChip("صوت MP3", Icons.audiotrack, Colors.orangeAccent),
              ],
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () { 
                Navigator.pop(context); 
                widget.onDownloadStarted();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("بدأ التحميل في الخلفية..."), behavior: SnackBarBehavior.floating)
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("بدء التحميل الآن", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String label, IconData icon, Color color) => Chip(
    avatar: Icon(icon, size: 18, color: color),
    label: Text(label),
    backgroundColor: Colors.black26,
    side: BorderSide(color: color.withOpacity(0.3)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.transparent],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_download_rounded, size: 100, color: Colors.blueAccent),
                const SizedBox(height: 10),
                const Text("R-Plus Downloader", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const Text("حمل فيديوهاتك المفضلة بسهولة", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "الزق رابط الفيديو هنا...",
                    prefixIcon: const Icon(Icons.link, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Colors.blueAccent, width: 1)),
                  ),
                ),
                const SizedBox(height: 25),
                if (_isLoading) 
                  const CircularProgressIndicator(color: Colors.blueAccent)
                else 
                  ElevatedButton.icon(
                    onPressed: () => _analyzeUrl(_urlController.text),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text("تحليل الرابط الذكي"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(220, 55),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  final TextEditingController _addressController = TextEditingController(text: "https://www.google.com");
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _detectedVideoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: TextField(
            controller: _addressController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: "ابحث أو أدخل عنواناً...",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (value) {
              var url = value.trim();
              if (!url.startsWith("http")) url = "https://www.google.com/search?q=$url";
              webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => webViewController?.reload(),
          )
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(value: _progress, backgroundColor: Colors.transparent, color: Colors.blueAccent, minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    allowsInlineMediaPlayback: true,
                    useShouldInterceptAjaxRequest: true,
                    useShouldInterceptFetchRequest: true,
                    mediaPlaybackRequiresUserGesture: false,
                    transparentBackground: false, 
                    hardwareAcceleration: true,
                    safeBrowsingEnabled: true,
                    cacheEnabled: true,
                    domStorageEnabled: true,
                    supportZoom: true,
                  ),
                  onWebViewCreated: (controller) => webViewController = controller,
                  onLoadStart: (controller, url) {
                    setState(() {
                      _addressController.text = url.toString();
                      _detectedVideoUrl = null;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() => _addressController.text = url.toString());
                    _checkHistory();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  onLoadResource: (controller, resource) {
                    final url = resource.url.toString();
                    if (url.contains(".mp4") || url.contains(".m3u8") || url.contains("fbcdn.net") || url.contains("googlevideo.com")) {
                      if (_detectedVideoUrl == null) {
                        setState(() => _detectedVideoUrl = url);
                      }
                    }
                  },
                ),
                if (_detectedVideoUrl != null)
                  Positioned(
                    bottom: 30,
                    right: 20,
                    child: FloatingActionButton.extended(
                      backgroundColor: Colors.redAccent,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text("تحميل الفيديو", style: TextStyle(color: Colors.white)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("تم كشف الفيديو! جاري التحميل..."), behavior: SnackBarBehavior.floating),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Container(
            height: 55,
            decoration: const BoxDecoration(color: Color(0xFF1A1A1A), border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _canGoBack ? Colors.white : Colors.grey), onPressed: _canGoBack ? () => webViewController?.goBack() : null),
                IconButton(icon: Icon(Icons.arrow_forward_ios, size: 18, color: _canGoForward ? Colors.white : Colors.grey), onPressed: _canGoForward ? () => webViewController?.goForward() : null),
                IconButton(icon: const Icon(Icons.home_rounded, size: 22), onPressed: () => webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com")))),
                IconButton(icon: const Icon(Icons.share_rounded, size: 20), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkHistory() async {
    if (webViewController != null) {
      bool canBack = await webViewController!.canGoBack();
      bool canForward = await webViewController!.canGoForward();
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canForward;
      });
    }
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("قائمة التحميلات تظهر هنا")));
}
