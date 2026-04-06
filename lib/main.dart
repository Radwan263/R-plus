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

// -----------------------------------------------------------------------------
// صياد الأخطاء العالمي (Error Hunter System)
// -----------------------------------------------------------------------------
class ErrorHunter {
  static final ValueNotifier<String> lastError = ValueNotifier("لا توجد أخطاء مسجلة حالياً");
  
  static void log(String context, dynamic error) {
    String msg = "[$context] ${error.toString()}";
    print(msg); // للظهور في سجل السيرفر
    lastError.value = "${DateTime.now().hour}:${DateTime.now().minute} -> $msg";
  }

  static void showLast(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تقرير صياد الأخطاء 🕵️"),
        content: Text(lastError.value),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تم")),
          TextButton(onPressed: () { lastError.value = "تم المسح"; Navigator.pop(ctx); }, child: const Text("مسح السجل")),
        ],
      ),
    );
  }
}

// متغيرات عامة
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
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    runApp(const RMediaHunterApp());
  }, (error, stack) {
    ErrorHunter.log("Global_Crash", error);
  });
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark, surface: AppColors.cardBg),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: AppColors.textMain, fontFamily: 'Cairo')),
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const SplashScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// شاشة البداية
// -----------------------------------------------------------------------------
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
    try {
      final prefs = await SharedPreferences.getInstance();
      bool isLocked = prefs.getBool('app_lock') ?? false;
      if (isLocked) {
        bool authenticated = await auth.authenticate(
          localizedReason: 'يرجى المصادقة لفتح تطبيق R-Plus',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false), 
        );
        if (authenticated) _goMain();
      } else {
        Future.delayed(const Duration(seconds: 2), _goMain);
      }
    } catch (e) {
      ErrorHunter.log("Security_Check", e);
      _goMain(); 
    }
  }

  void _goMain() {
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.bgDark, AppColors.cardBg])),
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
          setState(() { _selectedIndex = 0; _pageController.jumpToPage(0); });
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: PageView(
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
          if (index == 2) globalDownloadsKey.currentState?.loadFiles();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMain,
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
// مدير التحميلات مع "صياد الأخطاء"
// -----------------------------------------------------------------------------
class ActiveDownload {
  final String url;
  final String fileName;
  double progress;
  String size;
  ActiveDownload({required this.url, required this.fileName, this.progress = 0.0, this.size = "..."});
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();
  final ValueNotifier<List<ActiveDownload>> activeDownloadsNotifier = ValueNotifier([]);

  Future<void> startDownload(BuildContext context, String url, String fileName, bool isAudio) async {
    try {
      if (Platform.isAndroid) {
        await Permission.manageExternalStorage.request();
        await Permission.storage.request();
      }

      final String baseDir = "/storage/emulated/0/Download/R_Hunter";
      final Directory rHunterDir = Directory(baseDir);
      if (!await rHunterDir.exists()) {
        await rHunterDir.create(recursive: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("بدأ صيد $fileName"),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ));

      String savePath = "$baseDir/$fileName";
      ActiveDownload activeDl = ActiveDownload(url: url, fileName: fileName);
      activeDownloadsNotifier.value = [...activeDownloadsNotifier.value, activeDl];
      
      await _dio.download(url, savePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          activeDl.progress = received / total;
          activeDl.size = "${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB";
          activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
        }
      });
      
      activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => d.url != url).toList();
      globalDownloadsKey.currentState?.loadFiles(); 
    } catch (e) {
      ErrorHunter.log("Downloader", e);
      activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => d.url != url).toList();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل التحميل. تفقد صياد الأخطاء"), backgroundColor: Colors.red));
      }
    }
  }
}

// -----------------------------------------------------------------------------
// الشاشات الرئيسية
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
    if (url.isEmpty) return;
    setState(() => _isAnalyzing = true);
    final ytInstance = yt.YoutubeExplode();
    try {
      if (yt.VideoId.parseVideoId(url) != null) {
        final video = await ytInstance.videos.get(url);
        final manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        final vStream = manifest.muxed.withHighestBitrate();
        final aStream = manifest.audioOnly.withHighestBitrate();
        ytInstance.close();
        if (mounted) _showOptions(context, video.title, vStream.url.toString(), aStream.url.toString());
      } else {
        DownloadManager().startDownload(context, url, "Hunter_Media_${DateTime.now().millisecond}.mp4", false);
      }
    } catch (e) {
      ErrorHunter.log("YouTube_Analyzer", e);
    } finally { setState(() => _isAnalyzing = false); }
  }

  void _showOptions(BuildContext context, String title, String vUrl, String aUrl) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), onPressed: () {
          Navigator.pop(context);
          DownloadManager().startDownload(context, vUrl, "${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')}.mp4", false);
        }, child: const Text("تحميل فيديو MP4")),
        const SizedBox(height: 10),
        ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), onPressed: () {
          Navigator.pop(context);
          DownloadManager().startDownload(context, aUrl, "${title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')}.mp3", true);
        }, child: const Text("تحميل صوت MP3")),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("R-Plus Hunter"), centerTitle: true, backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.auto_fix_high_rounded, size: 80, color: AppColors.primary),
          const SizedBox(height: 40),
          TextField(controller: _urlController, decoration: InputDecoration(hintText: "ضع الرابط هنا...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
          const SizedBox(height: 20),
          _isAnalyzing ? const CircularProgressIndicator() : ElevatedButton(onPressed: _analyzeUrl, child: const Text("اصطياد"))
        ]),
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
  final TextEditingController _urlController = TextEditingController(text: "https://www.google.com");
  Map<String, Map<String, String>> _sniffedLinks = {}; 

  Future<void> _addSniffed(String url) async {
    if (!_sniffedLinks.containsKey(url)) {
      try {
        String title = await webViewController?.getTitle() ?? "Video_Playback";
        title = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
        if (mounted) setState(() => _sniffedLinks[url] = {"title": title, "size": "حساب..."});
        
        var res = await Dio().head(url);
        var len = res.headers.value('content-length');
        if (len != null) {
          double mb = int.parse(len) / (1024 * 1024);
          if (mounted) setState(() => _sniffedLinks[url]!["size"] = "${mb.toStringAsFixed(1)} MB");
        }
      } catch (e) {
        ErrorHunter.log("Sniffer_Info", e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: AppBar(backgroundColor: AppColors.cardBg, elevation: 0, flexibleSpace: SafeArea(child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.home, color: AppColors.primary), onPressed: () => webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri("https://www.google.com")))),
            Expanded(child: Container(decoration: BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.circular(20)), child: TextField(controller: _urlController, onSubmitted: (v) {
              var u = v.startsWith("http") ? v : "https://www.google.com/search?q=$v";
              webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
            }, decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15))))),
            Stack(alignment: Alignment.topRight, children: [
              IconButton(icon: const Icon(Icons.download_for_offline, size: 28), onPressed: _showSheet),
              if (_sniffedLinks.isNotEmpty) CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Text('${_sniffedLinks.length}', style: const TextStyle(fontSize: 10, color: Colors.white)))
            ]),
          ]),
        ))),
      ),
      body: Column(children: [
        if (_progress < 1.0) LinearProgressIndicator(value: _progress),
        Expanded(child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri("https://www.google.com")),
          onWebViewCreated: (c) { globalBrowserController = c; webViewController = c; },
          onLoadStart: (c, u) { setState(() { _urlController.text = u.toString(); _sniffedLinks.clear(); }); },
          onProgressChanged: (c, p) async {
            setState(() => _progress = p / 100);
            if (p == 100) {
              var res = await c.evaluateJavascript(source: "(function(){ var m=document.querySelectorAll('video,audio,source'); var u=[]; for(var i=0;i<m.length;i++){if(m[i].src && m[i].src.startsWith('http'))u.push(m[i].src);}return u.join(','); })();");
              if (res != null && res.isNotEmpty) { for(var s in res.split(',')) { if(s.contains(".mp4") || s.contains(".mp3") || s.contains(".m3u8")) _addSniffed(s); } }
            }
          },
          shouldInterceptRequest: (c, r) async {
            final u = r.url.toString().toLowerCase();
            if (u.contains(".mp4") || u.contains(".mp3") || u.contains(".ts")) { Future.microtask(() => _addSniffed(r.url.toString())); }
            return null;
          },
        ))
      ]),
    );
  }

  void _showSheet() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(
      height: 400, decoration: const BoxDecoration(color: AppColors.bgDark, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(children: [
        const SizedBox(height: 15),
        const Text("الصيدات المتاحة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Expanded(child: ListView.builder(itemCount: _sniffedLinks.length, itemBuilder: (context, i) {
          String link = _sniffedLinks.keys.elementAt(i);
          var data = _sniffedLinks[link]!;
          return ListTile(
            title: Text(data["title"]!, maxLines: 1),
            subtitle: Text(data["size"]!),
            trailing: ElevatedButton(onPressed: () {
              Navigator.pop(context);
              DownloadManager().startDownload(context, link, "${data['title']} - ${DateTime.now().millisecond}.mp4", false);
            }, child: const Text("تحميل")),
          );
        }))
      ]),
    ));
  }
}

// -----------------------------------------------------------------------------
// شاشة التحميلات - جرد محتويات مجلد R_Hunter
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
  void initState() { super.initState(); loadFiles(); }

  Future<void> loadFiles() async {
    try {
      setState(() => _isLoading = true);
      if (Platform.isAndroid) await Permission.manageExternalStorage.request();
      
      final dir = Directory("/storage/emulated/0/Download/R_Hunter");
      if (!await dir.exists()) {
        setState(() { _files = []; _isLoading = false; });
        return;
      }
      
      final all = dir.listSync();
      setState(() {
        _files = all.where((f) {
          String p = f.path.toLowerCase();
          return p.endsWith(".mp4") || p.endsWith(".mp3") || p.endsWith(".webm") || p.endsWith(".mkv");
        }).toList();
        _files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        _isLoading = false;
      });
    } catch (e) {
      ErrorHunter.log("List_Files", e);
      setState(() { _files = []; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تحميلات R_Hunter"), centerTitle: true, backgroundColor: Colors.transparent),
      body: Column(children: [
        ValueListenableBuilder<List<ActiveDownload>>(
          valueListenable: DownloadManager().activeDownloadsNotifier,
          builder: (context, list, _) => list.isEmpty ? const SizedBox.shrink() : Column(children: list.map((d) => ListTile(title: Text(d.fileName), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [LinearProgressIndicator(value: d.progress), Text(d.size, style: const TextStyle(fontSize: 10))]))).toList()),
        ),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _files.isEmpty ? _buildEmpty() : ListView.builder(
          itemCount: _files.length,
          itemBuilder: (context, i) {
            final f = _files[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), child: ListTile(
              leading: const Icon(Icons.movie_rounded, color: AppColors.primary),
              title: Text(f.path.split('/').last),
              onTap: () {
                try { OpenFile.open(f.path); } catch (e) { ErrorHunter.log("Open_File", e); }
              },
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { f.deleteSync(); loadFiles(); }),
            ));
          },
        ))
      ]),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.folder_open, size: 80, color: Colors.grey), const SizedBox(height: 10), const Text("المجلد فارغ"), ElevatedButton(onPressed: loadFiles, child: const Text("تحديث"))]));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLocked = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _isLocked = p.getBool('app_lock') ?? false);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات"), centerTitle: true, backgroundColor: Colors.transparent),
      body: ListView(padding: const EdgeInsets.all(15), children: [
        SwitchListTile(title: const Text("قفل التطبيق"), value: _isLocked, onChanged: (v) async {
          final p = await SharedPreferences.getInstance(); await p.setBool('app_lock', v);
          setState(() => _isLocked = v);
        }, secondary: const Icon(Icons.fingerprint)),
        const Divider(),
        ListTile(title: const Text("المطور: Radwan Mohamed"), subtitle: const Text("تواصل عبر تليجرام: @Radwan263"), leading: const Icon(Icons.person), onTap: () => launchUrl(Uri.parse("https://t.me/Radwan263"))),
        const Divider(),
        // 💡 إضافة زر صياد الأخطاء هنا
        ListTile(
          title: const Text("تقرير صياد الأخطاء"),
          subtitle: const Text("اضغط هنا لو واجهتك مشكلة تقنية"),
          leading: const Icon(Icons.bug_report_rounded, color: Colors.orange),
          onTap: () => ErrorHunter.showLast(context),
        ),
      ]),
    );
  }
}

