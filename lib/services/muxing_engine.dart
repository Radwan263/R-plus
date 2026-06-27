import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/ffprint.dart';

class MuxingEngine {
  static final MuxingEngine _instance = MuxingEngine._internal();
  factory MuxingEngine() => _instance;
  MuxingEngine._internal();

  /// Muxes separate video and audio tracks into a single MP4 container losslessly.
  Future<bool> muxVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    // Check if input files exist
    if (!await File(videoPath).exists() || !await File(audioPath).exists()) {
      return false;
    }

    // FFmpeg command:
    // -i video -i audio : Input files
    // -c copy : Copy codecs (lossless)
    // -map 0:v:0 -map 1:a:0 : Map first video stream from 1st input and first audio from 2nd input
    // -shortest : Finish encoding when the shortest input stream ends
    // -y : Overwrite output file
    final String command = "-i \"$videoPath\" -i \"$audioPath\" -c copy -map 0:v:0 -map 1:a:0 -shortest -y \"$outputPath\"";

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Cleanup temporary separate streams
      _safeDelete(videoPath);
      _safeDelete(audioPath);
      return true;
    } else {
      final logs = await session.getLogs();
      final failStackTrace = await session.getFailStackTrace();
      print("FFmpeg Muxing Failed. Return Code: $returnCode");
      return false;
    }
  }

  /// Converts various formats (like .ts chunks or raw streams) to standard MP4.
  Future<bool> convertToMp4(String inputPath, String outputPath) async {
    final String command = "-i \"$inputPath\" -c copy -bsf:a aac_adtstoasc -y \"$outputPath\"";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    return ReturnCode.isSuccess(returnCode);
  }

  /// Extracts audio from a video file.
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
      // Ignore cleanup errors
    }
  }
}
