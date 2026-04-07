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
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// -----------------------------------------------------------------------------
// صياد الأخطاء العالمي (Error Hunter System)
// -----------------------------------------------------------------------------
class ErrorHunter {
  static final ValueNotifier<String> lastError = ValueNotifier("لا توجد أخطاء مسجلة حالياً");
  
  static void log(String context, dynamic error) {
    String msg = "[$context] ${error.toString()}";
    print(msg); 
    lastError.value = "${DateTime.now().hour}:${DateTime.now().minute} -> $msg";
  }

  static void showLast(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgDark,
        title: const Text("تقرير صياد الأخطاء 🕵️", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(child: Text(lastError.value, style: const TextStyle(color: Colors.redAccent))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("تم", style: TextStyle(color: AppColors.primary))),
          TextButton(onPressed: () { lastError.value = "تم المسح"; Navigator.pop(ctx); }, child: const Text("مسح السجل", style: TextStyle(color: Colors.grey))),
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
    await DownloadManager().initNotifications();
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
          if (index == 2 && globalDownloadsKey.currentState != null) {
            globalDownloadsKey.currentState!.loadFiles();
          }
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
// مدير التحميلات النهائي (حل R_Hunter والملفات والعداد)
// -----------------------------------------------------------------------------
class ActiveDownload {
  final String url;
  final String fileName;
  double progress;
  String size;
  bool isCompleted;
  bool isFailed;
  bool isPaused;
  CancelToken? cancelToken;
  int downloadedBytes;
  int totalBytes;

  ActiveDownload({
    required this.url,
    required this.fileName,
    this.progress = 0.0,
    this.size = "...",
    this.isCompleted = false,
    this.isFailed = false,
    this.isPaused = false,
    this.cancelToken,
    this.downloadedBytes = 0,
    this.totalBytes = -1,
  });
}

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();
  final ValueNotifier<List<ActiveDownload>> activeDownloadsNotifier = ValueNotifier([]);
  VoidCallback? onDownloadComplete;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  void _showNotification(int id, String title, int progress) {
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'download_channel', 'تحميلات R-Plus',
      channelDescription: 'إشعارات تقدم التحميل',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: progress < 100,
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    _notificationsPlugin.show(id, title, progress < 100 ? 'جاري التحميل: $progress%' : 'اكتمل التحميل بنجاح', platformChannelSpecifics);
  }

  void scheduleDownload(BuildContext context, String url, String fileName, bool isAudio, DateTime scheduledTime) {
    final now = DateTime.now();
    if (scheduledTime.isBefore(now)) return;
    
    final duration = scheduledTime.difference(now);
    Timer(duration, () {
      startDownload(context, url, fileName, isAudio);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم جدولة التحميل في: ${scheduledTime.hour}:${scheduledTime.minute}")));
  }

  void clearCompleted() {
    activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => !d.isCompleted && !d.isFailed).toList();
  }

  void removeDownload(String url) {
    var dl = activeDownloadsNotifier.value.firstWhere((d) => d.url == url);
    dl.cancelToken?.cancel("User removed download");
    activeDownloadsNotifier.value = activeDownloadsNotifier.value.where((d) => d.url != url).toList();
  }

  void togglePause(String url, BuildContext context) {
    var dl = activeDownloadsNotifier.value.firstWhere((d) => d.url == url);
    if (dl.isCompleted || dl.isFailed) return;

    if (dl.isPaused) {
      dl.isPaused = false;
      activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
      startDownload(context, url, dl.fileName, false, isResuming: true);
    } else {
      dl.isPaused = true;
      dl.cancelToken?.cancel("Paused by user");
      activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
    }
  }

  Future<void> startDownload(BuildContext context, String url, String fileName, bool isAudio, {bool isResuming = false}) async {
    ActiveDownload? dl;
    if (isResuming) {
      dl = activeDownloadsNotifier.value.firstWhere((d) => d.url == url);
    } else {
      if (activeDownloadsNotifier.value.any((d) => d.url == url && !d.isCompleted)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذا الرابط جاري تحميله بالفعل")));
        return;
      }
      dl = ActiveDownload(url: url, fileName: fileName);
      activeDownloadsNotifier.value = [...activeDownloadsNotifier.value, dl];
    }

    try {
      if (Platform.isAndroid && !isResuming) {
        await Permission.storage.request();
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final String baseDir = "${downloadsDir.path}/R_Hunter";
      final Directory rHunterDir = Directory(baseDir);
      if (!await rHunterDir.exists()) await rHunterDir.create(recursive: true);

      String cleanFileName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      String savePath = "${rHunterDir.path}/$cleanFileName";
      File file = File(savePath);

      int start = 0;
      if (isResuming && await file.exists()) {
        start = await file.length();
      }

      dl.cancelToken = CancelToken();
      dl.isFailed = false;
      dl.isPaused = false;
      activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);

      // إضافة Headers المتصفح لتجنب حظر السيرفر (خطأ 403)
      Map<String, dynamic> headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
      };
      if (start > 0) headers['range'] = 'bytes=$start-';

      Response response = await _dio.get(
        url,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            int currentTotal = total + start;
            int currentReceived = received + start;
            dl!.progress = currentReceived / currentTotal;
            dl.downloadedBytes = currentReceived;
            dl.totalBytes = currentTotal;
            dl.size = "${(currentReceived / 1024 / 1024).toStringAsFixed(1)} MB / ${(currentTotal / 1024 / 1024).toStringAsFixed(1)} MB";
            if ((currentReceived / currentTotal * 100).toInt() % 5 == 0) {
              _showNotification(url.hashCode, dl.fileName, (dl.progress * 100).toInt());
            }
          } else {
            dl!.progress = -1.0;
            dl.size = "${((received + start) / 1024 / 1024).toStringAsFixed(1)} MB (جاري...)";
          }
          activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
        ),
        cancelToken: dl.cancelToken,
      );

      File outFile = File(savePath);
      var raf = await outFile.open(mode: start > 0 ? FileMode.append : FileMode.write);
      await for (var chunk in response.data.stream) {
        await raf.writeFrom(chunk);
      }
      await raf.close();

      dl.isCompleted = true;
      dl.progress = 1.0;
      activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
      _showNotification(url.hashCode, dl.fileName, 100);
      
      onDownloadComplete?.call(); 
      if (globalDownloadsKey.currentState != null) globalDownloadsKey.currentState!.loadFiles();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text("تم الحفظ بنجاح!")]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (CancelToken.isCancel(e as DioException)) {
        ErrorHunter.log("Downloader", "تم إيقاف التحميل مؤقتاً");
      } else {
        ErrorHunter.log("Downloader_Critical", e);
        dl!.isFailed = true;
        activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("حدث خطأ في التحميل"), backgroundColor: Colors.red));
        }
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

    try {
      if (url.contains("youtube.com/") || url.contains("youtu.be/")) {
        await _handleYoutube(url);
      } else if (url.contains("facebook.com") || url.contains("fb.watch")) {
        await _handleSocial(url, "Facebook");
      } else if (url.contains("tiktok.com")) {
        await _handleSocial(url, "TikTok");
      } else {
        DownloadManager().startDownload(context, url, "Media_${DateTime.now().millisecondsSinceEpoch}.mp4", false);
      }
    } catch (e) {
      ErrorHunter.log("Analyzer_Error", e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل التحليل. جرب رابطاً مباشراً")));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _handleYoutube(String url) async {
    final ytInstance = yt.YoutubeExplode();
    try {
      if (url.contains("list=")) {
        var playlist = await ytInstance.playlists.get(url);
        var videos = await ytInstance.playlists.getVideos(playlist.id).toList();
        ytInstance.close();
        if (mounted) _showPlaylistOptions(playlist.title, videos);
      } else {
        var video = await ytInstance.videos.get(url);
        var manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
        ytInstance.close();
        if (mounted) _showYoutubeOptions(video.title, manifest);
      }
    } catch (e) {
      ytInstance.close();
      rethrow;
    }
  }

  Future<void> _handleSocial(String url, String platform) async {
    // محاكاة استخراج الروابط للسوشيال ميديا (تطلب عادة API خارجي أو Scraping متقدم)
    // هنا نستخدم Sniffer المدمج في المتصفح كحل بديل أو نوجه المستخدم للمتصفح
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("جاري فتح $platform في المتصفح للاصطياد التلقائي...")));
      // التوجه لصفحة المتصفح مع الرابط
      // ملاحظة: هذا يتطلب تعديل بسيط في MainScreen للتنقل
    }
  }

  void _showRenameDialog(FileSystemEntity f) {
    final controller = TextEditingController(text: f.path.split('/').last);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("إعادة تسمية"),
      content: TextField(controller: controller),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
        TextButton(onPressed: () async {
          final newPath = f.path.replaceFirst(f.path.split('/').last, controller.text);
          await f.rename(newPath);
          Navigator.pop(ctx);
          loadFiles();
        }, child: const Text("حفظ")),
      ],
    ));
  }

  void _showYoutubeOptions(String title, yt.StreamManifest manifest) {
    var muxed = manifest.muxed.sortByVideoQuality();
    var audio = manifest.audioOnly.withHighestBitrate();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const Divider(height: 30),
            const Text("جودات الفيديو (MP4)", style: TextStyle(color: AppColors.primary)),
            ...muxed.map((s) => ListTile(
              title: Text(s.videoQualityLabel),
              subtitle: Text("${(s.size.totalMegaBytes).toStringAsFixed(1)} MB"),
              trailing: const Icon(Icons.download),
              onTap: () {
                Navigator.pop(context);
                DownloadManager().startDownload(context, s.url.toString(), "$title - ${s.videoQualityLabel}.mp4", false);
              },
            )),
            const Divider(),
            ListTile(
              title: const Text("تحميل صوت فقط (MP3)"),
              subtitle: Text("${(audio.size.totalMegaBytes).toStringAsFixed(1)} MB"),
              trailing: const Icon(Icons.music_note),
              onTap: () {
                Navigator.pop(context);
                DownloadManager().startDownload(context, audio.url.toString(), "$title.mp3", true);
              },
            ),
          ]),
        ),
      ),
    );
  }

  void _showPlaylistOptions(String title, List<yt.Video> videos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          Text("قائمة: $title", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("${videos.length} فيديو", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, i) => ListTile(
                leading: Image.network(videos[i].thumbnails.lowResUrl, width: 50),
                title: Text(videos[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(context);
                  _urlController.text = videos[i].url;
                  _analyzeUrl();
                },
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري تجهيز تحميل الكل...")));
              for (var v in videos) {
                // تحميل تلقائي بأعلى جودة متاحة (تبسيطاً)
                _analyzeAndDownloadSilently(v.url, v.title);
              }
            },
            child: const Text("تحميل الكل (أعلى جودة)"),
          )
        ]),
      ),
    );
  }

  Future<void> _analyzeAndDownloadSilently(String url, String title) async {
    final ytInstance = yt.YoutubeExplode();
    try {
      var video = await ytInstance.videos.get(url);
      var manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
      // استخدام جودة متوسطة لضمان سرعة التحميل في "تحميل الكل"
      var stream = manifest.muxed.where((s) => s.videoQualityLabel.contains("720") || s.videoQualityLabel.contains("480")).firstOrNull ?? manifest.muxed.withHighestBitrate();
      DownloadManager().startDownload(context, stream.url.toString(), "$title.mp4", false);
    } catch (_) {} finally { ytInstance.close(); }
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
          _isAnalyzing ? const CircularProgressIndicator() : Column(
            children: [
              ElevatedButton(onPressed: _analyzeUrl, child: const Text("اصطياد الآن")),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) {
                    final now = DateTime.now();
                    final scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                    if (scheduled.isBefore(now)) scheduled.add(const Duration(days: 1));
                    final url = _urlController.text.trim();
                    if (url.isNotEmpty) DownloadManager().scheduleDownload(context, url, "Scheduled_${DateTime.now().millisecond}.mp4", false, scheduled);
                  }
                },
                icon: const Icon(Icons.timer_outlined),
                label: const Text("جدولة التحميل"),
              ),
            ],
          )
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
  bool _adBlockEnabled = true; 
  bool _desktopMode = false;   
  final TextEditingController _urlController = TextEditingController(text: "https://www.google.com");
  
  Map<String, Map<String, String>> _sniffedLinks = {}; 

  Future<void> _addSniffedLink(String url) async {
    if (!_sniffedLinks.containsKey(url)) {
      try {
        String pageTitle = await webViewController?.getTitle() ?? "";
        if (pageTitle.isEmpty || pageTitle == "null") pageTitle = "Video_Playback";
        pageTitle = pageTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
        
        if (mounted) setState(() => _sniffedLinks[url] = {"title": pageTitle, "size": "حساب..."});

        var response = await Dio().head(url);
        var length = response.headers.value(HttpHeaders.contentLengthHeader) ?? response.headers.value('content-length');
        if (length != null) {
          double sizeInMb = int.parse(length) / (1024 * 1024);
          if (mounted) setState(() => _sniffedLinks[url]!["size"] = "${sizeInMb.toStringAsFixed(1)} MB");
        } else {
          if (mounted) setState(() => _sniffedLinks[url]!["size"] = "حجم غير معروف");
        }
      } catch (e) {
        if (mounted) setState(() => _sniffedLinks[url]!["size"] = "حجم غير معروف");
        ErrorHunter.log("Sniffer_Head_Request", e);
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
            child: Stack(
              children: [
                InAppWebView(
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
            if (_sniffedLinks.isNotEmpty)
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton.extended(
                  onPressed: _showSniffedLinksSheet,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  label: Text("اصطياد (${_sniffedLinks.length})", style: const TextStyle(color: Colors.white)),
                ),
              ),
              ],
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
// شاشة التحميلات المباشرة 
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
    try {
      setState(() => _isLoading = true);
      
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null || !await downloadsDir.exists()) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final dir = Directory("${downloadsDir.path}/R_Hunter");
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
      appBar: AppBar(
        title: const Text("تحميلات R_Hunter", style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true, 
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.primary), onPressed: loadFiles)
        ],
      ),
      body: Column(children: [
        ValueListenableBuilder<List<ActiveDownload>>(
          valueListenable: DownloadManager().activeDownloadsNotifier,
          builder: (context, activeList, child) {
            if (activeList.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("قائمة العمليات الحالية", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => DownloadManager().clearCompleted(),
                        icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: Colors.grey),
                        label: const Text("مسح المكتمل", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...activeList.map((dl) => Card(
                    color: AppColors.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), 
                      side: BorderSide(
                        color: dl.isFailed ? Colors.red : (dl.isCompleted ? Colors.green : AppColors.primary), 
                        width: 1
                      )
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(dl.fileName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (!dl.isCompleted && !dl.isFailed)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(dl.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: AppColors.primary),
                                  onPressed: () => DownloadManager().togglePause(dl.url, context),
                                ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey), 
                                onPressed: () => DownloadManager().removeDownload(dl.url)
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!dl.isCompleted && !dl.isFailed)
                            LinearProgressIndicator(
                              value: (dl.isPaused || dl.progress == -1.0) ? null : dl.progress, 
                              backgroundColor: AppColors.border, 
                              color: dl.isPaused ? Colors.orange : AppColors.primary, 
                              borderRadius: BorderRadius.circular(5), 
                              minHeight: 8
                            ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                dl.isFailed ? "فشل التحميل" : (dl.isCompleted ? "تم التحميل بنجاح" : (dl.isPaused ? "متوقف مؤقتاً" : (dl.progress == -1.0 ? "جاري التحميل..." : "${(dl.progress * 100).toStringAsFixed(1)} %"))), 
                                style: TextStyle(color: dl.isFailed ? Colors.red : (dl.isCompleted ? Colors.green : (dl.isPaused ? Colors.orange : AppColors.textMain)), fontSize: 12, fontWeight: FontWeight.bold)
                              ),
                              Text(dl.size, style: const TextStyle(color: AppColors.textMain, fontSize: 12)),
                            ],
                          ),
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
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _files.isEmpty ? _buildEmpty() : ListView.bu	          itemBuilder: (context, i) {
	            final f = _files[i];
	            final name = f.path.split('/').last;
	            return Card(
	              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
	              child: ListTile(
	                leading: const Icon(Icons.movie_rounded, color: AppColors.primary),
	                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
	                subtitle: Text("${(f.statSync().size / 1024 / 1024).toStringAsFixed(1)} MB"),
	                trailing: PopupMenuButton<String>(
	                  onSelected: (val) async {
	                    if (val == 'share') Share.shareXFiles([XFile(f.path)]);
	                    if (val == 'delete') { await f.delete(); loadFiles(); }
	                    if (val == 'rename') _showRenameDialog(f);
	                  },
	                  itemBuilder: (ctx) => [
	                    const PopupMenuItem(value: 'share', child: Text("مشاركة")),
	                    const PopupMenuItem(value: 'rename', child: Text("إعادة تسمية")),
	                    const PopupMenuItem(value: 'delete', child: Text("حذف")),
	                  ],
	                ),
	                onTap: () {
	                  try { OpenFile.open(f.path); } catch (e) { ErrorHunter.log("Open_File", e); }
	                },
	              ),
	            );
	          }, ))
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

