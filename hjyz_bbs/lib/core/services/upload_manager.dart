import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class UploadTask {
  UploadTask({required this.id, required this.name});

  final String id;
  final String name;
  double progress = 0;
  bool paused = false;
  bool cancelRequested = false;
  CancelToken? cancelToken;
  Future<void> Function()? resume;
}

class UploadManager extends ChangeNotifier {
  UploadManager._();
  static final instance = UploadManager._();

  final Map<String, UploadTask> _tasks = {};
  List<UploadTask> get activeTasks => List.unmodifiable(_tasks.values);

  Future<T> enqueue<T>({
    required String name,
    required Future<T> Function(CancelToken token, void Function(int, int) progress) run,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}_${_tasks.length}';
    final task = UploadTask(id: id, name: name);
    _tasks[id] = task;
    notifyListeners();
    final completer = Completer<T>();

    Future<void> execute() async {
      task.paused = false;
      task.cancelRequested = false;
      task.cancelToken = CancelToken();
      notifyListeners();
      try {
        final result = await run(task.cancelToken!, (sent, total) {
          if (total > 0) task.progress = (sent / total).clamp(0, 1);
          notifyListeners();
        });
        if (task.paused) return;
        if (!completer.isCompleted) completer.complete(result);
        _tasks.remove(id);
        notifyListeners();
      } catch (error, stack) {
        if (task.paused) return;
        if (!completer.isCompleted) completer.completeError(error, stack);
        _tasks.remove(id);
        notifyListeners();
      }
    }

    task.resume = execute;
    execute();
    return completer.future;
  }

  void pause(String id) {
    final task = _tasks[id];
    if (task == null || task.paused) return;
    task.paused = true;
    task.cancelRequested = true;
    task.cancelToken?.cancel('paused');
    notifyListeners();
  }

  void resume(String id) {
    final task = _tasks[id];
    if (task == null || !task.paused) return;
    task.resume?.call();
  }
}
