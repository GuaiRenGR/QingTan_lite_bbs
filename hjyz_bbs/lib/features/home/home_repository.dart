import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/config/app_config.dart';
import '../thread/thread_model.dart';

class HomeRepository {
  Future<ApiResult<List<ThreadModel>>> fetchFeed({
    required int page,
    required String channel,
    List<int> excludeIds = const [],
  }) async {
    final result = await ApiClient.instance.get(
      'threads/recommend',
      query: {
        'page': page,
        'page_size': AppConfig.pageSize,
        'channel': channel,
        if (excludeIds.isNotEmpty && channel == 'recommend')
          'exclude_ids': excludeIds,
      },
    );

    if (!result.success) {
      return ApiResult.fail(result.message, code: result.code);
    }

    try {
      final dynamic data = result.data;

      List list = [];

      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        if (data['list'] is List) {
          list = data['list'];
        } else if (data['data'] is List) {
          list = data['data'];
        } else if (data['items'] is List) {
          list = data['items'];
        }
      }

      final threads = list
          .map((item) => ThreadModel.fromJson(item))
          .where((item) => item.id > 0)
          .toList();

      return ApiResult.ok(threads);
    } catch (_) {
      return ApiResult.fail('列表数据解析失败');
    }
  }
}
