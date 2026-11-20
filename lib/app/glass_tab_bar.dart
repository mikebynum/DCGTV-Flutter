import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GlassTabBar extends StatefulWidget {
  const GlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const height = 60.0;
  static const _viewType = 'dcgtv/glass_tabs';
  static const _capabilities = MethodChannel('dcgtv/tab_bar');

  static Future<bool> isSupported() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _capabilities.invokeMethod<bool>('supportsLiquidGlass') ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar> {
  MethodChannel? _channel;

  void _attach(int id) {
    if (!mounted) return;
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('${GlassTabBar._viewType}/$id');
    _channel!.setMethodCallHandler((call) async {
      final index = call.arguments;
      if (mounted &&
          call.method == 'select' &&
          index is int &&
          index >= 0 &&
          index < 4) {
        widget.onSelected(index);
      }
    });
    unawaited(_syncSelection());
  }

  Future<void> _syncSelection() async {
    try {
      await _channel?.invokeMethod<void>('setSelection', widget.selectedIndex);
    } on MissingPluginException {
      // The view may have been removed while changing routes.
    } on PlatformException catch (error) {
      debugPrint('Could not update the iOS tab bar: $error');
    }
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      unawaited(_syncSelection());
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: GlassTabBar.height,
        child: UiKitView(
          viewType: GlassTabBar._viewType,
          layoutDirection: Directionality.of(context),
          creationParams: widget.selectedIndex,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _attach,
        ),
      );
}
