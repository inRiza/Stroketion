import 'package:flutter/foundation.dart';

class SessionRefresh {
  SessionRefresh._();

  static VoidCallback? onSessionSaved;

  static void notifySaved() => onSessionSaved?.call();
}
