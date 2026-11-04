import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:weils_api/features/workspace/domain/entities/workspace_entities.dart';
import 'package:weils_api/features/workspace/domain/use_cases/curl_codec.dart';
import 'package:weils_api/features/workspace/domain/use_cases/request_headers.dart';

/// 比较最终启用的请求头，覆盖自动生成值及大小写不敏感的覆盖规则。
Map<String, List<String>> wireHeaders(RequestSpec request) {
  final result = <String, List<String>>{};
  for (final header in [
    for (final h in defaultRequestHeaders(request, userAgent: 'test-agent'))
      if (h.value != null) Entry(name: h.name, value: h.value!),
    ...request.headers.where((h) => h.enabled && h.name.trim().isNotEmpty),
  ]) {
    result.putIfAbsent(header.name.toLowerCase(), () => []).add(header.value);
  }
  return result;
}

void main() {
  test('browser Bash command imports JSON, query values, duplicate headers and Bearer auth', () {
    final request = CurlCodec.parse(r'''
curl 'https://example.com/users?tag=a&tag=b&q=%E4%B8%AD%E6%96%87' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer secret' \
  -H 'X-Tag: first' -H 'X-Tag: second' \
  --data-raw '{"name":"中文","money":"$5"}' --compressed
''', folderId: 'users');
    expect(request.folderId, 'users');
    expect(request.method, 'POST');
    expect(request.effectiveUri.queryParametersAll['tag'], ['a', 'b']);
    expect(request.effectiveUri.queryParameters['q'], '中文');
    expect(request.bodyType, 'json');
    expect(jsonDecode(request.body), {'name': '中文', 'money': r'$5'});
    expect(request.authType, 'bearer');
    expect(request.token, 'secret');
    expect(wireHeaders(request)['x-tag'], ['first', 'second']);
    expect(request.validate(), isNull);
  });

  test('URL flags, attached options, clusters, explicit methods and empty body are preserved', () {
    final request = CurlCodec.parse(
      "curl -sSL -XPUT --url=https://example.com -H'X-Test: a:b' -d ''",
    );
    expect(request.method, 'PUT');
    expect(request.bodyType, 'text');
    expect(request.body, '');
    expect(wireHeaders(request)['x-test'], ['a:b']);
    expect(wireHeaders(request)['content-type'], [
      'application/x-www-form-urlencoded',
    ]);
    expect(CurlCodec.parse('curl -I https://example.com').method, 'HEAD');
    expect(
      CurlCodec.parse("curl --data-raw '@literal' https://example.com").body,
      '@literal',
    );
  });

  test('GET encoding and repeated data retain names, duplicates, spaces and Unicode', () {
    final request = CurlCodec.parse(
      "curl -G 'https://example.com?old=1' --data-urlencode 'q=中文 &值' -d tag=a -d tag=b",
    );
    expect(request.method, 'GET');
    expect(request.bodyType, 'none');
    expect(request.effectiveUri.queryParametersAll, {
      'old': ['1'],
      'q': ['中文 &值'],
      'tag': ['a', 'b'],
    });
    expect(
      CurlCodec.parse("curl https://example.com -d a=1 --data-binary b=2").body,
      'a=1&b=2',
    );
    expect(
      CurlCodec.parse('curl https://example.com --json \'{"a":\' --json \'1}\'')
          .body,
      '{"a":1}',
    );
  });

  test('ANSI-C and adjacent Bash quotes preserve escaped bytes, emoji and newlines', () {
    final request = CurlCodec.parse(
      r'''curl 'https://example.com' --data-raw $'O\'Brien\n\xE4\xB8\xAD\u6587\U0001F600' ''',
    );
    expect(request.body, "O'Brien\n中文😀");
    final adjacent = CurlCodec.parse(
      r'''curl https://example.com -H 'X-Name: O'"'"'Brien' ''',
    );
    expect(wireHeaders(adjacent)['x-name'], ["O'Brien"]);
    final doubleQuoted = CurlCodec.parse(
      r'''curl "https://example.com" --data-raw "{\"path\":\"a\\b\"}"''',
    );
    expect(doubleQuoted.body, r'{"path":"a\b"}');
  });

  test('PowerShell quoting and continuations preserve literal dollars and apostrophes', () {
    final request = CurlCodec.parse(
      "curl.exe `\r\n --url 'https://example.com' `\r\n --data-raw 'O''Brien \$value'",
      shell: CurlShell.powerShell,
    );
    expect(request.body, "O'Brien \$value");
    final doubled = CurlCodec.parse(
      'curl.exe https://example.com -H "X-Test: a""b"',
      shell: CurlShell.powerShell,
    );
    expect(wireHeaders(doubled)['x-test'], ['a"b']);
  });

  test(
    'authentication, cookies and shortcut headers respect custom overrides',
    () {
      final request = CurlCodec.parse(
        "curl https://example.com -u 'user:密码' -b 'sid=1; role=user' -A agent -e 'https://refer.example' -H 'User-Agent: custom'",
      );
      final headers = wireHeaders(request);
      expect(headers['authorization'], [
        'Basic ${base64Encode(utf8.encode('user:密码'))}',
      ]);
      expect(headers['cookie'], ['sid=1; role=user']);
      expect(headers['user-agent'], ['custom']);
      expect(headers['referer'], ['https://refer.example']);
      expect(
        CurlCodec.parse('curl https://example.com --oauth2-bearer secret')
            .token,
        'secret',
      );
      expect(
        CurlCodec.parse(
          "curl https://example.com --json not-json -H 'Content-Type: text/plain'",
        ).bodyType,
        'text',
      );
    },
  );

  test(
    'event-stream Accept or no-buffer selects SSE without sending anything',
    () {
      expect(
        CurlCodec.parse(
          "curl https://example.com -H 'Accept: text/event-stream'",
        ).protocol,
        'sse',
      );
      expect(CurlCodec.parse('curl -N https://example.com').protocol, 'sse');
      expect(
        CurlCodec.parse("curl https://example.com -H 'X-Empty;'")
            .headers
            .single
            .value,
        isEmpty,
      );
    },
  );

  for (final shell in CurlShell.values) {
    test('raw CRLF, controls and Unicode round trip for $shell', () {
      final request = RequestSpec(
        url: 'https://example.com',
        method: 'POST',
        bodyType: 'text',
        body: "中文 😀\r\nline2\tO'Brien\n",
      );
      final command = CurlCodec.generate(
        request,
        userAgent: 'test',
        shell: shell,
      );
      expect(CurlCodec.parse(command, shell: shell).body, request.body);
    });
    test(
      'export and import round trip preserves request semantics for $shell',
      () {
        final request = RequestSpec(
          method: 'POST',
          protocol: 'sse',
          url: 'https://example.com/a?replace=old#fragment',
          params: [
            Entry(name: 'replace', value: '中文 & space'),
            Entry(name: 'tag', value: 'a'),
            Entry(name: 'tag', value: 'b'),
            Entry(name: 'disabled', value: 'x', enabled: false),
          ],
          headers: [
            Entry(name: 'X-Test', value: "O'Brien \$literal"),
            Entry(name: 'X-Empty', value: ''),
            Entry(name: 'X-Tag', value: 'one'),
            Entry(name: 'X-Tag', value: 'two'),
            Entry(name: 'X-Disabled', enabled: false),
          ],
          authType: 'bearer',
          token: "token'\$value",
          bodyType: 'json',
          body: jsonEncode({'text': "中文 😀 O'Brien \$literal", 'line': 'a\nb'}),
        );
        final command = CurlCodec.generate(
          request,
          userAgent: 'test-agent',
          shell: shell,
        );
        final restored = CurlCodec.parse(command, shell: shell);
        expect(restored.id, isNot(request.id));
        expect(restored.method, request.method);
        expect(restored.protocol, request.protocol);
        expect(restored.effectiveUri, request.effectiveUri);
        expect(restored.body, request.body);
        expect(restored.authType, 'bearer');
        expect(restored.token, request.token);
        expect(wireHeaders(restored), wireHeaders(request));
        expect(command, isNot(contains('X-Disabled')));
        expect(command, isNot(contains('Content-Length')));
        final head = CurlCodec.generate(
          RequestSpec(method: 'HEAD', url: 'https://example.com'),
          userAgent: 'test-agent',
          shell: shell,
        );
        expect(head, contains('--head'));
        expect(CurlCodec.parse(head, shell: shell).method, 'HEAD');
      },
    );
  }

  for (final command in [
    '',
    'wget https://example.com',
    'curl',
    "curl 'https://example.com",
    'curl https://example.com -H',
    'curl https://example.com --proxy http://localhost',
    'curl https://example.com -k',
    'curl https://example.com -F file=@file.txt',
    'curl https://example.com --data @file.txt',
    'curl https://example.com --data-binary @-',
    'curl https://example.com --json @file.json',
    'curl https://example.com --data-urlencode name@file.txt',
    'curl https://example.com -H @headers.txt',
    "curl https://example.com -H 'Accept:'",
    "curl https://example.com -H 'Bad Header: value'",
    r'curl https://example.com -H "X-Test: $TOKEN"',
    r'curl https://example.com -d $(whoami)',
    'curl https://example.com | other',
    'curl https://example.com; other',
    'curl https://example.com > file',
    'curl https://example.com https://second.example',
    'curl https://example.com --next https://second.example',
    "curl 'https://example.com/{a,b}'",
    'curl ftp://example.com',
    'curl http://user:pass@example.com',
    'curl https://example.com -u user',
    'curl https://example.com --head -d body',
    'curl ^"https://example.com^" ^\n -H ^"X-Test: value^"',
    r"curl https://example.com --data-raw $'\xff'",
    r"curl https://example.com --data-raw $'\0'",
  ]) {
    test('unsupported or malformed command is rejected: $command', () {
      expect(
        () => CurlCodec.parse(command),
        throwsA(isA<CurlFormatException>()),
      );
    });
  }
  test('literal braces are supported with globoff and invalid export stays a domain error', () {
    expect(
      CurlCodec.parse("curl --globoff 'https://example.com/{literal}'").url,
      contains('literal'),
    );
    expect(
      () => CurlCodec.generate(
        RequestSpec(url: 'http://[invalid'),
        userAgent: 'test',
      ),
      throwsA(isA<CurlFormatException>()),
    );
    expect(
      () => CurlCodec.generate(
        RequestSpec(url: 'https://example.com', bodyType: 'text', body: '\x00'),
        userAgent: 'test',
      ),
      throwsA(isA<CurlFormatException>()),
    );
  });
}
