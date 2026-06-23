import 'dart:async';
import 'dart:convert';
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

// Import new models and services
import 'models/download_task.dart';
import 'services/network_traffic_sniffer.dart';
import 'services/scraping_engine.dart';
import 'services/muxing_engine.dart';

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
    await ScrapingEngine().init();
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
class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();
  final Dio _dio = Dio();
  final ValueNotifier<List<DownloadTask>> activeDownloadsNotifier = ValueNotifier([]);
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

  Future<void> startDownload(BuildContext context, String url, String fileName, bool isAudio, {bool isResuming = false, Map<String, String>? headers}) async {
    DownloadTask? dl;
    if (isResuming) {
      dl = activeDownloadsNotifier.value.firstWhere((d) => d.url == url);
    } else {
      if (activeDownloadsNotifier.value.any((d) => d.url == url && !d.isCompleted)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("هذا الرابط جاري تحميله بالفعل")));
        return;
      }
      dl = DownloadTask(url: url, fileName: fileName, headers: headers ?? {});
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

      // Use intercepted headers or default ones
      Map<String, dynamic> finalHeaders = {
        'User-Agent': dl.headers['User-Agent'] ?? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': '*/*',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
      };
      
      if (dl.headers['Cookie'] != null && dl.headers['Cookie']!.isNotEmpty) finalHeaders['Cookie'] = dl.headers['Cookie'];
      if (dl.headers['Referer'] != null && dl.headers['Referer']!.isNotEmpty) finalHeaders['Referer'] = dl.headers['Referer'];
      
      // Add any other intercepted headers
      dl.headers.forEach((key, value) {
        if (!finalHeaders.containsKey(key)) finalHeaders[key] = value;
      });

      if (start > 0) finalHeaders['range'] = 'bytes=$start-';

      Response response = await _dio.get(
        url,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            dl!.progress = (received + start) / (total + start);
            dl.downloadedBytes = received + start;
            dl.totalBytes = total + start;
            dl.size = "${(dl.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB";
            activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
            _showNotification(url.hashCode, dl.fileName, (dl.progress * 100).toInt());
          }
        },
        cancelToken: dl.cancelToken,
        options: Options(
          headers: finalHeaders,
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      IOSink sink = file.openWrite(mode: start > 0 ? FileMode.append : FileMode.write);
      await sink.addStream(response.data.stream);
      await sink.close();

      // Handle Adaptive Muxing if needed
      if (dl.isAdaptiveStream && dl.videoStreamUrl != null && dl.audioStreamUrl != null) {
        _showNotification(url.hashCode, "جاري دمج الفيديو والصوت...", 99);
        final String videoPath = "${rHunterDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4";
        final String audioPath = "${rHunterDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a";
        
        // This is a simplified logic; in a real app, you'd download both first
        // For this architecture, we assume the muxing happens after both are ready
        bool success = await MuxingEngine().muxVideoAudio(
          videoPath: videoPath,
          audioPath: audioPath,
          outputPath: savePath,
        );
        
        if (!success) {
          dl.isFailed = true;
          _showNotification(url.hashCode, "فشل دمج الملفات", 0);
          return;
        }
      }

      dl.isCompleted = true;
      dl.progress = 1.0;
      activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
      _showNotification(url.hashCode, dl.fileName, 100);
      if (onDownloadComplete != null) onDownloadComplete!();

    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) {
        dl!.isFailed = true;
        activeDownloadsNotifier.value = List.from(activeDownloadsNotifier.value);
        ErrorHunter.log("Download_Manager", e);
      }
    }
  }
}

// -----------------------------------------------------------------------------
// الصفحة الرئيسية (HomePage)
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
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isAnalyzing = true);
    final ytInstance = yt.YoutubeExplode();

    try {
      if (url.contains("youtube.com") || url.contains("youtu.be")) {
        if (url.contains("playlist?list=")) {
          var playlist = await ytInstance.playlists.get(url);
          var videos = await ytInstance.playlists.getVideos(playlist.id).toList();
          if (mounted) _showPlaylistOptions(playlist.title, videos);
        } else {
          var video = await ytInstance.videos.get(url);
          var manifest = await ytInstance.videos.streamsClient.getManifest(video.id);
          if (mounted) _showYoutubeOptions(video.title, manifest);
        }
      } else if (url.contains("facebook.com") || url.contains("fb.watch")) {
        await _handleSocial(url, "Facebook");
      } else {
        // Generic link: Start download directly or try to sniff
        DownloadManager().startDownload(context, url, "Video_${DateTime.now().millisecondsSinceEpoch}.mp4", false);
      }
    } catch (e) {
      ErrorHunter.log("URL_Analysis", e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل تحليل الرابط، جرب استخدامه في المتصفح")));
    } finally {
      ytInstance.close();
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _handleSocial(String url, String platform) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("جاري فتح $platform في المتصفح للاصطياد التلقائي...")));
    }
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

// -----------------------------------------------------------------------------
// صفحة المتصفح (BrowserPage)
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
  
  Map<String, DownloadTask> _sniffedTasks = {}; 
  late StreamSubscription<DownloadTask> _snifferSubscription;

  @override
  void initState() {
    super.initState();
    _snifferSubscription = NetworkTrafficSniffer().snifferStream.listen((task) {
      if (!_sniffedTasks.containsKey(task.url)) {
        _addSniffedTask(task);
      }
    });
  }

  @override
  void dispose() {
    _snifferSubscription.cancel();
    super.dispose();
  }

  Future<void> _addSniffedTask(DownloadTask task) async {
    try {
      String pageTitle = await webViewController?.getTitle() ?? "";
      if (pageTitle.isEmpty || pageTitle == "null") pageTitle = "Video_Playback";
      pageTitle = pageTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ').trim();
      
      final updatedTask = DownloadTask(
        url: task.url,
        fileName: "$pageTitle.${task.fileName.split('.').last}",
        headers: task.headers,
        isAdaptiveStream: task.isAdaptiveStream,
        mimeType: task.mimeType,
      );

      if (mounted) setState(() => _sniffedTasks[task.url] = updatedTask);

      var response = await Dio().head(task.url, options: Options(headers: task.headers));
      var length = response.headers.value(HttpHeaders.contentLengthHeader) ?? response.headers.value('content-length');
      if (length != null) {
        double sizeInMb = int.parse(length) / (1024 * 1024);
        if (mounted) {
          setState(() {
            _sniffedTasks[task.url]!.size = "${sizeInMb.toStringAsFixed(1)} MB";
            _sniffedTasks[task.url]!.totalBytes = int.parse(length);
          });
        }
      } else {
        if (mounted) setState(() => _sniffedTasks[task.url]!.size = "حجم غير معروف");
      }
    } catch (e) {
      if (mounted) setState(() => _sniffedTasks[task.url]!.size = "حجم غير معروف");
      ErrorHunter.log("Sniffer_Head_Request", e);
    }
  }

  void _showSniffedLinksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            const Text("الروابط المصطادة 🎣", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: _sniffedTasks.isEmpty 
                ? const Center(child: Text("لم يتم العثور على روابط ميديا بعد"))
                : ListView.builder(
                    itemCount: _sniffedTasks.length,
                    itemBuilder: (context, index) {
                      String url = _sniffedTasks.keys.elementAt(index);
                      DownloadTask task = _sniffedTasks[url]!;
                      return ListTile(
                        leading: const Icon(Icons.video_collection_rounded, color: AppColors.primary),
                        title: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(task.size, style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.download_rounded, color: AppColors.primary),
                        onTap: () {
                          DownloadManager().startDownload(context, url, task.fileName, false, headers: task.headers);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
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
                      if (_sniffedTasks.isNotEmpty)
                        Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text('${_sniffedTasks.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
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
                    controller.addJavaScriptHandler(handlerName: 'onMediaFound', callback: (args) {
                      final List<dynamic> foundMedia = jsonDecode(args[0]);
                      for (var item in foundMedia) {
                        final task = DownloadTask(
                          url: item['url'],
                          fileName: "Video_${DateTime.now().millisecondsSinceEpoch}.mp4",
                          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'},
                        );
                        if (!_sniffedTasks.containsKey(task.url)) {
                          _addSniffedTask(task);
                        }
                      }
                    });
                  },
                  onLoadStart: (controller, url) {
                    setState(() { _urlController.text = url.toString(); _sniffedTasks.clear(); });
                  },
                  onUpdateVisitedHistory: (controller, url, androidIsReload) {
                    setState(() => _urlController.text = url.toString());
                  },
                  onLoadStop: (controller, url) async {
                    if (_adBlockEnabled) {
                      await controller.evaluateJavascript(source: "var style = document.createElement('style'); style.type = 'text/css'; style.innerHTML = '.ad, .ads, .banner, .pop-up, iframe[src*=\"ads\"], [class*=\"ad-\"], [id*=\"ad-\"] { display: none !important; }'; document.head.appendChild(style);");
                    }
                    await ScrapingEngine().injectRules(controller, url, 'onLoadStop');
                    await controller.evaluateJavascript(source: ScrapingEngine.universalMediaFinderJs);
                  },
                  onProgressChanged: (controller, progress) async {
                    setState(() => _progress = progress / 100);
                  },
                  shouldInterceptRequest: (controller, request) async {
                    NetworkTrafficSniffer().handleRequest(request);
                    return null;
                  },
                  onLoadResource: (controller, resource) {
                    NetworkTrafficSniffer().handleResource(resource);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowserPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        switch (value) {
          case 'refresh': webViewController?.reload(); break;
          case 'desktop': setState(() { _desktopMode = !_desktopMode; }); webViewController?.setSettings(settings: InAppWebViewSettings(userAgent: _desktopMode ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36" : "Mozilla/5.0 (Linux; Android 13) Chrome/116.0.0.0 Mobile Safari/537.36")); webViewController?.reload(); break;
          case 'adblock': setState(() { _adBlockEnabled = !_adBlockEnabled; }); webViewController?.reload(); break;
          case 'clear': await InAppWebViewController.clearAllCache(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم مسح ذاكرة التخزين المؤقت"))); break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text("تحديث"))),
        PopupMenuItem(value: 'desktop', child: ListTile(leading: Icon(_desktopMode ? Icons.phone_android : Icons.desktop_windows), title: Text(_desktopMode ? "وضع الجوال" : "وضع الكمبيوتر"))),
        PopupMenuItem(value: 'adblock', child: ListTile(leading: Icon(_adBlockEnabled ? Icons.block : Icons.check_circle), title: Text(_adBlockEnabled ? "تعطيل مانع الإعلانات" : "تفعيل مانع الإعلانات"))),
        const PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.delete_sweep), title: Text("مسح الكاش"))),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// صفحة التحميلات (DownloadsPage)
// -----------------------------------------------------------------------------
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});
  @override
  State<DownloadsPage> createState() => DownloadsPageState();
}

class DownloadsPageState extends State<DownloadsPage> {
  List<FileSystemEntity> _files = [];
  bool _isFilesTab = false;

  @override
  void initState() {
    super.initState();
    loadFiles();
    DownloadManager().onDownloadComplete = loadFiles;
  }

  Future<void> loadFiles() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download/R_Hunter');
      } else {
        dir = await getDownloadsDirectory();
      }
      if (dir != null && await dir.exists()) {
        setState(() => _files = dir!.listSync().where((f) => f is File).toList().reversed.toList());
      }
    } catch (e) { ErrorHunter.log("Load_Files", e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مركز التحميل"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            children: [
              Expanded(child: InkWell(onTap: () => setState(() => _isFilesTab = false), child: Container(alignment: Alignment.center, height: 50, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: !_isFilesTab ? AppColors.primary : Colors.transparent, width: 2))), child: const Text("قيد التنفيذ")))),
              Expanded(child: InkWell(onTap: () => setState(() => _isFilesTab = true), child: Container(alignment: Alignment.center, height: 50, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _isFilesTab ? AppColors.primary : Colors.transparent, width: 2))), child: const Text("المكتملة")))),
            ],
          ),
        ),
      ),
      body: _isFilesTab ? _buildFilesList() : _buildActiveList(),
      floatingActionButton: !_isFilesTab ? FloatingActionButton(onPressed: () => DownloadManager().clearCompleted(), mini: true, backgroundColor: Colors.redAccent, child: const Icon(Icons.delete_sweep)) : null,
    );
  }

  Widget _buildActiveList() {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadManager().activeDownloadsNotifier,
      builder: (context, downloads, _) {
        if (downloads.isEmpty) return const Center(child: Text("لا توجد تحميلات نشطة حالياً"));
        return ListView.builder(
          itemCount: downloads.length,
          itemBuilder: (context, i) {
            final d = downloads[i];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                title: Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: d.progress, color: d.isFailed ? Colors.red : AppColors.primary),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${(d.progress * 100).toInt()}% | ${d.size}", style: const TextStyle(fontSize: 10)),
                        if (d.isFailed) const Text("فشل التحميل", style: TextStyle(color: Colors.red, fontSize: 10)),
                        if (d.isCompleted) const Text("اكتمل", style: TextStyle(color: Colors.green, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: Icon(d.isPaused ? Icons.play_arrow : Icons.pause, size: 20), onPressed: () => DownloadManager().togglePause(d.url, context)),
                    IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.red), onPressed: () => DownloadManager().removeDownload(d.url)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilesList() {
    if (_files.isEmpty) return const Center(child: Text("لا توجد ملفات محملة بعد"));
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final f = _files[i];
        final name = f.path.split('/').last;
        return ListTile(
          leading: const Icon(Icons.video_library_rounded, color: AppColors.primary),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("${(File(f.path).lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB"),
          trailing: PopupMenuButton(
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'open', child: Text("فتح")),
              const PopupMenuItem(value: 'share', child: Text("مشاركة")),
              const PopupMenuItem(value: 'rename', child: Text("إعادة تسمية")),
              const PopupMenuItem(value: 'delete', child: Text("حذف")),
            ],
            onSelected: (val) async {
              if (val == 'open') OpenFile.open(f.path);
              if (val == 'share') Share.shareXFiles([XFile(f.path)]);
              if (val == 'delete') { await f.delete(); loadFiles(); }
              if (val == 'rename') _showRenameDialog(f);
            },
          ),
          onTap: () => OpenFile.open(f.path),
        );
      },
    );
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
}

// -----------------------------------------------------------------------------
// صفحة الإعدادات (SettingsPage)
// -----------------------------------------------------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _appLock = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _appLock = prefs.getBool('app_lock') ?? false);
  }

  _toggleLock(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock', val);
    setState(() => _appLock = val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("الإعدادات")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text("قفل التطبيق (بصمة/رمز)"),
            trailing: Switch(value: _appLock, onChanged: _toggleLock),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text("صياد الأخطاء (Error Hunter)"),
            subtitle: const Text("عرض آخر الأخطاء المسجلة"),
            onTap: () => ErrorHunter.showLast(context),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("عن R-Plus"),
            subtitle: Text("الإصدار 1.1.0 Omni-Sniffer Edition"),
          ),
        ],
      ),
    );
  }
}
