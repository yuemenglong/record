import 'dart:async';

import 'package:record/record.dart';

import '../../const/const.dart';

/// 自定义异常，用于表示录音被外部 forceStop 终止
class ForceStopException implements Exception {
  final String message;

  ForceStopException([this.message = 'Recording was force-stopped.']);

  @override
  String toString() => 'ForceStopException: $message';
}

/// 录音函数，增加了 forceStop 逻辑处理
///
/// 参数 [path]：保存录音文件的路径；
//// [silenceDelay]：静音多久后（秒）自动结束录音；
//// [onAmplitudeChanged]、[onStart]、[onStop] 为录音过程中的回调；
//// [forceStop] 是一个外部可调用的函数引用，内部将其赋值为终止函数。
Future<void> doRecordAudio(
  String path,
  double silenceDelay, {
  void Function(double)? onAmplitudeChanged,
  void Function()? onStart,
  void Function()? onStop,
  void Function(void Function())? forceStop,
}) async {
  final recorder = AudioRecorder();
  final completer = Completer<void>();

  // 用于记录录音是否已经正常结束或异常终止
  bool _completed = false;
  Timer? silenceTimer;

  // 内部定义 forceStop 的实现逻辑
  void _internalForceStop() async {
    if (_completed) return; // 如果录音已结束，不需要处理
    print("Force stop triggered.");
    // 取消计时器
    silenceTimer?.cancel();
    try {
      // 尽量停止录音并释放资源
      if (await recorder.isRecording()) {
        await recorder.stop();
      }
    } catch (_) {
      // 忽略 stop 过程中的异常
    }
    await recorder.dispose();
    _completed = true;
    // 通过 completer 将错误传递到调用者处
    completer.completeError(ForceStopException());
  }

  // 如果外部传入了 forceStop 的“设置器”，则把内部的 forceStop 函数赋值给外部
  if (forceStop != null) {
    forceStop(_internalForceStop);
  }

  try {
    bool started = false;
    if (!(await recorder.hasPermission())) {
      print("No Permission");
      return;
    }
    const encoder = AudioEncoder.pcm16bits;
    if (!(await recorder.isEncoderSupported(encoder))) {
      print("No Encoder");
      return;
    }
    // 设置录音配置：单声道、16000采样率、WAV格式
    const config = RecordConfig(
      encoder: encoder,
      numChannels: 1,
      sampleRate: 16000,
    );

    // 监听音量变化
    recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amplitude) {
      var db = amplitude.current;
      if (!started && db > Const.SilentLimitMax) {
        print("Start Watch");
        started = true;
        if (onStart != null) {
          onStart();
        }
      }
      if (started && db < Const.SilentLimitMin) {
        // 开始或重置静音计时器
        if (silenceTimer == null) {
          print("Create Timer");
          silenceTimer = Timer(Duration(seconds: silenceDelay.toInt()), () async {
            // 如果录音已经 force stop，则这里不再继续
            if (_completed) return;
            print("Before Stop");
            await recorder.stop();
            await recorder.dispose();
            _completed = true;
            print("After Stop");
            if (onStop != null) {
              onStop();
            }
            completer.complete();
          });
        }
      } else {
        if (silenceTimer != null) {
          print("Cancel Timer");
          // 如果音量恢复到正常，则取消静音计时器
          silenceTimer?.cancel();
          silenceTimer = null;
        }
      }
      if (onAmplitudeChanged != null) {
        onAmplitudeChanged(db);
      }
    });

    print("Before Start");
    await recorder.start(config, path: path);
    print("After Start");
    return completer.future;
  } catch (e) {
    // 如果发生异常，则确保取消录音并释放相关资源
    await recorder.cancel();
    await recorder.dispose();
    rethrow;
  }
}
