import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  bool get isOffline => offline.value;

  void markOnline() {
    if (offline.value) offline.value = false;
  }

  void markOffline() {
    if (!offline.value) offline.value = true;
  }
}
