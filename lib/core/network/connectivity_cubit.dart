import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ConnectivityStatus { checking, online, offline }

class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit() : super(ConnectivityStatus.checking) {
    _init();
  }

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    emit(_toStatus(results));

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      emit(_toStatus(results));
    });
  }

  ConnectivityStatus _toStatus(List<ConnectivityResult> results) {
    if (results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet)) {
      return ConnectivityStatus.online;
    }
    return ConnectivityStatus.offline;
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
