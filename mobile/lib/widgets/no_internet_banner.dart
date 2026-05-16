import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoInternetBanner extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnected;
  const NoInternetBanner({super.key, required this.child, this.onReconnected});

  @override
  State<NoInternetBanner> createState() => _NoInternetBannerState();
}

class _NoInternetBannerState extends State<NoInternetBanner> {
  bool _offline = false;
  late StreamSubscription<List<ConnectivityResult>> _sub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_update);
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  static const _channel = MethodChannel('doanhdd.javaup/settings');

  Future<void> _openWifiSettings() async {
    try {
      await _channel.invokeMethod('openWifiSettings');
    } catch (_) {}
  }

  void _update(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) {
      setState(() => _offline = offline);
      if (!offline) widget.onReconnected?.call();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        widget.child,
        if (_offline)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            child: AnimatedSlide(
              offset: Offset.zero,
              duration: const Duration(milliseconds: 250),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openWifiSettings,
                child: Container(
                    width: double.infinity,
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Không có kết nối mạng — Nhấn để mở cài đặt',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
          ),
      ],
    );
  }
}
