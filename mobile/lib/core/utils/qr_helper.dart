class QrHelper {
  QrHelper._();

  static const prefix = 'stroketion:user:';
  static const _legacyPrefix = 'hology:user:';

  static String userPayload(String userId) => '$prefix$userId';

  static String? parseUserId(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(prefix)) return raw.substring(prefix.length);
    if (raw.startsWith(_legacyPrefix)) {
      return raw.substring(_legacyPrefix.length);
    }
    return raw.length == 36 ? raw : null;
  }
}
