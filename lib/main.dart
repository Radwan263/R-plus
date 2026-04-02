import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RCimaApp());
}

class RCimaApp extends StatelessWidget {
  const RCimaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R Cima Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
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
        backgroundColor: const Color(0xFF1E1E1E),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.travel_explore), label: 'المتصفح'),
          NavigationDestination(icon: Icon(Icons.download_outlined), label: 'التحميلات'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// شاشة الرئيسية
// ----------------------------------------------------
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
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        final ytInstance = yt.YoutubeExplode();
        try {
          final video = await ytInstance.videos.get(url);
          final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
          final streamInfo = manifest.muxed.withHighestBitrate();
          final size = streamInfo.size.totalMegaBytes.toStringAsFixed(2);
          _showDownloadSheet(video.title, "$size MB", isYoutube: true);
        } finally {
          ytInstance.close();
        }
      } else {
        final response = await http.head(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        });
        final sizeBytes = int.tryParse(response.headers['content-length'] ?? "0") ?? 0;
        final sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
        _showDownloadSheet("ملف مكتشف", sizeBytes > 0 ? "$sizeMB MB" : "رابط مباشر", isYoutube: false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل التحليل: تأكد من الرابط")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDownloadSheet(String title, String size, {required bool isYoutube}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text("الحجم التقريبي: $size", style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isYoutube) _choiceChip("فيديو MP4", Icons.movie),
                _choiceChip("صوت MP3", Icons.audiotrack),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); widget.onDownloadStarted(); },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueAccent),
              child: const Text("بدء التحميل الآن"),
            )
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String label, IconData icon) => Chip(avatar: Icon(icon, size: 16), label: Text(label));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_download, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 30),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: "الزق الرابط هنا...",
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator()
              else ElevatedButton.icon(
                onPressed: () => _analyzeUrl(_urlController.text),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text("تحليل الرابط الذكي"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// شاشة المتصفح المتكامل (Integrated Browser)
// ----------------------------------------------------
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
        backgroundColor: const Color(0xFF1E1E1E),
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
          child: TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: "ابحث أو أدخل عنواناً",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 20),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onSubmitted: (value) {
              var url = value;
              if (!url.startsWith("http")) url = "https://www.google.com/search?q=$url";
              webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => webViewController?.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(value: _progress, backgroundColor: Colors.transparent, color: Colors.blueAccent),
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
                    transparentBackground: true,
                    // إعدادات أندرويد المتقدمة لحل الشاشة السوداء
                    hardwareAcceleration: true,
                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    useWideViewPort: true,
                    loadWithOverviewMode: true,
                    // إعدادات iOS
                    allowsBackForwardNavigationGestures: true,
                  ),
                  onWebViewCreated: (controller) => webViewController = controller,
                  onLoadStart: (controller, url) {
                    setState(() {
                      _addressController.text = url.toString();
                      _detectedVideoUrl = null;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _addressController.text = url.toString();
                    });
                    _checkHistory();
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() => _progress = progress / 100);
                  },
                  // منطق كشف الفيديوهات (Video Sniffer)
                  onLoadResource: (controller, resource) {
                    final url = resource.url.toString();
                    // كشف روابط الفيديو المباشرة والتحويلات
                    if (url.contains(".mp4") || 
                        url.contains(".m3u8") || 
                        url.contains("video_redirect") || 
                        url.contains("fbcdn.net") || // روابط فيسبوك
                        url.contains("tiktokcdn.com") || // روابط تيك توك
                        url.contains("googlevideo.com")) { // روابط يوتيوب (أحياناً تظهر هنا)
                      setState(() => _detectedVideoUrl = url);
                    }
                  },
                ),
                if (_detectedVideoUrl != null)
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: Colors.redAccent,
                      child: const Icon(Icons.download, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("تم كشف فيديو! جاري التحضير...")),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // شريط أدوات المتصفح السفلي
          Container(
            height: 50,
            color: const Color(0xFF1E1E1E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: _canGoBack ? Colors.white : Colors.grey),
                  onPressed: _canGoBack ? () => webViewController?.goBack() : null,
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward, color: _canGoForward ? Colors.white : Colors.grey),
                  onPressed: _canGoForward ? () => webViewController?.goForward() : null,
                ),
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com"))),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {},
                ),
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
