import 'dart:io';

import '../api/api_client.dart';
import '../api/api_result.dart';
import 'download_service.dart';

class DatabaseBackupService {
  DatabaseBackupService._();

  static final DatabaseBackupService instance = DatabaseBackupService._();

  Future<ApiResult<String>> download({
    void Function(int received, int total)? onProgress,
  }) async {
    final directory = await DownloadService.instance.getDownloadDir();
    final now = DateTime.now();
    final timestamp = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
      '_',
      now.hour.toString().padLeft(2, '0'),
      now.minute.toString().padLeft(2, '0'),
      now.second.toString().padLeft(2, '0'),
    ].join();

    var suffix = 0;
    late String path;
    do {
      final duplicateSuffix = suffix == 0 ? '' : '_$suffix';
      path = [
        directory.path,
        'qingtan_backup_$timestamp$duplicateSuffix.sql',
      ].join(Platform.pathSeparator);
      suffix++;
    } while (await File(path).exists());

    return ApiClient.instance.downloadAdminBackup(
      savePath: path,
      onReceiveProgress: onProgress,
    );
  }
}
