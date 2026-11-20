import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

enum NetworkStatus { unknown, connected, disconnected }

class ConnectivityService extends GetxService with WidgetsBindingObserver {
  final Future<List<ConnectivityResult>> Function() _check;
  final Stream<List<ConnectivityResult>> _changes;
  final status = NetworkStatus.unknown.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _revision = 0;
  bool _disposed = false;

  ConnectivityService({
    Future<List<ConnectivityResult>> Function()? check,
    Stream<List<ConnectivityResult>>? changes,
  }) : _check = check ?? Connectivity().checkConnectivity,
       _changes = changes ?? Connectivity().onConnectivityChanged;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _changes.listen(
      (results) {
        if (_disposed) return;
        _revision++;
        status.value = _classify(results);
      },
      onError: (Object error) {
        if (_disposed) return;
        _revision++;
        status.value = NetworkStatus.unknown;
      },
    );
    unawaited(checkNow());
  }

  NetworkStatus _classify(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none)
      ? NetworkStatus.connected
      : NetworkStatus.disconnected;

  Future<NetworkStatus> checkNow() async {
    if (_disposed) return status.value;
    final revision = ++_revision;
    try {
      final results = await _check().timeout(const Duration(seconds: 10));
      if (!_disposed && revision == _revision) {
        status.value = _classify(results);
      }
    } catch (_) {
      if (!_disposed && revision == _revision) {
        status.value = NetworkStatus.unknown;
      }
    }
    return status.value;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(checkNow());
  }

  @override
  void onClose() {
    _disposed = true;
    _revision++;
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
