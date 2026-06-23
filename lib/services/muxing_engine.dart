import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

class MuxingEngine {
  static final MuxingEngine _instance = MuxingEngine._internal();
  factory MuxingEngine() => _instance;
  MuxingEngine._internal();

  Future<bool> muxVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // FFmpeg command to mux video and audio losslessly
    // -i video -i audio -c copy -map 0:v:0 -map 1:a:0 output
    final String command = "-i \"$videoPath\" -i \"$audioPath\" -c copy -map 0:v:0 -map 1:a:0 -y \"$outputPath\"";

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Cleanup temporary files
      try {
        await File(videoPath).delete();
        await File(audioPath).delete();
      } catch (e) {
        // Log cleanup error
      }
      return true;
    } else {
      // Log FFmpeg error
      final logs = await session.getLogs();
      print("FFmpeg Error: ${logs.join('\n')}");
      return false;
    }
  }

  Future<bool> convertToMp4(String inputPath, String outputPath) async {
    final String command = "-i \"$inputPath\" -c copy -y \"$outputPath\"";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }
}
