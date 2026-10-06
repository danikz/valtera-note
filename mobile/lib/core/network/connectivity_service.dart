import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final isOnlineStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.isOnlineStream;
});

class ConnectivityService {
  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription? _subscription;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  Stream<bool> get isOnlineStream => _controller.stream;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _controller.add(_isOnline(results));

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(_isOnline(results));
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  Future<bool> checkOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
