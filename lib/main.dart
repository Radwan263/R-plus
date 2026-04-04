import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  runApp(const RMediaHunterApp());
}

class RMediaHunterApp extends StatelessWidget {
  const RMediaHunterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'R-Plus MediaHunter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFF0A0E14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
          surface: const Color(0xFF161B22),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
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
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1117), Color(0xFF010409)],
          ),
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            const HomePage(),
            const BrowserPage(),
            const DownloadsPage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildGlassBottomNav(),
    );
  }

  Widget _buildGlassBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              _pageController.animateToPage(index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.blueAccent,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'المتصفح'),
              BottomNavigationBarItem(icon: Icon(Icons.download_done_rounded), label: 'التحميلات'),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// شاشة الرئيسية (Home)
// -----------------------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isAnalyzing = false;

  Future<void> _analyzeUrl() async {
    String url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSmartSnackBar("يرجى إدخال رابط أولاً", Icons.warning_amber_rounded, Colors.orange);
      return;
    }

    setState(() => _isAnalyzing = true);
    try {
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        final ytInstance = yt.YoutubeExplode();
        final video = await ytInstance.videos.get(url);
        final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        final streamInfo = manifest.muxed.withHighestBitrate();
        ytInstance.close();
        _showDownloadSheet(video.title, streamInfo.url.toString(), "YouTube");
      } else {
        // محرك تحليل عام للسوشيال ميديا
        _showSmartSnackBar("جاري البحث عن الفيديو...", Icons.search, Colors.blue);
        // هنا يمكن إضافة TikWM API أو غيرها مستقبلاً
        _showDownloadSheet("فيديو مكتشف", url, "Social Media");
      }
    } catch (e) {
      _showSmartSnackBar("فشل التحليل: تأكد من الرابط", Icons.error_outline, Colors.red);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showSmartSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  void _showDownloadSheet(String title, String downloadUrl, String source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 2),
            const SizedBox(height: 10),
            Text("المصدر: $source", style: const TextStyle(color: Colors.blueAccent)),
            const SizedBox(height: 30),
            _buildActionButton("تحميل الفيديو (MP4)", Icons.movie_creation_rounded, Colors.blueAccent, () => _startDownload(title, downloadUrl)),
            const SizedBox(height: 12),
            _buildActionButton("تحميل صوت (MP3)", Icons.audiotrack_rounded, Colors.orangeAccent, () {}),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Future<void> _startDownload(String title, String url) async {
    Navigator.pop(context);
    _showSmartSnackBar("بدأ التحميل الآن...", Icons.downloading, Colors.green);
    // منطق التحميل باستخدام Dio سيتم هنا
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.auto_fix_high_rounded, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 20),
          const Text("R-Plus MediaHunter", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const Text("صائد الفيديوهات الذكي", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 50),
          _buildGlassInput(),
          const SizedBox(height: 25),
          _isAnalyzing 
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _analyzeUrl,
                icon: const Icon(Icons.bolt_rounded),
                label: const Text("تحليل الرابط الآن"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildGlassInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _urlController,
        decoration: const InputDecoration(
          hintText: "ضع رابط الفيديو هنا...",
          prefixIcon: Icon(Icons.link_rounded, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// شاشة المتصفح (Browser) - حل فيسبوك الجذري
// -----------------------------------------------------------------------------
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  double _progress = 0;
  final TextEditingController _searchController = TextEditingController(text: "https://www.google.com");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildGlassSearchBar(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => webViewController?.reload()),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0)
            LinearProgressIndicator(value: _progress, color: Colors.blueAccent, backgroundColor: Colors.transparent, minHeight: 2),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                useShouldInterceptAjaxRequest: true,
                useShouldInterceptFetchRequest: true,
                // حل فيسبوك: User-Agent وهمي قوي
                userAgent: "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36",
                transparentBackground: false,
                safeBrowsingEnabled: true,
                hardwareAcceleration: true,
              ),
              onWebViewCreated: (controller) => webViewController = controller,
              onProgressChanged: (controller, progress) => setState(() => _progress = progress / 100),
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;
                // منع الروابط غير المعروفة (مثل fb://)
                if (!["http", "https", "file", "chrome", "data", "javascript", "about"].contains(uri.scheme)) {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onReceivedError: (controller, request, error) {
                // تجاهل أخطاء الـ Scheme غير المعروفة
                if (error.description.contains("ERR_UNKNOWN_URL_SCHEME")) return;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: const InputDecoration(
          hintText: "ابحث أو أدخل عنواناً...",
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onSubmitted: (val) {
          var url = val.trim();
          if (!url.startsWith("http")) url = "https://www.google.com/search?q=$url";
          webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// شاشة التحميلات (Downloads) - الحالات الفارغة
// -----------------------------------------------------------------------------
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    List downloads = []; // مثال لقائمة فارغة

    return Scaffold(
      appBar: AppBar(title: const Text("التحميلات المنتهية"), backgroundColor: Colors.transparent),
      body: downloads.isEmpty 
        ? _buildEmptyState()
        : ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) => ListTile(title: Text("فيديو $index")),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 100, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text("لا توجد تحميلات حالياً..", style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("ابدأ بصيد الفيديوهات الآن!", style: TextStyle(color: Colors.blueAccent)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// مكونات واجهة مستخدم إضافية (UI Components)
// -----------------------------------------------------------------------------
class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withOpacity(0.85),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: child,
        ),
      ),
    );
  }
}
