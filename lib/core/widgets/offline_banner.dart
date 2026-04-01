import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final StreamSubscription<dynamic> _sub;
  bool _offline = false;
  bool _showReconnected = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _sub = Connectivity().onConnectivityChanged.listen((event) {
      final connected = _isConnected(event);
      if (!connected && !_offline) {
        setState(() {
          _offline = true;
          _showReconnected = false;
        });
      } else if (connected && _offline) {
        setState(() {
          _offline = false;
          _showReconnected = true;
        });
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showReconnected = false);
          }
        });
      }
    });
  }

  Future<void> _initialize() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (!mounted) return;
      setState(() => _offline = !_isConnected(result));
    } catch (_) {
      // If connectivity fails, do nothing.
    }
  }

  bool _isConnected(Object? value) {
    if (value is ConnectivityResult) {
      return value != ConnectivityResult.none;
    }
    if (value is List<ConnectivityResult>) {
      return value.isNotEmpty && !value.contains(ConnectivityResult.none);
    }
    return true;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              offset: (_offline || _showReconnected) ? Offset.zero : const Offset(0, -1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: (_offline || _showReconnected) ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: _offline ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
                  child: Row(
                    children: [
                      Icon(
                        _offline ? Icons.wifi_off_rounded : Icons.check_circle_rounded,
                        color: _offline ? const Color(0xFF7B6000) : const Color(0xFF1B5E20),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _offline
                              ? 'No internet connection. App works fully offline.'
                              : 'Connected.',
                          style: TextStyle(
                            color: _offline ? const Color(0xFF7B6000) : const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

