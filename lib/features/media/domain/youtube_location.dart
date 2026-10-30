/// Accepts public YouTube links or a search, without opening arbitrary websites.
class YouTubeLocation {
  static final home = Uri.https('m.youtube.com', '/');
  static const _contentHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };
  static const _accountHosts = {
    'accounts.google.com',
    'consent.google.com',
    'consent.youtube.com',
  };
  static const _savedParameters = {
    'v',
    'list',
    'index',
    't',
    'start',
    'search_query',
  };

  static bool isContent(Uri uri) =>
      uri.scheme == 'https' &&
      (!uri.hasPort || uri.port == 443) &&
      uri.userInfo.isEmpty &&
      _contentHosts.contains(uri.host.toLowerCase());

  static bool allowsNavigation(Uri uri) =>
      isContent(uri) ||
      (uri.scheme == 'https' &&
          (!uri.hasPort || uri.port == 443) &&
          uri.userInfo.isEmpty &&
          _accountHosts.contains(uri.host.toLowerCase()));

  static Uri fromInput(String input) {
    var value = input.trim();
    if (value.isEmpty) return home;
    if (value.length > 2048) {
      throw const FormatException('Liên kết hoặc từ khóa quá dài.');
    }
    if (RegExp(
      r'^(www\.|m\.|music\.)?youtube\.com(/|$)|^youtu\.be/',
      caseSensitive: false,
    ).hasMatch(value)) {
      value = 'https://$value';
    }
    if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(value)) {
      final uri = Uri.tryParse(value);
      if (uri == null || !isContent(uri)) {
        throw const FormatException('Chỉ nhận liên kết HTTPS của YouTube.');
      }
      return forStorage(uri) ?? home;
    }
    if (value.length > 200) {
      throw const FormatException('Từ khóa tìm kiếm tối đa 200 ký tự.');
    }
    return Uri.https('m.youtube.com', '/results', {'search_query': value});
  }

  /// Retains only playback/search parameters, never Google sign-in redirects,
  /// credentials, fragments or tracking parameters.
  static Uri? forStorage(Uri uri) {
    if (!isContent(uri) || uri.toString().length > 2048) return null;
    if (RegExp(r'^/(signin|logout|redirect|account)(/|$)').hasMatch(uri.path)) {
      return null;
    }
    final parameters = <String, String>{
      for (final entry in uri.queryParameters.entries)
        if (_savedParameters.contains(entry.key)) entry.key: entry.value,
    };
    var path = uri.path;
    if (uri.host.toLowerCase() == 'youtu.be') {
      final id = uri.pathSegments.firstOrNull;
      if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
        return home;
      }
      path = '/watch';
      parameters['v'] = id;
    }
    return Uri.https(
      'm.youtube.com',
      path.isEmpty ? '/' : path,
      parameters.isEmpty ? null : parameters,
    );
  }
}
