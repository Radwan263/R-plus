import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_plus/open_file_plus.dart';

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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLocked = prefs.getBool('app_lock') ?? false;
    if (isLocked) {
      try {
        bool authenticated = await auth.authenticate(
          localizedReason: 'يرجى المصادقة لفتح تطبيق R-Plus',
          options: const AuthenticationOptions(stickyAuth: true), 
        );
        if (authenticated) _goMain();
      } catch (e) {
        _goMain(); 
      }
    } else {
      Future.delayed(const Duration(seconds: 2), _goMain);
    }
  }

  void _goMain() {
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high_rounded, size: 100, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text("R-Plus MediaHunter", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const CircularProgressIndicator(color: Colors.blueAccent),
          ],
        ),
      ),
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
            const SettingsPage(),
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
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'المتصفح'),
              BottomNavigationBarItem(icon: Icon(Icons.download_done_rounded), label: 'التحميلات'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();
  final Map<String, CancelToken> _activeDownloads = {};
  final Map<String, double> _progressMap = {};

  Future<void> startDownload(String url, String fileName, Function(double) onProgress, Function() onComplete) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath = "${dir.path}/$fileName";
    final cancelToken = CancelToken();
    _activeDownloads[url] = cancelToken;
    try {
      await _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            double progress = received / total;
            _progressMap[url] = progress;
            onProgress(progress);
          }
        },
      );
      _activeDownloads.remove(url);
      onComplete();
    } catch (e) {
      _activeDownloads.remove(url);
      rethrow;
    }
  }
  void cancelDownload(String url) {
    _activeDownloads[url]?.cancel();
    _activeDownloads.remove(url);
  }
}

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
    if (url.isEmpty) return;
    setState(() => _isAnalyzing = true);
    try {
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        final ytInstance = yt.YoutubeExplode();
        final video = await ytInstance.videos.get(url);
        final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        final streamInfo = manifest.muxed.withHighestBitrate();
        ytInstance.close();
        _showDownloadSheet(video.title, streamInfo.url.toString());
      } else {
        _showDownloadSheet("فيديو من السوشيال ميديا", url);
      }
    } catch (e) {
      _showSmartSnackBar("فشل التحليل", Icons.error, Colors.red);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showDownloadSheet(String title, String downloadUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GlassSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startDownload(title, downloadUrl);
              },
              child: const Text("بدء التحميل"),
            ),
          ],
        ),
      ),
    );
  }

  void _startDownload(String title, String url) {
    DownloadManager().startDownload(url, "${title.replaceAll(' ', '_')}.mp4", (p) {}, () {
      _showSmartSnackBar("اكتمل التحميل!", Icons.check_circle, Colors.green);
    });
  }

  void _showSmartSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 10), Text(message)]), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_fix_high_rounded, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 40),
            _buildGlassInput(),
            const SizedBox(height: 20),
            _isAnalyzing ? const CircularProgressIndicator() : ElevatedButton(onPressed: _analyzeUrl, child: const Text("صيد الفيديو")),
          ],
        ),
      ),
    );
  }
  Widget _buildGlassInput() {
    return Container(decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: TextField(controller: _urlController, decoration: const InputDecoration(hintText: "ضع الرابط هنا", border: InputBorder.none, contentPadding: EdgeInsets.all(15))));
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});
  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  double _progress = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text("المتصفح الذكي")),
      body: Column(
        children: [
          if (_progress < 1.0) LinearProgressIndicator(value: _progress),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
              initialSettings: InAppWebViewSettings(javaScriptEnabled: true, userAgent: "Mozilla/5.0 (Linux; Android 13) Chrome/116.0.0.0 Mobile Safari/537.36"),
              onWebViewCreated: (controller) => webViewController = controller,
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
              shouldInterceptRequest: (controller, request) async {
                final url = request.url.toString();
                if (url.contains("ads") || url.contains("doubleclick") || url.contains("pop-under")) {
                  return WebResourceResponse(contentType: "text/plain", data: Uint8List(0));
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  List<FileSystemEntity> _files = [];
  @override
  void initState() {
    super.initState();
    _loadFiles();
  }
  
  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    setState(() { _files = dir.listSync().where((f) => f.path.endsWith(".mp4")).toList(); });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("التحميلات"), backgroundColor: Colors.transparent),
      body: _files.isEmpty ? const Center(child: Text("لا توجد تحميلات")) : ListView.builder(
            itemCount: _files.length,
            itemBuilder: (context, index) {
              final file = _files[index];
              return ListTile(
                leading: const Icon(Icons.video_library_rounded),
                title: Text(file.path.split('/').last),
                onTap: () {
                  // فتح الفيديو بمشغل الموبايل الأساسي
                  OpenFilePlus.open(file.path);
                },
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { file.deleteSync(); _loadFiles(); }),
              );
            },
          ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLocked = false;
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isLocked = prefs.getBool('app_lock') ?? false);
  }
  Future<void> _toggleLock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock', val);
    setState(() => _isLocked = val);
  }
  Future<void> _checkUpdate() async {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("تحديث جديد متاح!"), content: const Text("نسخة v1.2.0 متوفرة الآن على GitHub. هل تريد التحديث؟"), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("لاحقاً")), ElevatedButton(onPressed: () => launchUrl(Uri.parse("https://github.com/Radwan263/R-plus/releases")), child: const Text("تحديث الآن"))]));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات"), backgroundColor: Colors.transparent),
      body: ListView(
        children: [
          SwitchListTile(title: const Text("قفل التطبيق (بصمة الإصبع)"), subtitle: const Text("حماية خصوصيتك وتحميلاتك"), value: _isLocked, onChanged: _toggleLock, secondary: const Icon(Icons.fingerprint)),
          ListTile(title: const Text("التحقق من التحديثات"), subtitle: const Text("نسخة التطبيق v1.1.0"), leading: const Icon(Icons.system_update_rounded), onTap: _checkUpdate),
          const Divider(),
          ListTile(title: const Text("عن المطور"), subtitle: const Text("Radwan - R-Plus Hunter"), leading: const Icon(Icons.info_outline_rounded)),
        ],
      ),
    );
  }
}

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(24), decoration: const BoxDecoration(color: Color(0xFF161B22), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), child: child);
  }
}

