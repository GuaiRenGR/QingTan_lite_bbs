class ServerConfig {
  final int id;
  final String name;
  final String url;
  final int weight;

  const ServerConfig({
    required this.id,
    required this.name,
    required this.url,
    this.weight = 5,
  });

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString().trim() ?? '',
      url: json['url']?.toString().trim() ?? '',
      weight: int.tryParse(json['weight']?.toString() ?? '') ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'weight': weight,
      };
}

class ServerHealth {
  final bool reachable;
  final int latencyMs;
  final DateTime lastChecked;
  final int consecutiveFailures;

  const ServerHealth({
    this.reachable = true,
    this.latencyMs = 0,
    required this.lastChecked,
    this.consecutiveFailures = 0,
  });

  ServerHealth copyWith({
    bool? reachable,
    int? latencyMs,
    DateTime? lastChecked,
    int? consecutiveFailures,
  }) {
    return ServerHealth(
      reachable: reachable ?? this.reachable,
      latencyMs: latencyMs ?? this.latencyMs,
      lastChecked: lastChecked ?? this.lastChecked,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    );
  }
}
