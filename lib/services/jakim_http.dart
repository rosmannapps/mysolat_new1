// lib/services/jakim_http.dart
//
// Centralized HTTP helper for JAKIM e-Solat API requests.
//
// JAKIM's web infrastructure (WAF / bot protection) rejects requests that
// look like scripts (HTTP 403 Forbidden) — typically those missing a real
// browser User-Agent. This helper attaches browser-like headers so the
// request is accepted.
//
// If JAKIM changes its rules again in the future, update only this file.

import 'package:http/http.dart' as http;

class JakimHttp {
  JakimHttp._();

  // A current iOS Safari user-agent. Update annually.
  static const String _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 '
      'Mobile/15E148 Safari/604.1';

  /// Default headers that make the request look like a browser visit
  /// to e-solat.gov.my. Override per-call by passing [extraHeaders].
  static Map<String, String> defaultHeaders() => const {
    'User-Agent': _userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9,ms;q=0.8',
    'Referer': 'https://www.e-solat.gov.my/',
    'Origin': 'https://www.e-solat.gov.my',
    'Cache-Control': 'no-cache',
    'X-Requested-With': 'XMLHttpRequest',
    'Connection': 'keep-alive',
  };

  /// GET wrapper. Pass an existing [client] if you want connection reuse,
  /// otherwise a one-shot client is used.
  static Future<http.Response> get(
      Uri uri, {
        http.Client? client,
        Map<String, String>? extraHeaders,
        Duration timeout = const Duration(seconds: 30),
      }) async {
    final headers = <String, String>{
      ...defaultHeaders(),
      if (extraHeaders != null) ...extraHeaders,
    };

    final ownsClient = client == null;
    final c = client ?? http.Client();
    try {
      return await c.get(uri, headers: headers).timeout(timeout);
    } finally {
      if (ownsClient) c.close();
    }
  }
}