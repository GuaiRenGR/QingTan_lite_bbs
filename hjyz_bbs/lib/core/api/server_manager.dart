import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/app_logger.dart';
import 'server_config.dart';

class ServerManager {
  ServerManager._();
  static final ServerManager instance = ServerManager._();

  static const _serverCacheKey = 'server_list_cache_v1';
  static const _selectedServerKey = 'selected_server_id_v1';

  final List<ServerConfig> _servers = [];
  final Map<int, ServerHealth> _healthStatus = {};
  ServerConfig? _currentServer;
  int? _selectedServerId;
  Timer? _healthCheckTimer;

  List<ServerConfig> get servers => List.unmodifiable(_servers);
  ServerConfig? get currentServer => _currentServer;
  int get serverCount => _servers.length;
  ServerHealth? healthFor(int serverId) => _healthStatus[serverId];

  List<ServerConfig> get activeServers {
    final now = DateTime.now();
    final result = <ServerConfig>[];
    for (final server in _servers) {
      final health = _healthStatus[server.id];
      if (health == null || health.reachable) {
        result.add(server);
      } else if (now.difference(health.lastChecked).inSeconds > 30) {
        result.add(server);
      }
    }
    return result.isEmpty ? List.from(_servers) : result;
  }

  List<ServerConfig> get requestServers {
    final active = activeServers;
    final current = _currentServer;
    if (current == null) return active;
    return [
      current,
      ...active.where((server) => server.id != current.id),
    ];
  }

  Future<void> init({List<ServerConfig>? servers}) async {
    _healthCheckTimer?.cancel();
    _servers.clear();
    _healthStatus.clear();

    final preferences = await SharedPreferences.getInstance();
    _selectedServerId = preferences.getInt(_selectedServerKey);
    final cached = _readCachedServers(preferences);
    _replaceServers(
      cached.isNotEmpty ? cached : (servers ?? AppConfig.serverList),
    );
    if (_servers.isEmpty) {
      _replaceServers(const [
        ServerConfig(
          id: 1,
          name: '默认服务器',
          url: AppConfig.apiEntry,
        ),
      ]);
    }

    _currentServer = _findServer(_selectedServerId) ?? _servers.first;
    await _checkAllServers(selectFastest: _selectedServerId == null);
    await refreshServerList();

    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkAllServers(),
    );
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }

  Future<bool> refreshServerList() async {
    final candidates = requestServers;
    for (final server in candidates) {
      try {
        final response = await _discoveryDio(server.url).get(
          '',
          queryParameters: {'route': 'system/servers'},
        );
        final body = response.data;
        final data = body is Map ? body['data'] : null;
        final rawServers = data is Map ? data['servers'] : null;
        if (rawServers is! List) continue;

        final discovered = rawServers
            .whereType<Map>()
            .map(
              (item) =>
                  ServerConfig.fromJson(Map<String, dynamic>.from(item)),
            )
            .where(_isValidServer)
            .toList(growable: false);
        if (discovered.isEmpty) continue;

        final previous = _currentServer;
        _replaceServers(discovered);
        ServerConfig? retained;
        for (final server in _servers) {
          if (server.id == previous?.id || server.url == previous?.url) {
            retained = server;
            break;
          }
        }
        _currentServer =
            _findServer(_selectedServerId) ?? retained ?? _servers.first;
        await _cacheServers();
        await _checkAllServers(selectFastest: _selectedServerId == null);
        return true;
      } catch (error) {
        await AppLogger.log(
          'ServerManager',
          'discovery failed: serverId=${server.id} error=$error',
        );
      }
    }
    return false;
  }

  Future<int> checkAllServers() async {
    await _checkAllServers();
    return _servers.length;
  }

  Future<void> selectServer(int serverId) async {
    final server = _findServer(serverId);
    if (server == null) return;
    _selectedServerId = server.id;
    _currentServer = server;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_selectedServerKey, server.id);
  }

  Future<ServerConfig?> selectBestServer() async {
    await _checkAllServers(selectFastest: true);
    return _currentServer;
  }

  ServerConfig getServer(int serverId) {
    return _findServer(serverId) ?? _servers.first;
  }

  void reportSuccess(int serverId) {
    final old = _healthStatus[serverId];
    _healthStatus[serverId] = ServerHealth(
      reachable: true,
      latencyMs: old?.latencyMs ?? 0,
      lastChecked: DateTime.now(),
    );
  }

  void reportFailure(int serverId) {
    final old = _healthStatus[serverId] ??
        ServerHealth(lastChecked: DateTime(2000));
    _healthStatus[serverId] = old.copyWith(
      reachable: false,
      consecutiveFailures: old.consecutiveFailures + 1,
      lastChecked: DateTime.now(),
    );
    if (_currentServer?.id == serverId && old.consecutiveFailures >= 1) {
      _switchToNextServer();
    }
  }

  Future<void> _checkAllServers({bool selectFastest = false}) async {
    if (_servers.isEmpty) return;
    final results = await Future.wait(
      _servers.map(_pingServer),
      eagerError: false,
    );
    for (var index = 0; index < results.length; index++) {
      _healthStatus[_servers[index].id] = results[index];
    }
    if (selectFastest) {
      final reachable = _servers.where(
        (server) => _healthStatus[server.id]?.reachable == true,
      );
      if (reachable.isNotEmpty) {
        _currentServer = reachable.reduce((best, candidate) {
          final bestLatency = _healthStatus[best.id]?.latencyMs ?? 99999;
          final candidateLatency =
              _healthStatus[candidate.id]?.latencyMs ?? 99999;
          return candidateLatency < bestLatency ? candidate : best;
        });
      }
    }
  }

  Future<ServerHealth> _pingServer(ServerConfig server) async {
    final start = DateTime.now();
    try {
      final response = await _discoveryDio(server.url).get(
        '',
        queryParameters: {'route': 'system/ping'},
      );
      if (response.statusCode == 200) {
        return ServerHealth(
          reachable: true,
          latencyMs: DateTime.now().difference(start).inMilliseconds,
          lastChecked: DateTime.now(),
        );
      }
    } catch (error) {
      await AppLogger.log(
        'ServerManager',
        'ping failed: serverId=${server.id} error=$error',
      );
    }
    final old = _healthStatus[server.id];
    return ServerHealth(
      reachable: false,
      latencyMs: 99999,
      lastChecked: DateTime.now(),
      consecutiveFailures: (old?.consecutiveFailures ?? 0) + 1,
    );
  }

  Dio _discoveryDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 8),
        responseType: ResponseType.json,
      ),
    );
  }

  void _switchToNextServer() {
    final active = activeServers
        .where((server) => server.id != _currentServer?.id)
        .toList();
    if (active.isNotEmpty) _currentServer = active.first;
  }

  void _replaceServers(Iterable<ServerConfig> servers) {
    final unique = <int, ServerConfig>{};
    for (final server in servers.where(_isValidServer)) {
      unique[server.id] = server;
    }
    _servers
      ..clear()
      ..addAll(unique.values);
    _healthStatus.removeWhere(
      (id, _) => !_servers.any((server) => server.id == id),
    );
  }

  bool _isValidServer(ServerConfig server) {
    final uri = Uri.tryParse(server.url);
    return server.id > 0 &&
        server.name.isNotEmpty &&
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  ServerConfig? _findServer(int? id) {
    if (id == null) return null;
    for (final server in _servers) {
      if (server.id == id) return server;
    }
    return null;
  }

  List<ServerConfig> _readCachedServers(SharedPreferences preferences) {
    try {
      final raw = preferences.getString(_serverCacheKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => ServerConfig.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(_isValidServer)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _cacheServers() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _serverCacheKey,
      jsonEncode(_servers.map((server) => server.toJson()).toList()),
    );
  }
}
