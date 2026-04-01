import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // مكتبة المتصفح

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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onDownloadStarted: () {
        setState(() { _selectedIndex = 2; });
      }),
      const BrowserPage(), // شاشة المتصفح الحقيقية
      const DownloadsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() { _selectedIndex = index; });
        },
        backgroundColor: const Color(0xFF1E1E1E),
        indicatorColor: Colors.blueAccent.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home, color: Colors.blueAccent), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.travel_explore), selectedIcon: Icon(Icons.travel_explore, color: Colors.blueAccent), label: 'المتصفح'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download, color: Colors.blueAccent), label: 'التحميلات'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 1. شاشة الرئيسية
// ----------------------------------------------------
class HomePage extends StatefulWidget {
  final VoidCallback onDownloadStarted;
  const HomePage({super.key, required this.onDownloadStarted});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkClipboardForLink();
  }

  Future<void> _checkClipboardForLink() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      String copiedText = data.text!;
      if (copiedText.contains('http://') || copiedText.contains('https://')) {
        setState(() { _urlController.text = copiedText; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم التقاط الرابط من الحافظة! 🔗"), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _showDownloadSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Text("تحميل الملف!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.video_file, size: 45, color: Colors.blueAccent),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("مسلسل ليل الحلقة 43 - عرب سيد", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Text("249.78 MB • mp4", style: TextStyle(color: Colors.grey[400])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              const Text("اختر الجودة:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _qualityChip("1080p", Colors.green), _qualityChip("720p", Colors.blue), _qualityChip("480p", Colors.orange), _qualityChip("MP3", Colors.redAccent),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDownloadStarted();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("بدأ التحميل...")));
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("البدء", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _qualityChip(String label, Color color) {
    return ActionChip(label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: color.withOpacity(0.15), side: BorderSide(color: color, width: 1.5), onPressed: () {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('R Cima Downloader', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: const Color(0xFF1E1E1E), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_download_rounded, size: 90, color: Colors.blueAccent),
            const SizedBox(height: 40),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'ضع رابط الفيديو أو الصفحة هنا...', prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () => _urlController.clear()),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (_urlController.text.isNotEmpty) { _showDownloadSheet(); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال الرابط أولاً!"), backgroundColor: Colors.redAccent)); }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text('تحليل الرابط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 2. شاشة المتصفح (المحرك وصائد الروابط)
// ----------------------------------------------------
class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? webViewController;
  double progress = 0;
  final TextEditingController _searchController = TextEditingController(text: "https://google.com");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(hintText: "ابحث أو أدخل رابط...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.grey)),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (value) {
            var url = WebUri(value.startsWith("http") ? value : "https://www.google.com/search?q=$value");
            webViewController?.loadUrl(urlRequest: URLRequest(url: url));
          },
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => webViewController?.reload()),
        ],
      ),
      body: Column(
        children: [
          if (progress < 1.0) LinearProgressIndicator(value: progress, color: Colors.blueAccent, backgroundColor: Colors.transparent),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri("https://google.com")),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onProgressChanged: (controller, p) {
                setState(() { progress = p / 100; });
              },
              // ⚠️ صائد الروابط السري (Sniffer)
              shouldInterceptRequest: (controller, request) async {
                String url = request.url.toString();
                // لو الرابط فيه صيغة فيديو، المتصفح هيصطاده
                if (url.endsWith(".mp4") || url.endsWith(".m3u8") || url.contains(".mp4?")) {
                  print("🎯 تم اصطياد فيديو: $url");
                  // هنبرمج ظهور الإشعار (رقم 1 الأحمر اللي في صورتك) هنا التحديث الجاي!
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

// ----------------------------------------------------
// 3. شاشة التحميلات
// ----------------------------------------------------
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحميلات', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: const Color(0xFF1E1E1E), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Card(
            color: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.video_file, size: 40, color: Colors.blueAccent),
                      const SizedBox(width: 15),
                      const Expanded(child: Text("مسلسل ليل الحلقة 43 - عرب سيد.mp4", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      IconButton(icon: const Icon(Icons.pause_circle_filled, size: 35, color: Colors.orangeAccent), onPressed: () {}),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("105 MB / 249 MB", style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      const Text("45%", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: 0.45, backgroundColor: Colors.grey[800], color: Colors.blueAccent, minHeight: 6, borderRadius: BorderRadius.circular(10)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("2.5 MB/s", style: TextStyle(color: Colors.greenAccent[400], fontSize: 12)),
                      Text("يتبقى دقيقتين", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

