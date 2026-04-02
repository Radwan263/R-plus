import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:http/http.dart' as http;

void main() {
  runApp(const RCimaApp());
}

class RCimaApp extends StatelessWidget {
  const RCimaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R Cima Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.blue, scaffoldBackgroundColor: const Color(0xFF121212), useMaterial3: true),
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
  String lastAnalyzedTitle = "جاري التحليل...";
  String lastAnalyzedSize = "0 MB";
  
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
// شاشة الرئيسية مع محرك التحليل الذكي
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

  // المحرك الذكي لتحليل الروابط
  Future<void> _analyzeUrl(String url) async {
    setState(() => _isLoading = true);
    try {
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        var ytInstance = yt.YoutubeExplode();
        var video = await ytInstance.videos.get(url);
        var manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        var size = manifest.muxed.bestQuality.size.totalMegaBytes.toStringAsFixed(2);
        _showDownloadSheet(video.title, "$size MB", isYoutube: true);
        ytInstance.close();
      } else {
        // للمواقع الأخرى (فيسبوك، تيك توك، روابط مباشرة)
        var response = await http.head(Uri.parse(url));
        var sizeBytes = int.tryParse(response.headers['content-length'] ?? "0") ?? 0;
        var sizeMB = (sizeBytes / (1024 * 1024)).toStringAsFixed(2);
        var contentType = response.headers['content-type'] ?? "";
        _showDownloadSheet("ملف فيديو مكتشف", "$sizeMB MB", isYoutube: false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("فشل التحليل: تأكد من الرابط")));
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
                decoration: InputDecoration(hintText: "الزق الرابط هنا...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              ),
              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator()
              else ElevatedButton(
                onPressed: () => _analyzeUrl(_urlController.text),
                child: const Text("تحليل الرابط الذكي"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// شاشة المتصفح المحسنة
// ----------------------------------------------------
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("المتصفح"), backgroundColor: const Color(0xFF1E1E1E)),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
        onWebViewCreated: (controller) => webViewController = controller,
        initialSettings: InAppWebViewSettings(javaScriptEnabled: true, allowsInlineMediaPlayback: true),
      ),
    );
  }
}

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("قائمة التحميلات تظهر هنا")));
}

