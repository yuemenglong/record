import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record_example/lesson/lesson.dart';
import 'package:record_example/const/const.dart';
import 'package:record_example/util/pack/get_audio_from_text.dart';
import 'package:record_example/util/pack/get_text_from_audio.dart';
import 'package:record_example/util/pack/play_audio.dart';
import 'package:record_example/util/pack/record_audio.dart';
import 'package:record_example/util/pack/text_diff.dart';
import 'package:record_example/util/time_recorder.dart';
import 'package:record_example/widget/choose_lesson.dart';
import 'package:record_example/widget/edit_favour_sentence.dart';

import '../util/util.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  static const double radiusNormal = 50.0;
  static const double radiusMin = 30.0;
  static const double radiusMax = 400.0;
  static const Duration maxSentenceDuration = Duration(seconds: 5); // 每句最大时间

  // Add multiplier options
  static const List<double> multiplierOptions = [1.33333, 1.66666, 2];
  double currentMultiplier = 1.33333; // Default value

  bool isRecording = false;
  bool isPlaying = false;
  bool isRunning = false;
  bool showLessonSelection = false;
  bool isPaused = false; // 新增暂停状态
  double radius = radiusNormal;
  Color circleColor = Colors.blueGrey;
  late Lesson lesson;
  late List<Lesson> lessons;
  String currentSentence = '';
  String currentSentenceCn = '';
  String currentSentenceWrong = '';

  TimeRecorder timeRecorder = TimeRecorder();
  Timer? refreshTimer;

  Completer<bool> _skipCompleter = Completer<bool>();
  Completer<void>? _pauseCompleter; // 新增暂停的Completer

  /// 用于保存当前录音的 forceStop 操作引用
  void Function()? _forceStopHandler;

  @override
  void initState() {
    super.initState();
    LessonStore.getLessons().then((allLessons) {
      setState(() {
        lessons = allLessons;
        lesson = allLessons[0];
      });
    });
  }

  Future<void> _selectLesson(Lesson selectedLesson) async {
    // 如果录音还在进行，先停止现有录音
    _forceStopCurrentRecording();
    setState(() {
      lesson = selectedLesson;
      showLessonSelection = false;
    });
  }

  /// 当需要 forceStop 现有录音时调用此方法
  void _forceStopCurrentRecording() {
    if (_forceStopHandler != null) {
      print("Force stop current recording before starting new one or exiting.");
      _forceStopHandler!();
      _forceStopHandler = null;
    }
    setState(() {
      isPlaying = false;
    });
  }

  void _skipCurrentSentence() {
    _skipCompleter.complete(false);
  }

  void _togglePause() {
    setState(() {
      isPaused = !isPaused;
      if (!isPaused && _pauseCompleter != null) {
        _pauseCompleter!.complete(); // 恢复执行
        _pauseCompleter = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 计算显示的总时间（累计时间 + 当前句子的时间）
    Duration displayedDuration = Duration(milliseconds: timeRecorder.getTotalMs());
    String displayedTime =
        '${displayedDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}分:${displayedDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}秒';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Const.lightColor,
        title: const Text('课文跟读'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 点击返回按钮时，先停止录音
            _forceStopCurrentRecording();
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.grey.shade800,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  width: radius * 2,
                  height: radius * 2,
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: circleColor,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    currentSentence,
                    style: const TextStyle(fontSize: 36.0, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    currentSentenceCn,
                    style: const TextStyle(fontSize: 36.0, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    currentSentenceWrong,
                    style: const TextStyle(fontSize: 36.0, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          // 在屏幕底部显示最终总时间（可选）
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '总用时: ${timeRecorder.getTotalTimeStr()}',
                style: const TextStyle(fontSize: 24.0, color: Colors.white),
              ),
            ),
          ),
          // 将跳过和暂停按钮放在右侧常驻区域
          if (isRunning) ...[
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: 'skipSentence',
                    onPressed: _skipCurrentSentence,
                    child: const Icon(Icons.skip_next),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'pauseButton',
                    onPressed: _togglePause,
                    backgroundColor: isPaused ? Colors.green : Colors.orange,
                    child: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                  const SizedBox(height: 16),
                  FloatingActionButton(
                    heroTag: 'replayButton',
                    onPressed: startPlaying,
                    backgroundColor: isPlaying ? Colors.grey : Colors.blue,
                    child: const Icon(Icons.replay),
                  ),
                ],
              ),
            ),
          ],
          // Add multiplier slider
          Positioned(
            top: 16,
            right: 16,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.2,
              child: Slider(
                value: currentMultiplier,
                min: multiplierOptions.first,
                max: multiplierOptions.last,
                divisions: multiplierOptions.length - 1,
                onChanged: (value) {
                  setState(() {
                    currentMultiplier = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !isRunning
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'start',
                  onPressed: () async {
                    // 开始前先 force stop 当前录音，防止状态冲突
                    _forceStopCurrentRecording();
                    if (!isRunning) {
                      setState(() {
                        isRunning = true;
                        timeRecorder.reset();
                      });
                      await start();
                      setState(() {
                        isRunning = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始练习'),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'selectLesson',
                  onPressed: () {
                    _forceStopCurrentRecording();
                    showChooseLessonDialog(context, lessons, _selectLesson);
                    setState(() {
                      showLessonSelection = true;
                    });
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('选择课程'),
                ),
                const SizedBox(width: 16),
                FloatingActionButton.extended(
                  heroTag: 'editFavour',
                  onPressed: () {
                    _forceStopCurrentRecording();
                    showEditFavourSentence(context, lessons);
                  },
                  icon: const Icon(Icons.favorite),
                  label: const Text('编辑收藏'),
                ),
              ],
            )
          : null,
    );
  }

  double mapAmplitudeToRadius(double amplitude) {
    if (amplitude < Const.SilentLimitMin) {
      return radiusMin;
    } else if (amplitude > Const.VoiceLimitMax) {
      return radiusMax;
    } else {
      double normalized = (amplitude - Const.SilentLimitMin) / -(Const.SilentLimitMin);
      return radiusMin + normalized * (radiusMax - radiusMin);
    }
  }

  /// 开始录音并传入 forceStop 的设置器，保存 forceStop 调用引用
  Future<void> startRecording() async {
    setState(() {
      isRecording = true;
      circleColor = Colors.blue;
    });
    return await doRecordAudio(
      Const.wavPath,
      1,
      onAmplitudeChanged: (amplitude) {
        setState(() {
          radius = mapAmplitudeToRadius(amplitude);
        });
      },
      onStop: () {
        setState(() {
          isRecording = false;
          radius = radiusNormal;
          circleColor = Colors.blueGrey;
        });
      },
      forceStop: (handler) {
        _forceStopHandler = handler;
      },
    );
  }

  Future<void> startPlaying() async {
    if (isPlaying) {
      return;
    }
    setState(() {
      isPlaying = true;
    });
    await doPlayAudio(Const.wavPath);
    setState(() {
      isPlaying = false;
    });
  }

  Future<void> start() async {
    timeRecorder.reset();
    for (var s in lesson.sentences) {
      setState(() {
        isPlaying = false;
        currentSentence = s.text;
        currentSentenceCn = s.textCn;
        currentSentenceWrong = "";
      });

      // 启动定时器，每100毫秒更新一次当前句子的时间
      refreshTimer?.cancel();
      refreshTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        setState(() {});
      });

      while (true) {
        // 获取音频文件（朗读音频）
        await Util.getAudioFromText(s.text, Const.wavPath);
        var wavTime = await Util.getWavDuration(Const.wavPath);
        await startPlaying();
        // 开始录音前先确保没有遗留正在录音的任务
        _skipCompleter = Completer<bool>();

        var timeoutCompleter = Completer<bool>();
        Timer(Duration(milliseconds: (wavTime * currentMultiplier * 1000).toInt()), () async {
          // 如果正在暂停，等待恢复
          if (isPaused) {
            _pauseCompleter = Completer<void>();
            await _pauseCompleter?.future;
          }
          timeoutCompleter.complete(true);
        });

        bool result = await Future.any<bool>([_skipCompleter.future, timeoutCompleter.future]);
        break;
        var readText = await doGetTextFromAudio(Const.wavPath);
        var same = await Util.textIsSame(s.text, readText);
        if (same) {
          break;
        } else {
          setState(() {
            currentSentenceWrong = readText;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    // 页面退出前，forceStop 当前录音，确保释放录音资源
    _forceStopCurrentRecording();
    refreshTimer?.cancel();
    super.dispose();
  }
}
