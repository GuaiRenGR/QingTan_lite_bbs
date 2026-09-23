import 'dart:io';

import '../api/api_client.dart';
import '../api/api_result.dart';
import 'download_service.dart';

class MultiServerPackageService {
  MultiServerPackageService._();

  static final instance = MultiServerPackageService._();

  Future<ApiResult<String>> download({
    required Map<String, dynamic> data,
    void Function(int received, int total)? onProgress,
  }) async {
    final directory = await DownloadService.instance.getDownloadDir();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
    var suffix = 0;
    late String path;
    do {
      path = '${directory.path}${Platform.pathSeparator}qingtan_multi_server_$stamp${suffix == 0 ? '' : '_$suffix'}.zip';
      suffix++;
    } while (await File(path).exists());
    return ApiClient.instance.downloadMultiServerPackage(
      savePath: path,
      data: data,
      onReceiveProgress: onProgress,
    );
  }
}
