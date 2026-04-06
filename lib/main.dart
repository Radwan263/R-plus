import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file_plus/open_file_plus.dart';

// متغيرات عامة للتحكم السريع
InAppWebViewController? globalBrowserController;
final GlobalKey<DownloadsPageState> globalDownloadsKey = GlobalKey(); 

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
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bgDark, AppColors.cardBg]),
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
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_selectedIndex == 1 && globalBrowserController != null) {
          if (await globalBrowserController!.canGoBack()) {
            globalBrowserController!.goBack();
            return;
          }
        }
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
            _pageController.jumpToPage(0);
          });
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.bgDark, AppColors.cardBg])),
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), 
            onPageChanged: (index) => setState(() => _selectedIndex = index),
            children: [
              const HomePage(),
              const BrowserPage(),
              DownloadsPage(key: globalDownloadsKey),
              const SettingsPage(),
            ],
          ),
        ),
        bottomNavigationBar: _buildGlassBottomNav(),
      ),
    );
  }

  Widget _buildGlassBottomNav() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.cardBg, border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.jumpToPage(index); 
          if (index == 2) {
            globalDownloadsKey.currentState?.loadFiles();
          }
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

// -----------------------------------------------------------------------------
// مدير التحميلات الذكي
// -----------------------------------------------------------------------------
class ActiveDownload {
  final String url;
  final String fileName;
  double progress;
  ActiveDownload({required this.url, required this.fileName, this.progress = 0.0});
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();

  final ValueNotifier<List<ActiveDownload>> activeDownloadsNotifier = ValueNotifier([]);
  VoidCallback? onDownloadComplete;

  Future<void> startDownload(BuildContext context, String url, String fileName, bool isAudio) async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      await Permission.videos.request();
      await Permission.audio.request();
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("بدأ تحميل: $fileName\nراجع قسم التحميلات"),
      backgroundColor: isAudio ? AppColors.telegramBlue : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));

    String savePath = "/storage/emulated/0/Download/$fileName";
    ActiveDownload activeDl = ActiveDownload(url: url, fileName: fileName);
    activeDownloadsNotifier.value = [...activeDownloadsNotifier.value, activeDl];
    
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            activeDl.progress = received / total;
            activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
          }
        },
      );

      activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => d.url != url).toList();
      onDownloadComplete?.call(); 
      globalDownloadsKey.currentState?.loadFiles(); 

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text("اكتمل التحميل بنجاح!")]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => d.url != url).toList();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("فشل التحميل. تأكد من جودة الإنترنت أو مساحة الجهاز"),
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
        DownloadManager().startDownload(context, url, "Video_Playback_${DateTime.now().millisecond}.mp4", false);
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
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white), maxLines: 2, textAlign: TextAlign.center),
            const SizedBox(height: 30),
            _buildGlassOptionCard(context, Icons.video_library_rounded, "تحميل فيديو", "MP4 جودة عالية", AppColors.primary, () {
              Navigator.pop(context);
              String safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
              DownloadManager().startDownload(context, videoUrl, "$safeName.mp4", false);
            }),
            const SizedBox(height: 15),
            _buildGlassOptionCard(context, Icons.music_note_rounded, "تحميل صوت (MP3)", "صوت عالي الجودة M4A", AppColors.telegramBlue, () {
              Navigator.pop(context);
              String safeName = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ');
              DownloadManager().startDownload(context, audioUrl, "$safeName.mp3", true);
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
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border, width: 0.5)),
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
                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.05), blurRadius: 10)]),
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

// -----------------------------------------------------------------------------
// المتصفح الذكي 
// -----------------------------------------------------------------------------
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
  final TextEditingController _urlController = TextEditingController(text: "https://www.google.com");
  
  Map<String, Map<String, String>> _sniffedLinks = {}; 

  Future<void> _addSniffedLink(String url) async {
    if (!_sniffedLinks.containsKey(url)) {
      String pageTitle = await webViewController?.getTitle() ?? "";
      if (pageTitle.isEmpty || pageTitle == "null") pageTitle = "Video_Playback";
      pageTitle = pageTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
      
      if (mounted) {
        setState(() {
          _sniffedLinks[url] = {"title": pageTitle, "size": "يتم حساب الحجم..."};
        });
      }

      try {
        var response = await Dio().head(url);
        var length = response.headers.value(HttpHeaders.contentLengthHeader) ?? response.headers.value('content-length');
        if (length != null) {
          double sizeInMb = int.parse(length) / (1024 * 1024);
          if (mounted) {
            setState(() {
              _sniffedLinks[url] = {"title": pageTitle, "size": "${sizeInMb.toStringAsFixed(1)} MB"};
            });
          }
        } else {
          if (mounted) setState(() => _sniffedLinks[url] = {"title": pageTitle, "size": "حجم غير معروف"});
        }
      } catch (e) {
        if (mounted) setState(() => _sniffedLinks[url] = {"title": pageTitle, "size": "حجم غير معروف"});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(
          backgroundColor: AppColors.cardBg,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.home_rounded, color: AppColors.primary), onPressed: () => webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com")))),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 14),
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (value) {
                          var url = value.startsWith("http") ? value : "https://www.google.com/search?q=$value";
                          webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
                        },
                        decoration: const InputDecoration(hintText: "ابحث أو أدخل رابطاً...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10)),
                      ),
                    ),
                  ),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      IconButton(icon: const Icon(Icons.download_for_offline_rounded, size: 28, color: AppColors.textMain), onPressed: _showSniffedLinksSheet),
                      if (_sniffedLinks.isNotEmpty)
                        Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${_sniffedLinks.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
                    ],
                  ),
                  _buildBrowserPopupMenu(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_progress < 1.0) LinearProgressIndicator(value: _progress, color: AppColors.primary, backgroundColor: AppColors.cardBg, minHeight: 3),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                verticalScrollBarEnabled: true,
                supportMultipleWindows: false, 
                javaScriptCanOpenWindowsAutomatically: false,
                userAgent: _desktopMode ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36" : "Mozilla/5.0 (Linux; Android 13) Chrome/116.0.0.0 Mobile Safari/537.36",
              ),
              onWebViewCreated: (controller) {
                globalBrowserController = controller; 
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() { _urlController.text = url.toString(); _sniffedLinks.clear(); });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                setState(() => _urlController.text = url.toString());
              },
              onLoadStop: (controller, url) async {
                if (_adBlockEnabled) {
                  await controller.evaluateJavascript(source: "var style = document.createElement('style'); style.type = 'text/css'; style.innerHTML = '.ad, .ads, .banner, .pop-up, iframe[src*=\"ads\"], [class*=\"ad-\"], [id*=\"ad-\"] { display: none !important; }'; document.head.appendChild(style);");
                }
              },
              onProgressChanged: (controller, progress) async {
                setState(() => _progress = progress / 100);
                if (progress == 100) {
                  var result = await controller.evaluateJavascript(source: "(function() { var media = document.querySelectorAll('video, audio, source'); var urls = []; for(var i=0; i<media.length; i++) { if(media[i].src && media[i].src.startsWith('http')) urls.push(media[i].src); } return urls.join(','); })();");
                  if (result != null && result.toString().isNotEmpty) {
                    List<String> urls = result.toString().split(',');
                    for(var u in urls) { if(_isMediaUrl(u)) _addSniffedLink(u); }
                  }
                }
              },
              shouldInterceptRequest: (controller, request) async {
                final url = request.url.toString().toLowerCase();
                if (_adBlockEnabled) {
                  final adHosts = ["ads", "adsystem", "popunder", "propellerads", "exoclick", "doubleclick", "analytics", "tracker", "syndication", "adserver"];
                  if (adHosts.any((host) => url.contains(host))) return WebResourceResponse(contentType: "text/plain", data: Uint8List(0));
                }
                if (_isMediaUrl(url)) {
                  Future.microtask(() => _addSniffedLink(request.url.toString()));
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isMediaUrl(String url) {
    return url.contains(".mp4") || url.contains(".m3u8") || url.contains(".webm") || url.contains(".mp3") || url.contains(".m4a") || url.contains(".ts");
  }

  void _showSniffedLinksSheet() {
    if (_sniffedLinks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم يتم التقاط أي روابط ميديا في هذه الصفحة بعد.")));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.vertical(top: Radius.circular(25)), border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.radar_rounded, color: AppColors.primary), const SizedBox(width: 10), Text("تم اصطياد ${_sniffedLinks.length} ملف", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white))]),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _sniffedLinks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  String link = _sniffedLinks.keys.elementAt(index);
                  var data = _sniffedLinks[link]!;
                  String rawTitle = data["title"] ?? "Video_Playback";
                  String sizeStr = data["size"] ?? "حجم غير معروف";
                  bool isAudio = link.toLowerCase().contains(".mp3") || link.toLowerCase().contains(".m4a");
                  
                  return Container(
                    decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.border)),
                    child: ListTile(
                      leading: Icon(isAudio ? Icons.music_note : Icons.movie, color: isAudio ? AppColors.telegramBlue : AppColors.primary),
                      title: Text(rawTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("${isAudio ? 'ملف صوتي' : 'ملف فيديو'} • $sizeStr", style: const TextStyle(color: AppColors.textMain, fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          Navigator.pop(context);
                          String ext = isAudio ? ".mp3" : ".mp4";
                          if (rawTitle.length > 40) rawTitle = rawTitle.substring(0, 40);
                          String fileName = "$rawTitle - ${DateTime.now().millisecondsSinceEpoch}$ext";
                          
                          DownloadManager().startDownload(context, link, fileName, isAudio);
                        },
                        child: const Text("تحميل", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
            if (settings != null) await webViewController?.setSettings(settings: settings);
            await webViewController?.reload();
            break;
          case 'clear_sniffer':
            setState(() => _sniffedLinks.clear());
            break;
          case 'close_browser':
            await webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com")));
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'toggle_adblock', child: Row(children: [Icon(_adBlockEnabled ? Icons.block : Icons.check_circle_outline, color: _adBlockEnabled ? Colors.red : Colors.green, size: 20), const SizedBox(width: 10), Text(_adBlockEnabled ? "إيقاف الإعلانات (مفعّل)" : "تشغيل الإعلانات (متوقّف)", style: const TextStyle(color: AppColors.textMain))])),
        const PopupMenuDivider(height: 0.5),
        PopupMenuItem(value: 'toggle_desktop', child: Row(children: [const Icon(Icons.desktop_mac_rounded, color: AppColors.telegramBlue, size: 20), const SizedBox(width: 10), Text(_desktopMode ? "وضع الجوال" : "سطح المكتب", style: const TextStyle(color: AppColors.textMain))])),
        const PopupMenuDivider(height: 0.5),
        PopupMenuItem(value: 'clear_sniffer', child: Row(children: [const Icon(Icons.cleaning_services_rounded, color: Colors.orange, size: 20), const SizedBox(width: 10), const Text("مسح الروابط المصطادة", style: TextStyle(color: AppColors.textMain))])),
        const PopupMenuDivider(height: 0.5),
        PopupMenuItem(value: 'close_browser', child: Row(children: [const Icon(Icons.close_rounded, color: Colors.white, size: 20), const SizedBox(width: 10), const Text("الرجوع لـ Google", style: TextStyle(color: Colors.white))])),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// شاشة التحميلات بتعديل toLowerCase والامتدادات الشاملة
// -----------------------------------------------------------------------------
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => DownloadsPageState();
}

class DownloadsPageState extends State<DownloadsPage> {
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadFiles();
    DownloadManager().onDownloadComplete = loadFiles;
  }
  
  Future<void> loadFiles() async {
    setState(() => _isLoading = true);
    final dir = Directory("/storage/emulated/0/Download");
    if (!await dir.exists()) {
      setState(() => _isLoading = false);
      return;
    }
    
    final List<FileSystemEntity> allFiles = dir.listSync();
    setState(() {
      _files = allFiles.where((f) {
        String path = f.path.toLowerCase();
        return path.endsWith(".mp4") || 
               path.endsWith(".mp3") || 
               path.endsWith(".webm") || 
               path.endsWith(".mkv") || 
               path.endsWith(".m4a") || 
               path.endsWith(".avi") || 
               path.endsWith(".mov") || 
               path.endsWith(".ts");
      }).toList();
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("التحميلات الخاصة بي", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, centerTitle: true),
      body: Column(
        children: [
          ValueListenableBuilder<List<ActiveDownload>>(
            valueListenable: DownloadManager().activeDownloadsNotifier,
            builder: (context, activeList, child) {
              if (activeList.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("جاري التحميل...", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...activeList.map((dl) => Card(
                      color: AppColors.cardBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.primary, width: 1)),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dl.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: dl.progress, backgroundColor: AppColors.border, color: AppColors.primary, borderRadius: BorderRadius.circular(5), minHeight: 8),
                            const SizedBox(height: 5),
                            Align(alignment: Alignment.centerLeft, child: Text("${(dl.progress * 100).toStringAsFixed(1)} %", style: const TextStyle(color: AppColors.textMain, fontSize: 12))),
                          ],
                        ),
                      ),
                    )),
                    const Divider(color: AppColors.border, height: 30),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator(color: AppColors.primary)) : _files.isEmpty ? _buildEmptyState() : _buildFilesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.video_collection_rounded, size: 100, color: AppColors.border), SizedBox(height: 20), Text("لا توجد ملفات مكتملة", style: TextStyle(fontSize: 18, color: AppColors.textMain))]));
  }

  Widget _buildFilesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: _files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final file = _files[index];
        final path = file.path.toLowerCase();
        final isAudio = path.endsWith(".mp3") || path.endsWith(".m4a");
        return Card(
          color: AppColors.cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.border, width: 0.5)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isAudio ? AppColors.telegramBlue : AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(isAudio ? Icons.music_note_rounded : Icons.movie_rounded, color: isAudio ? AppColors.telegramBlue : AppColors.primary, size: 28)),
            title: Text(file.path.split('/').last, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () async { await OpenFile.open(file.path); },
            trailing: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () async { await file.delete(); loadFiles(); }),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لم نتمكن من فتح تليجرام.")));
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

