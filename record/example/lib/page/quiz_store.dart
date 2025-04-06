import 'dart:async';

import '../lesson/lesson.dart';
import '../util/util.dart';

class QuizStore {
  Lesson lesson;
  bool isCn2En;

  /*这个index包括word和sentence，word走完就继续sentence*/
  int _index = 0;
  Map<int, Completer<List<String>>> options = {};

  QuizStore({
    required this.lesson,
    required this.isCn2En,
  });

  String getEn(int index) {
    if (isFin(index)) {
      return '';
    }
    if (index < lesson.words.length) {
      return lesson.words[index].text;
    } else {
      return lesson.sentences[index - lesson.words.length].text;
    }
  }

  String getCn(int index) {
    if (isFin(index)) {
      return '';
    }
    if (index < lesson.words.length) {
      return lesson.words[index].textCn;
    } else {
      return lesson.sentences[index - lesson.words.length].textCn;
    }
  }

  String getQuestion(int index) {
    if (isFin(index)) {
      return '';
    }
    if (isCn2En) {
      return getCn(index);
    } else {
      return getEn(index);
    }
  }

  String getAnswer(int index) {
    if (isFin(index)) {
      return '';
    }
    if (isCn2En) {
      return getEn(index);
    } else {
      return getCn(index);
    }
  }

  bool isFin(index) {
    return index >= lesson.words.length + lesson.sentences.length;
  }

  String getCurrentQuestion() {
    return getQuestion(_index);
  }

  String getCurrentAnswer() {
    return getAnswer(_index);
  }

  void getAllAnswer() {
    for (var i = 0; i < totalCount(); i++) {
      getOptions(i);
    }
  }

  Future<List<String>> getOptions(int i) async {
    if (isFin(i)) {
      return [];
    }
    if (options.containsKey(i)) {
      return options[i]!.future;
    }
    var question = getQuestion(i);
    var answer = getAnswer(i);
    var completer = Completer<List<String>>();
    options[i] = completer;
    Future<List<String>>? future;
    if (isCn2En) {
      future = Util.randomEnglish(question, answer);
    } else {
      future = Util.randomChinese(question, answer);
    }
    future.then((others) {
      var opts = [answer, ...others];
      opts.shuffle();
      completer.complete(opts);
    });
    return completer.future;
  }

  Future<List<String>> getCurrentOptions() async {
    getOptions(_index + 1);
    return getOptions(_index);
  }

  void moveNext() {
    _index++;
  }

  bool isFinish() {
    return isFin(_index);
  }

  int totalCount() {
    return lesson.words.length + lesson.sentences.length;
  }
}
