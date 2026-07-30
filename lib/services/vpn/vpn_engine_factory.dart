import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'android_vpn_engine.dart';
import 'ios_vpn_engine.dart';
import 'vpn_engine.dart';
import 'web_vpn_engine.dart';

VpnEngine createVpnEngine() {
  if (kIsWeb) return WebVpnEngine();

  try {
    if (Platform.isAndroid) return AndroidVpnEngine();
    if (Platform.isIOS) return IOSVpnEngine();
  } catch (_) {
    // Platform недоступен — fallback
  }

  return WebVpnEngine();
}