import 'dart:convert';

import '../entities/workspace_entities.dart';
import 'request_headers.dart';

enum CurlShell { bash, powerShell }

/// cURL 命令不完整或包含当前请求模型无法表示的选项。
class CurlFormatException implements Exception {
  const CurlFormatException(this.message);
  final String message;

  /// 返回可直接显示在导入弹窗中的中文说明。
  @override
  String toString() => message;
}

/// 只转换请求配置，不执行命令、展开环境变量或访问本地文件。
abstract final class CurlCodec {
  static const _methods = {
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
    'CONNECT',
    'TRACE',
  };
  static const _valueOptions = {
    '-X',
    '--request',
    '-H',
    '--header',
    '-d',
    '--data',
    '--data-ascii',
    '--data-raw',
    '--data-binary',
    '--data-urlencode',
    '--json',
    '--url',
    '-A',
    '--user-agent',
    '-e',
    '--referer',
    '-b',
    '--cookie',
    '-u',
    '--user',
    '--oauth2-bearer',
  };
  static const _flags = {
    '-s',
    '--silent',
    '-S',
    '--show-error',
    '-v',
    '--verbose',
    '-i',
    '--include',
    '-L',
    '--location',
    '--compressed',
    '-g',
    '--globoff',
    '--basic',
    '--no-progress-meter',
    '--progress-bar',
  };

  /// 将单个 cURL 命令解析为新请求；正文与查询参数保留原始业务内容。
  static RequestSpec parse(
    String command, {
    String folderId = 'default',
    CurlShell shell = CurlShell.bash,
  }) {
    final args = _words(command, shell);
    if (args.isEmpty ||
        !RegExp(
          r'(^|[/\\])curl(?:\.exe)?$',
          caseSensitive: false,
        ).hasMatch(args.first)) {
      throw const CurlFormatException('请粘贴以 curl 或 curl.exe 开头的完整命令。');
    }
    String? url, method, user, bearer;
    var get = false,
        head = false,
        noBuffer = false,
        json = false,
        globoff = false;
    var hasData = false, body = '';
    final headers = <Entry>[];
    final generated = <String, String>{};
    var positional = false;
    for (var i = 1; i < args.length; i++) {
      var option = args[i];
      String? attached;
      if (option == '--' && !positional) {
        positional = true;
        continue;
      }
      if (positional || !option.startsWith('-')) {
        if (url != null) {
          throw const CurlFormatException('一次只能导入一个请求，请勿粘贴多个 URL 或多条命令。');
        }
        url = option;
        continue;
      }
      if (option.startsWith('--')) {
        final equal = option.indexOf('=');
        if (equal >= 0) {
          attached = option.substring(equal + 1);
          option = option.substring(0, equal);
        }
      } else if (option.length > 2) {
        attached = option.substring(2);
        option = option.substring(0, 2);
        if (!_valueOptions.contains(option)) {
          args.insert(i + 1, '-$attached');
          attached = null;
        }
      }
      if (_valueOptions.contains(option)) {
        final String value;
        if (attached != null) {
          value = attached;
        } else {
          if (++i >= args.length) throw CurlFormatException('$option 缺少参数值。');
          value = args[i];
        }
        switch (option) {
          case '-X' || '--request':
            method = value.toUpperCase();
          case '-H' || '--header':
            headers.add(_header(value));
          case '--url':
            if (url != null) throw const CurlFormatException('一次只能导入一个 URL。');
            url = value;
          case '-A' || '--user-agent':
            generated['User-Agent'] = value;
          case '-e' || '--referer':
            if (value.endsWith(';auto')) {
              throw const CurlFormatException('暂不支持 Referer 的 ;auto 选项。');
            }
            generated['Referer'] = value;
          case '-b' || '--cookie':
            if (!value.contains('=')) {
              throw const CurlFormatException(
                'Cookie 只支持直接填写 name=value，不支持读取 Cookie 文件。',
              );
            }
            generated['Cookie'] = value;
          case '-u' || '--user':
            if (!value.contains(':')) {
              throw const CurlFormatException(
                '用户名认证须完整填写 user:password，不支持交互式输入密码。',
              );
            }
            user = value;
          case '--oauth2-bearer':
            bearer = value;
          default:
            var part = value;
            if (option != '--data-raw' &&
                option != '--data-urlencode' &&
                part.startsWith('@')) {
              throw const CurlFormatException('暂不支持从文件或标准输入读取正文，请直接粘贴正文内容。');
            }
            if (option == '--data-urlencode') part = _encodeData(value);
            if (hasData && option != '--json') body += '&';
            body += part;
            hasData = true;
            if (option == '--json') json = true;
        }
      } else {
        if (attached != null) throw CurlFormatException('$option 不接受参数值。');
        switch (option) {
          case '-G' || '--get':
            get = true;
          case '--no-get':
            get = false;
          case '-I' || '--head':
            head = true;
          case '-N' || '--no-buffer':
            noBuffer = true;
          case '-g' || '--globoff':
            globoff = true;
          default:
            if (!_flags.contains(option)) {
              throw CurlFormatException(
                '暂不支持选项 $option。文件上传、代理、证书、脚本及输出到文件等选项无法导入。',
              );
            }
        }
      }
    }
    if (url == null || url.isEmpty) {
      throw const CurlFormatException('命令中缺少请求 URL。');
    }
    if (!globoff &&
        RegExp(r'\{[^{}]*\}|\[[0-9a-zA-Z]+-[0-9a-zA-Z]+(?::\d+)?\]')
            .hasMatch(url)) {
      throw const CurlFormatException(
        'URL 包含 cURL 批量展开语法，请使用单个 URL；字面量括号请添加 --globoff。',
      );
    }
    var uri = _uri(url);
    if (head && (hasData && !get || method != null && method != 'HEAD')) {
      throw const CurlFormatException('--head 不能与正文或其他请求方法组合导入。');
    }
    if (get && hasData && body.isNotEmpty) {
      uri = uri.replace(
        query: uri.hasQuery && uri.query.isNotEmpty
            ? '${uri.query}&$body'
            : body,
      );
    }
    final verb =
        method ??
        (head
            ? 'HEAD'
            : get
            ? 'GET'
            : hasData
            ? 'POST'
            : 'GET');
    if (!_methods.contains(verb)) throw CurlFormatException('暂不支持请求方法 $verb。');
    final custom = headers.map((h) => h.name.toLowerCase()).toSet();
    if (json) {
      generated['Content-Type'] = 'application/json';
      generated['Accept'] = 'application/json';
    } else if (hasData && !get) {
      generated['Content-Type'] = 'application/x-www-form-urlencoded';
    }
    if (bearer != null && user != null) {
      throw const CurlFormatException('请勿同时指定用户名认证和 Bearer Token。');
    }
    if (user != null) {
      generated['Authorization'] = 'Basic ${base64Encode(utf8.encode(user))}';
    }
    if (bearer != null) generated['Authorization'] = 'Bearer $bearer';
    for (final entry in generated.entries) {
      if (!custom.contains(entry.key.toLowerCase())) {
        headers.add(_header('${entry.key}: ${entry.value}'));
      }
    }
    var authType = 'none', token = '';
    final authorization = headers
        .where((h) => h.name.toLowerCase() == 'authorization')
        .toList();
    if (authorization.length == 1 &&
        authorization.single.value.toLowerCase().startsWith('bearer ')) {
      authType = 'bearer';
      token = authorization.single.value.substring(7);
      headers.remove(authorization.single);
    }
    final hasBody = hasData && !get;
    var bodyType = hasBody ? 'text' : 'none';
    final contentType = headers
        .where((h) => h.name.toLowerCase() == 'content-type')
        .firstOrNull
        ?.value
        .split(';')
        .first
        .trim()
        .toLowerCase();
    if (hasBody &&
        (contentType == 'application/json' ||
            contentType?.endsWith('+json') == true)) {
      try {
        jsonDecode(body);
        bodyType = 'json';
      } on FormatException {
        // 无效 JSON 仍以原始文本保留，Content-Type 由显式 Header 维持。
      }
    }
    final sse =
        noBuffer ||
        headers.any(
          (h) =>
              h.name.toLowerCase() == 'accept' &&
              h.value.toLowerCase().contains('text/event-stream'),
        );
    return RequestSpec(
      name: '${uri.host}${uri.path == '/' ? '' : uri.path}',
      folderId: folderId,
      method: verb,
      protocol: sse ? 'sse' : 'http',
      url: uri.toString(),
      headers: headers,
      bodyType: bodyType,
      body: hasBody ? body : '',
      authType: authType,
      token: token,
    );
  }

  /// 按应用实际启用的参数、默认 Headers 与认证生成可复制命令。
  static String generate(
    RequestSpec request, {
    required String userAgent,
    CurlShell shell = CurlShell.bash,
  }) {
    late final Uri uri;
    try {
      uri = _uri(request.effectiveUri.toString());
    } on FormatException {
      throw const CurlFormatException('URL 格式无效，请先填写完整的请求地址。');
    }
    if (request.method == 'HEAD' && request.bodyType != 'none') {
      throw const CurlFormatException('HEAD 请求导出时不能带正文，请先将正文类型设为“无 Body”。');
    }
    if (!_methods.contains(request.method)) {
      throw const CurlFormatException('当前请求方法无法导出。');
    }
    final headers = [
      for (final h in defaultRequestHeaders(request, userAgent: userAgent))
        if (h.value != null && !['Host', 'Content-Length'].contains(h.name))
          Entry(name: h.name, value: h.value!),
      ...request.headers.where((h) => h.enabled && h.name.trim().isNotEmpty),
    ];
    final quote = shell == CurlShell.bash ? _bashQuote : _powerShellQuote;
    final lines = <String>[
      shell == CurlShell.bash ? 'curl' : 'curl.exe',
      '--globoff',
      '--location',
      '--compressed',
      if (request.protocol == 'sse') '--no-buffer',
      if (request.method == 'HEAD')
        '--head'
      else
        '--request ${quote(request.method)}',
      '--url ${quote(uri.toString())}',
      for (final h in headers) '--header ${quote(_exportHeader(h))}',
      if (request.bodyType != 'none') '--data-raw ${quote(request.body)}',
    ];
    return lines.join(shell == CurlShell.bash ? ' \\\n  ' : ' `\n  ');
  }

  /// 校验 URL，禁止导入当前客户端不支持的协议或 URL 内嵌认证。
  static Uri _uri(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const CurlFormatException(
        'URL 须为完整的 HTTP/HTTPS 地址，认证信息请通过 Header 或 --user 指定。',
      );
    }
    return uri;
  }

  /// 解析显式 Header；空值使用 cURL 的 Name; 形式，移除 Header 的语法不做近似转换。
  static Entry _header(String text) {
    final colon = text.indexOf(':');
    final empty = colon < 0 && text.endsWith(';');
    if (colon < 0 && !empty) {
      throw const CurlFormatException('Header 须为 Name: value，不支持从文件读取 Header。');
    }
    final name = text.substring(0, empty ? text.length - 1 : colon).trim();
    final value = empty ? '' : text.substring(colon + 1).trimLeft();
    if (!RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$").hasMatch(name) ||
        value.contains(RegExp(r'[\r\n\x00]'))) {
      throw const CurlFormatException('Header 名称或值无效，请检查换行与特殊字符。');
    }
    if (!empty && value.isEmpty) {
      throw const CurlFormatException(
        '暂不支持 Name: 移除 Header 的语法；显式空 Header 请使用 Name;。',
      );
    }
    return Entry(name: name, value: value);
  }

  /// 对显式空 Header 使用分号，避免 cURL 将其解释为移除该 Header。
  static String _exportHeader(Entry entry) {
    final name = entry.name.trim();
    if (entry.value.isEmpty) {
      _header('$name;');
      return '$name;';
    }
    _header('$name: ${entry.value}');
    return '$name: ${entry.value}';
  }

  /// 按 UTF-8 编码表单值，支持内联内容，拒绝文件引用。
  static String _encodeData(String text) {
    final equal = text.indexOf('=');
    if (equal < 0 && text.contains('@')) {
      throw const CurlFormatException('--data-urlencode 暂不支持文件引用。');
    }
    final name = equal > 0 ? '${text.substring(0, equal)}=' : '';
    final value = equal >= 0 ? text.substring(equal + 1) : text;
    final encoded = utf8
        .encode(value)
        .map(
          (b) =>
              b >= 65 && b <= 90 ||
                  b >= 97 && b <= 122 ||
                  b >= 48 && b <= 57 ||
                  [45, 46, 95, 126].contains(b)
              ? String.fromCharCode(b)
              : '%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}',
        )
        .join();
    return '$name$encoded';
  }

  /// 使用单引号保护 Bash 参数，单引号本身通过相邻引号片段表示。
  static String _bashQuote(String text) {
    _checkText(text);
    if (text.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      final escaped = StringBuffer();
      for (final rune in text.runes) {
        if (rune == 39 || rune == 92) {
          escaped.write('\\${String.fromCharCode(rune)}');
        } else if (rune < 32 || rune == 127) {
          escaped.write('\\x${rune.toRadixString(16).padLeft(2, '0')}');
        } else {
          escaped.writeCharCode(rune);
        }
      }
      // 显式编码控制字符，避免 shell 将命令文本中的 CRLF 归一化为 LF。
      return "\$'$escaped'";
    }
    return "'${text.replaceAll("'", "'\"'\"'")}'";
  }

  /// 使用 PowerShell 单引号字符串，保留美元符号与换行，不展开表达式。
  static String _powerShellQuote(String text) {
    _checkText(text);
    return "'${text.replaceAll("'", "''")}'";
  }

  /// 命令行参数无法表示 NUL，拒绝生成会截断内容的命令。
  static void _checkText(String text) {
    if (text.contains('\x00')) {
      throw const CurlFormatException('命令行无法表示 NUL 字符，请移除后重试。');
    }
  }

  /// 进行有限的 shell 分词，保留引号中的内容，拒绝命令拼接、重定向和变量求值。
  static List<String> _words(String source, CurlShell shell) {
    _checkText(source);
    final result = <String>[];
    var word = StringBuffer(), active = false;
    String? quote;
    final powerShell = shell == CurlShell.powerShell;
    for (var i = 0; i < source.length; i++) {
      final ch = source[i];
      if (quote == "'") {
        if (ch == "'") {
          if (powerShell && i + 1 < source.length && source[i + 1] == "'") {
            word.write("'");
            i++;
          } else {
            quote = null;
          }
        } else {
          word.write(ch);
        }
        continue;
      }
      if (ch == (powerShell ? '`' : r'\')) {
        if (i + 1 >= source.length) {
          throw const CurlFormatException('命令末尾的转义符缺少后续字符。');
        }
        var next = source[++i];
        if (next == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
          next = source[++i];
        }
        if (next == '\n') continue;
        if (!powerShell &&
            quote == '"' &&
            !['"', r'\', r'$', '`'].contains(next)) {
          word.write(r'\');
        }
        word.write(
          powerShell && quote == '"'
              ? const {'n': '\n', 'r': '\r', 't': '\t'}[next] ?? next
              : next,
        );
        active = true;
        continue;
      }
      if (!powerShell &&
          ch == r'$' &&
          quote == null &&
          i + 1 < source.length &&
          source[i + 1] == "'") {
        final ansi = _ansi(source, i + 2);
        word.write(ansi.$1);
        i = ansi.$2;
        active = true;
        continue;
      }
      if (ch == r'$' || !powerShell && ch == '`') {
        throw const CurlFormatException('暂不支持变量、命令替换或脚本表达式，请粘贴已展开的实际值。');
      }
      if (quote == '"') {
        if (ch == '"') {
          if (powerShell && i + 1 < source.length && source[i + 1] == '"') {
            word.write('"');
            i++;
          } else {
            quote = null;
          }
        } else {
          word.write(ch);
        }
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        active = true;
      } else if (RegExp(r'\s').hasMatch(ch)) {
        if (active) {
          result.add(word.toString());
          word = StringBuffer();
          active = false;
        }
      } else if (';&|<>()'.contains(ch) || powerShell && '{}'.contains(ch)) {
        throw const CurlFormatException('只支持单条 cURL 命令，不支持管道、重定向或其他脚本。');
      } else if (ch == '^' &&
          i + 1 < source.length &&
          ['"', '\r', '\n'].contains(source[i + 1])) {
        throw const CurlFormatException(
          '这是 Windows CMD 格式，请在浏览器选择“复制为 cURL（bash）”，或改用 PowerShell 7 格式。',
        );
      } else {
        word.write(ch);
        active = true;
      }
    }
    if (quote != null) throw const CurlFormatException('引号未闭合，请粘贴完整命令。');
    if (active) result.add(word.toString());
    return result;
  }

  /// 解码 Bash 的 ANSI-C 引号；字节转义须组成合法 UTF-8，二进制正文不做替换。
  static (String, int) _ansi(String source, int offset) {
    final bytes = <int>[];
    var raw = StringBuffer();
    for (var i = offset; i < source.length; i++) {
      final ch = source[i];
      if (ch != "'" && ch != r'\') {
        raw.write(ch);
        continue;
      }
      bytes.addAll(utf8.encode(raw.toString()));
      raw = StringBuffer();
      if (ch == "'") {
        try {
          final text = utf8.decode(bytes);
          _checkText(text);
          return (text, i);
        } on FormatException {
          throw const CurlFormatException('ANSI-C 引号包含非 UTF-8 二进制数据，暂不支持导入。');
        }
      }
      if (++i >= source.length) break;
      final escape = source[i];
      if (escape == 'c') {
        throw const CurlFormatException('暂不支持 ANSI-C 引号中的 \\c 控制字符转义。');
      }
      const simple = {
        'a': 7,
        'b': 8,
        'e': 27,
        'E': 27,
        'f': 12,
        'n': 10,
        'r': 13,
        't': 9,
        'v': 11,
        r'\': 92,
        "'": 39,
        '"': 34,
        '?': 63,
      };
      if (simple.containsKey(escape)) {
        bytes.add(simple[escape]!);
      } else if (['x', 'u', 'U'].contains(escape) ||
          RegExp(r'[0-7]').hasMatch(escape)) {
        final octal = RegExp(r'[0-7]').hasMatch(escape);
        final limit = octal
            ? 3
            : escape == 'x'
            ? 2
            : escape == 'u'
            ? 4
            : 8;
        var digits = octal ? escape : '';
        final pattern = octal ? RegExp(r'[0-7]') : RegExp(r'[0-9a-fA-F]');
        while (digits.length < limit &&
            i + 1 < source.length &&
            pattern.hasMatch(source[i + 1])) {
          digits += source[++i];
        }
        if (digits.isEmpty) {
          throw const CurlFormatException('ANSI-C 引号中的字符转义无效。');
        }
        final code = int.parse(digits, radix: octal ? 8 : 16);
        if (octal || escape == 'x') {
          bytes.add(code & 255);
        } else {
          if (code > 0x10ffff || code >= 0xd800 && code <= 0xdfff) {
            throw const CurlFormatException('Unicode 转义无效。');
          }
          bytes.addAll(utf8.encode(String.fromCharCode(code)));
        }
      } else {
        bytes.addAll(utf8.encode('\\$escape'));
      }
    }
    throw const CurlFormatException('ANSI-C 引号未闭合。');
  }
}
