import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- تم الإضافة عشان نتحكم في زر الخروج
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_plus/open_file_plus.dart';

// متغير عام للتحكم في المتصفح من أي مكان (عشان زر الرجوع)
InAppWebViewController? globalBrowserController;

// تعريف الوان الهوية للتطبيق
class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color bgDark = Color(0xFF0A0E14);
  static const Color cardBg = Color(0xFF161B22);
  static const Color border = Color(0xFF30363D);
  static const Color textMain = Color(0xFFC9D1D9);
  static const Color telegramBlue = Color(0xFF229ED9);
}

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
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.bgDark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          surface: AppColors.cardBg,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.textMain, fontFamily: 'Cairo'),
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
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false), 
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgDark, AppColors.cardBg],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_fix_high_rounded, size: 100, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text("R-Plus MediaHunter", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              const CircularProgressIndicator(color: AppColors.primary),
            ],
          ),
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
    // إحاطة الشاشة بـ PopScope للتحكم في زر الرجوع
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. لو إنت في المتصفح والموقع فيه صفحة سابقة، ارجع للموقع اللي قبله
        if (_selectedIndex == 1 && globalBrowserController != null) {
          if (await globalBrowserController!.canGoBack()) {
            globalBrowserController!.goBack();
            return;
          }
        }

        // 2. لو إنت في أي قسم غير الرئيسية، ارجع للرئيسية بدل ما تقفل التطبيق
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _pageController.jumpToPage(0);
          });
          return;
        }

        // 3. لو إنت في الرئيسية ومفيش حاجة وراك، اقفل التطبيق
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.bgDark, AppColors.cardBg],
            ),
          ),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), 
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: const [
              HomePage(),
              BrowserPage(),
              DownloadsPage(),
              SettingsPage(),
            ],
          ),
        ),
        bottomNavigationBar: _buildGlassBottomNav(),
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.jumpToPage(index); 
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMain,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'المتصفح'),
          BottomNavigationBarItem(icon: Icon(Icons.download_done_rounded), label: 'التحميلات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();

  Future<void> startDownload(BuildContext context, String url, String fileName, bool isAudio) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("بدء صيد ${isAudio ? 'الصوت' : 'الفيديو'}... المرجو عدم إغلاق التطبيق"),
      backgroundColor: isAudio ? AppColors.telegramBlue : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));

    var status = await Permission.storage.request();
    if (!status.isGranted) return;

    String savePath = "/storage/emulated/0/Download/$fileName";
    
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {}
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text("اكتمل التحميل! فحص المجلد.")]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("فشل التحميل. تأكد من جودة الإنترنت وحاول مرة أخرى"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
    final ytInstance = yt.YoutubeExplode();

    try {
      if (yt.VideoId.parseVideoId(url) != null) {
        final video = await ytInstance.videos.get(url);
        final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        
        final videoStream = manifest.muxed.withHighestBitrate();
        final audioStream = manifest.audioOnly.withHighestBitrate();
        
        ytInstance.close();
        
        if (mounted) {
          _showDownloadOptionsSheet(context, video.title, videoStream.url.toString(), audioStream.url.toString());
        }
      } else {
        DownloadManager().startDownload(context, url, "hunter_download_${DateTime.now().millisecond}.mp4", false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم نتمكن من تحليل هذا الرابط. تأكد من أنه رابط فيديو عام"), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _showDownloadOptionsSheet(BuildContext context, String title, String videoUrl, String audioUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), maxLines: 2, textAlign: TextAlign.center),
            const SizedBox(height: 30),
            _buildGlassOptionCard(context, Icons.video_library_rounded, "تحميل فيديو", "MP4 جودة عالية", AppColors.primary, () {
              Navigator.pop(context);
              DownloadManager().startDownload(context, videoUrl, "${title.replaceAll(' ', '_')}.mp4", false);
            }),
            const SizedBox(height: 15),
            _buildGlassOptionCard(context, Icons.music_note_rounded, "تحميل صوت (MP3)", "صوت عالي الجودة M4A", AppColors.telegramBlue, () {
              Navigator.pop(context);
              DownloadManager().startDownload(context, audioUrl, "${title.replaceAll(' ', '_')}.mp3", true);
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassOptionCard(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)), Text(subtitle, style: const TextStyle(color: AppColors.textMain, fontSize: 12))])),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMain, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("R-Plus MediaHunter", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_fix_high_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10)],
                ),
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: "ضع رابط الفيديو هنا... (يوتيوب، وغيره)",
                    hintStyle: const TextStyle(color: AppColors.textMain),
                    prefixIcon: const Icon(Icons.link, color: AppColors.primary),
                    suffixIcon: _urlController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: AppColors.textMain), onPressed: () => setState(() => _urlController.clear())) : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                  onChanged: (text) => setState(() {}),
                ),
              ),
              const SizedBox(height: 25),
              _isAnalyzing ? const CircularProgressIndicator(color: AppColors.primary) : ElevatedButton.icon(onPressed: _analyzeUrl, icon: const Icon(Icons.zoom_in_rounded), label: const Text("اصطاد الفيديو", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
            ],
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
  double _progress = 0;
  bool _adBlockEnabled = true; 
  bool _desktopMode = false;   
  final String _initialUrl = "https://www.google.com";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("المتصفح الذكي", style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(decoration: const BoxDecoration(color: AppColors.cardBg)),
        actions: [
          _buildBrowserPopupMenu(),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1.0) LinearProgressIndicator(value: _progress, color: AppColors.primary, backgroundColor: AppColors.border),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                verticalScrollBarEnabled: true,
                horizontalScrollBarEnabled: false, 
                // الضربة الأولى للإعلانات: منع النوافذ المنبثقة اللي بتفتح فجأة
                supportMultipleWindows: false, 
                javaScriptCanOpenWindowsAutomatically: false, 
                userAgent: _desktopMode ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36" : "Mozilla/5.0 (Linux; Android 13) Chrome/116.0.0.0 Mobile Safari/537.36",
                builtInZoomControls: true, 
                displayZoomControls: false,
                supportZoom: true,
              ),
              onWebViewCreated: (controller) {
                // ربط المتصفح بالمتغير العام عشان زر الرجوع
                globalBrowserController = controller; 
                webViewController = controller;
              },
              onProgressChanged: (c, p) => setState(() => _progress = p / 100),
              onLoadStop: (controller, url) async {
                // الضربة التانية للإعلانات: حقن كود جافاسكريبت يمسح مساحة الإعلان من الموقع نفسه!
                if (_adBlockEnabled) {
                  await controller.evaluateJavascript(source: """
                    var style = document.createElement('style');
                    style.type = 'text/css';
                    style.innerHTML = '.ad, .ads, .banner, .pop-up, iframe[src*="ads"], [class*="ad-"], [id*="ad-"] { display: none !important; }';
                    document.head.appendChild(style);
                  """);
                }
              },
              shouldInterceptRequest: (controller, request) async {
                // الضربة التالتة للإعلانات: قائمة سوداء قوية جداً لسيرفرات الإعلانات
                if (_adBlockEnabled) {
                  final url = request.url.toString().toLowerCase();
                  final adHosts = ["ads", "adsystem", "popunder", "propellerads", "exoclick", "doubleclick", "analytics", "tracker", "adserver", "syndication"];
                  if (adHosts.any((host) => url.contains(host))) {
                    return WebResourceResponse(contentType: "text/plain", data: Uint8List(0));
                  }
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.primary),
      color: AppColors.cardBg,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border, width: 1)),
      onSelected: (value) async {
        switch (value) {
          case 'toggle_adblock':
            setState(() => _adBlockEnabled = !_adBlockEnabled);
            await webViewController?.reload(); 
            break;
          case 'toggle_desktop':
            setState(() => _desktopMode = !_desktopMode);
            var settings = await webViewController?.getSettings();
            settings?.userAgent = _desktopMode ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36" : "Mozilla/5.0 (Linux; Android 13) Chrome/116.0.0.0 Mobile Safari/537.36";
            if (settings != null) {
              await webViewController?.setSettings(settings: settings);
            }
            await webViewController?.reload();
            break;
          case 'close_browser':
            await webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(_initialUrl)));
            break;
        }
      },
      itemBuilder: (context) => [
        _buildPopupItem('toggle_adblock', _adBlockEnabled ? "إيقاف الإعلانات (مفعّل)" : "تشغيل الإعلانات (متوقّف)", _adBlockEnabled ? Icons.block : Icons.check_circle_outline, _adBlockEnabled ? Colors.red : Colors.green),
        const PopupMenuDivider(height: 0.5),
        _buildPopupItem('toggle_desktop', _desktopMode ? "وضع الجوال" : "سطح المكتب", Icons.desktop_mac_rounded, AppColors.telegramBlue),
        const PopupMenuDivider(height: 0.5),
        _buildPopupItem('close_browser', "أغلق المتصفح", Icons.close_rounded, Colors.white),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String text, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 10), Text(text, style: TextStyle(color: value == 'close_browser' ? Colors.white : AppColors.textMain))]),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }
  
  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final dir = Directory("/storage/emulated/0/Download");
    if (!await dir.exists()) {
      setState(() => _isLoading = false);
      return;
    }
    
    final List<FileSystemEntity> allFiles = dir.listSync();
    setState(() {
      _files = allFiles.where((f) {
        return f.path.endsWith(".mp4") || f.path.endsWith(".mp3") || f.path.endsWith(". Hunter_");
      }).toList();
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("التحميلات الخاصة بي", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, centerTitle: true),
      body: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : _files.isEmpty ? _buildEmptyState() : _buildFilesList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_collection_rounded, size: 100, color: AppColors.border), SizedBox(height: 20), Text("لا توجد تحميلات حتى الآن", style: TextStyle(fontSize: 18, color: AppColors.textMain))]));
  }

  Widget _buildFilesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: _files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = _files[index];
        final isVideo = file.path.endsWith(".mp4");
        return Card(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border, width: 0.5)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isVideo ? AppColors.primary : AppColors.telegramBlue).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isVideo ? Icons.movie_rounded : Icons.music_note_rounded, color: isVideo ? AppColors.primary : AppColors.telegramBlue, size: 28)),
            title: Text(file.path.split('/').last, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () async {
              await OpenFile.open(file.path);
            },
            trailing: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () async {
              await file.delete();
              _loadFiles();
            }),
          ),
        );
      },
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
  
  Future<void> _launchTelegram() async {
    final Uri url = Uri.parse("https://t.me/Radwan263");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم نتمكن من فتح تليجرام. تأكد من تثبيت التطبيق")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          SwitchListTile(title: const Text("قفل التطبيق (بصمة الإصبع)"), subtitle: const Text("حماية خصوصيتك وتحميلاتك"), value: _isLocked, onChanged: _toggleLock, secondary: const Icon(Icons.fingerprint), activeColor: AppColors.primary, activeTrackColor: AppColors.primary.withOpacity(0.3), tileColor: AppColors.cardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
          const SizedBox(height: 25),
          const Divider(color: AppColors.border),
          const SizedBox(height: 25),
          
          const Text("حول التطبيق والمطور", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          Card(
            color: AppColors.cardBg,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border, width: 0.5)),
            child: Column(
              children: [
                const ListTile(title: Text("اسم المطور", style: TextStyle(color: AppColors.textMain)), trailing: Text("Radwan Mohamed", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)), leading: Icon(Icons.person_rounded, color: AppColors.primary)),
                const PopupMenuDivider(height: 0.5),
                ListTile(title: const Text("تليجرام المطور (اضغط للتواصل)", style: TextStyle(color: AppColors.textMain)), trailing: const Text("@Radwan263", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.telegramBlue, fontSize: 16)), leading: Container(width: 28, height: 28, decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/d/dd/Telegram_logo.svg")), color: Colors.transparent)), onTap: _launchTelegram), 
                const PopupMenuDivider(height: 0.5),
                const ListTile(title: Text("نسخة التطبيق", style: TextStyle(color: AppColors.textMain)), trailing: Text("v1.1.0 Stable", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), leading: Icon(Icons.info_outline_rounded, color: AppColors.textMain)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

