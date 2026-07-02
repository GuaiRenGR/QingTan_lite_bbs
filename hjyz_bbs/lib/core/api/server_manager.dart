import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'server_config.dart';

class ServerManager {
  ServerManager._();
  static final ServerManager instance = ServerManager._();

  final List<ServerConfig> _servers = [];
  ServerConfig? _currentServer;
  final Map<int, ServerHealth> _healthStatus = {};
  Timer? _healthCheckTimer;

  List<ServerConfig> get activeServers {
    final now = DateTime.now();
    final result = <ServerConfig>[];
    for (final s in _servers) {
      final health = _healthStatus[s.id];
      if (health == null || health.reachable) {
        result.add(s);
      } else if (now.difference(health.lastChecked).inSeconds > 30) {
        _healthStatus[s.id] = health.copyWith(reachable: true);
        result.add(s);
      }
    }
    if (result.isEmpty) {
      return List.from(_servers);
    }
    return result;
  }

  ServerConfig? get currentServer => _currentServer;
  int get serverCount => _servers.length;

  Future<void> init({List<ServerConfig>? servers}) async {
    if (servers != null) {
      _servers.addAll(servers);
    } else {
      _servers.addAll(AppConfig.serverList);
    }

    if (_servers.isEmpty) {
      _servers.add(const ServerConfig(
        id: 1,
        name: '默认服务器',
        url: 'http://newbbs.hj1bbs.top/index.php',
      ));
    }

    _currentServer = _servers.first;

    await _initialHealthCheck();

    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _backgroundHealthCheck(),
    );
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }

  Future<void> _initialHealthCheck() async {
    final results = await Future.wait(
      _servers.map((s) => _pingServer(s)),
      eagerError: false,
    );

    int bestIdx = 0;
    int bestLatency = 999999;

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      final s = _servers[i];
      _healthStatus[s.id] = r;
      if (r.reachable && r.latencyMs < bestLatency) {
        bestLatency = r.latencyMs;
        bestIdx = i;
      }
    }

    _currentServer = _servers[bestIdx];
  }

  Future<void> _backgroundHealthCheck() async {
    await Future.wait(
      _servers.map((s) => _pingServer(s).then((r) {
        _healthStatus[s.id] = r;
      })),
      eagerError: false,
    );
  }

  Future<ServerHealth> _pingServer(ServerConfig server) async {
    final start = DateTime.now();
    final dio = Dio(BaseOptions(
      baseUrl: server.url,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    try {
      final response = await dio.get('', queryParameters: {'route': 'system/ping'});
      if (response.statusCode == 200) {
        final latency = DateTime.now().difference(start).inMilliseconds;
        return ServerHealth(
          reachable: true,
          latencyMs: latency,
          lastChecked: DateTime.now(),
          consecutiveFailures: 0,
        );
      }
    } catch (_) {}

    final old = _healthStatus[server.id];
    return ServerHealth(
      reachable: false,
      latencyMs: 99999,
      lastChecked: DateTime.now(),
      consecutiveFailures: (old?.consecutiveFailures ?? 0) + 1,
    );
  }

  void reportSuccess(int serverId) {
    final old = _healthStatus[serverId];
    if (old != null) {
      _healthStatus[serverId] = old.copyWith(
        reachable: true,
        consecutiveFailures: 0,
        lastChecked: DateTime.now(),
      );
    }
  }

  void reportFailure(int serverId) {
    final old = _healthStatus[serverId] ??
        ServerHealth(lastChecked: DateTime(2000));
    _healthStatus[serverId] = old.copyWith(
      reachable: false,
      consecutiveFailures: old.consecutiveFailures + 1,
      lastChecked: DateTime.now(),
    );

    // 如果当前服务器连续失败，自动切换
    if (_currentServer?.id == serverId && old.consecutiveFailures >= 1) {
      _switchToNextServer();
    }
  }

  void _switchToNextServer() {
    final active = activeServers;
    if (active.length <= 1) return;

    final currentIdx = active.indexWhere(
      (s) => s.id == _currentServer?.id,
    );
    final nextIdx = (currentIdx + 1) % active.length;
    _currentServer = active[nextIdx];
  }

  Future<ServerConfig?> selectBestServer() async {
    if (_servers.isEmpty) return null;

    final reachable = activeServers;
    if (reachable.isEmpty) {
      _currentServer = _servers[Random().nextInt(_servers.length)];
      return _currentServer;
    }

    // 按权重选择
    final totalWeight = reachable.fold(0, (int sum, s) => sum + s.weight);
    int r = Random().nextInt(totalWeight);
    for (final s in reachable) {
      r -= s.weight;
      if (r < 0) {
        _currentServer = s;
        return s;
      }
    }

    _currentServer = reachable.first;
    return _currentServer;
  }

  Future<int> checkAllServers() async {
    await _initialHealthCheck();
    return _servers.length;
  }

  ServerConfig getServer(int serverId) {
    return _servers.firstWhere(
      (s) => s.id == serverId,
      orElse: () => _servers.first,
    );
  }
}
