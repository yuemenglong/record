import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

import '../../const/key.dart';
import 'refresh_token.dart';

String _getAudioCachePath(String text) {
  final bytes = utf8.encode(text);
  final hash = md5.convert(bytes).toString();
  return path.join('.audio_cache', '$hash.wav');
}

Future<void> _ensureCacheDirectoryExists() async {
  final dir = Directory('.audio_cache');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

Future<bool> _copyFile(String source, String destination) async {
  try {
    await File(source).copy(destination);
    return true;
  } catch (e) {
    print("Error copying file: $e");
    return false;
  }
}

Future<void> _textToSpeechPost(String appKey, String token, String text, String audioSaveFile,
    {String format = "wav", int sampleRate = 16000}) async {
  // Set service URL
  const url = "https://nls-gateway-cn-shanghai.aliyuncs.com/stream/v1/tts";

  // Construct request body
  final requestBody = jsonEncode({
    "appkey": appKey,
    "token": token,
    "text": text,
    "format": format,
    "sample_rate": sampleRate,
  });

  final headers = {"Content-Type": "application/json"};

  while (true) {
    try {
      // Send POST request
      final response = await http.post(Uri.parse(url), headers: headers, body: requestBody);

      // Handle response
      final contentType = response.headers["content-type"];
      if (contentType == "audio/mpeg") {
        final audioFile = File(audioSaveFile);
        await audioFile.writeAsBytes(response.bodyBytes);
        print("Text-to-speech succeeded, audio saved to: $audioSaveFile");
        return; // 成功时退出循环
      } else {
        final errorMessage = response.body;
        print("Text-to-speech failed: $errorMessage. Retrying...");
        await Future.delayed(const Duration(seconds: 2)); // 等待 2 秒后重试
      }
    } catch (e) {
      print("Error occurred: $e. Retrying...");
      await Future.delayed(const Duration(seconds: 2)); // 等待 2 秒后重试
    }
  }
}

Future<void> doGetAudioFromText(String text, String saveFile) async {
  await _ensureCacheDirectoryExists();
  final cachePath = _getAudioCachePath(text);
  
  // Check if cached version exists
  if (await File(cachePath).exists()) {
    final success = await _copyFile(cachePath, saveFile);
    if (success) {
      print("Audio retrieved from cache: $saveFile");
      return;
    }
  }

  // If not in cache or copy failed, generate new audio
  final token = doGetToken();
  await _textToSpeechPost(Key.AppKey, token, text, saveFile);
  
  // Cache the newly generated audio
  await _copyFile(saveFile, cachePath);
}
