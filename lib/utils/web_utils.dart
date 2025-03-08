import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:universal_html/html.dart' as html;
import 'dart:ui_web' as ui;

void registerViewFactory(String viewType, String url) {
  if (kIsWeb) {
    ui.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
    debugPrint('Registered view factory for $viewType with URL: $url');
  }
}