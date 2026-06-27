import 'dart:io';
// الاستدعاءات الصحيحة المتوافقة مع نسخة الـ Full
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

class MuxingEngine {
  static final MuxingEngine _instance = MuxingEngine._internal();
  factory MuxingEngine() => _instance;
  MuxingEngine._internal();

  /// دمج مسار الفيديو والصوت المنفصلين في ملف MP4 واحد بدون فقدان جودة (Lossless).
  Future<bool> muxVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // التحقق من وجود ملفات المدخلات
    if (!await File(videoPath).exists() || !await File(audioPath).exists()) {
      return false;
    }

    // أمر FFmpeg:
    // -i video -i audio : ملفات المدخلات
    // -c copy : نسخ الترميز بدون إعادة ضغط (lossless)
    // -map 0:v:0 -map 1:a:0 : دمج أول مسار فيديو من المدخل الأول وأول مسار صوت من المدخل الثاني
    // -shortest : إنهاء عملية الدمج عند انتهاء المسار الأقصر طولاً
    // -y : استبدال الملف النهائي إذا كان موجوداً مسبقاً
    final String command = "-i \"$videoPath\" -i \"$audioPath\" -c copy -map 0:v:0 -map 1:a:0 -shortest -y \"$outputPath\"";

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // تنظيف وحذف الملفات المؤقتة بعد نجاح العملية
      _safeDelete(videoPath);
      _safeDelete(audioPath);
      return true;
    } else {
      final logs = await session.getLogs();
      final failStackTrace = await session.getFailStackTrace();
      print("FFmpeg Muxing Failed. Return Code: $returnCode");
      print("Logs: $logs");
      if (failStackTrace != null) print("Stack Trace: $failStackTrace");
      return false;
    }
  }

  /// تحويل صيغ الفيديو المختلفة (مثل مقاطع .ts) إلى صيغة MP4 القياسية.
  Future<bool> convertToMp4(String inputPath, String outputPath) async {
    final String command = "-i \"$inputPath\" -c copy -bsf:a aac_adtstoasc -y \"$outputPath\"";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }

  /// استخراج الصوت فقط من ملف فيديو.
  Future<bool> extractAudio(String videoPath, String audioOutputPath) async {
    final String command = "-i \"$videoPath\" -vn -acodec copy -y \"$audioOutputPath\"";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }

  void _safeDelete(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      // تجاهل أخطاء الحذف المؤقتة لضمان عدم توقف التطبيق
    }
  }
}
