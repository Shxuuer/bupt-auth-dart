import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 用户信息，包含登录及刷新 token 后返回的基本信息
class UserInfo {
  final String? accessToken;
  final String? tokenType;
  final String? refreshToken;
  final int? expiresIn;
  final String? scope;
  final String? tenantId;
  final String? roleName;
  final String? license;
  final String? loginId;
  final String? userId; // 用户 ID
  final String? userName; // 学号
  final String? realName;
  final String? avatar;
  final String? deptId;
  final String? clientId;
  final String? account; // 学号
  final String? jti;

  const UserInfo({
    required this.accessToken,
    required this.tokenType,
    required this.refreshToken,
    required this.expiresIn,
    required this.scope,
    required this.tenantId,
    required this.roleName,
    required this.license,
    required this.loginId,
    required this.userId,
    required this.userName,
    required this.realName,
    required this.avatar,
    required this.deptId,
    required this.clientId,
    required this.account,
    required this.jti,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      refreshToken: json['refresh_token'],
      expiresIn: json['expires_in'],
      scope: json['scope'],
      tenantId: json['tenant_id'],
      roleName: json['role_name'],
      license: json['license'],
      loginId: json['loginId'],
      userId: json['user_id'],
      userName: json['user_name'],
      realName: json['real_name'],
      avatar: json['avatar'],
      deptId: json['dept_id'],
      clientId: json['client_id'],
      account: json['account'],
      jti: json['jti'],
    );
  }

  @override
  String toString() {
    // 拼接所有的字符串
    return 'UserInfo(accessToken: $accessToken, tokenType: $tokenType, refreshToken: $refreshToken, expiresIn: $expiresIn, scope: $scope, tenantId: $tenantId, roleName: $roleName, license: $license, loginId: $loginId, userId: $userId, userName: $userName, realName: $realName, avatar: $avatar, deptId: $deptId, clientId: $clientId, account: $account, jti: $jti)';
  }
}

/// 登录错误
class LoginError implements Exception {
  final String message;
  LoginError(this.message);
  @override
  String toString() => 'LoginError: $message';
}

/// OCR 识别失败错误
class OCRError implements Exception {
  final String message;
  OCRError(this.message);
  @override
  String toString() => 'OCRError: $message';
}

/// 会话信息
class Session {
  final String id;
  final String cookie;
  final String execution;
  Session({required this.id, required this.cookie, required this.execution});
}

/// 验证码错误，需要处理验证码流程
class CaptchaError implements Exception {
  final Session session;
  final String username;
  final String password;

  CaptchaError(
    String message, {
    required this.session,
    required this.username,
    required this.password,
  });

  /// 获取验证码 URL
  String get captchaUrl =>
      'https://auth.bupt.edu.cn/authserver/captcha?captchaId=${session.id}&r=${DateTime.now().microsecondsSinceEpoch.toString().substring(0, 5)}';

  /// 获取 cookie
  String get cookie => session.cookie;

  /// 解析并提交验证码
  Future<UserInfo> resolve(String captcha) async {
    return await login(
      username,
      password,
      session: Session(
        id: session.id,
        cookie: session.cookie,
        execution: session.execution,
      ),
      captcha: captcha,
    );
  }
}

/// 刷新 token
Future<UserInfo> refreshToken(String refreshToken) async {
  var uri = Uri.parse('https://apiucloud.bupt.edu.cn/ykt-basics/oauth/token');
  var request = http.MultipartRequest('POST', uri)
    ..fields['grant_type'] = 'refresh_token'
    ..fields['refresh_token'] = refreshToken
    ..headers['authorization'] = 'Basic cG9ydGFsOnBvcnRhbF9zZWNyZXQ=';

  var response = await request.send();
  var body = await response.stream.bytesToString();
  if (response.statusCode != 200) {
    throw LoginError('刷新 token 失败: ${response.statusCode}');
  }
  return UserInfo.fromJson(json.decode(body));
}

/// 获取初始 cookie 和 execution，并检查是否需要验证码
Future<Session> _getCookieAndExecution(String username, String password) async {
  var uri = Uri.parse(
    'https://auth.bupt.edu.cn/authserver/login?service=https://ucloud.bupt.edu.cn',
  );
  var res = await http.get(uri);
  var setCookie = res.headers['set-cookie'];
  if (setCookie == null) {
    throw LoginError('登录失败(-1): 无法获取到 cookie');
  }
  var cookie = setCookie.split(';').first;
  var html = res.body;
  var execReg = RegExp(r'<input name="execution" value="(.*?)"');
  var execMatch = execReg.firstMatch(html);
  if (execMatch == null) {
    throw LoginError('登录失败(-2): 无法获取到 execution');
  }
  var execution = execMatch.group(1)!;
  var capReg = RegExp(r"config.captcha[^{]*{[^}]*id: '(.*?)'");
  var capMatch = capReg.firstMatch(html);
  if (capMatch != null) {
    throw CaptchaError(
      '登录失败(-3): 需要验证码',
      session: Session(
        id: capMatch.group(1)!,
        cookie: cookie,
        execution: execution,
      ),
      username: username,
      password: password,
    );
  }
  return Session(id: '', cookie: cookie, execution: execution);
}

/// 登录函数
Future<UserInfo> login(
  String username,
  String password, {
  Session? session,
  String? captcha,
}) async {
  // 获取或使用已有 session
  var sess = session ?? await _getCookieAndExecution(username, password);
  var uri = Uri.parse(
    'https://auth.bupt.edu.cn/authserver/login?service=https://ucloud.bupt.edu.cn',
  );
  var body = {
    'username': username,
    'password': password,
    'submit': '登录',
    'type': 'username_password',
    'execution': sess.execution,
    '_eventId': 'submit',
  };
  if (captcha != null) body['captcha'] = captcha;

  var response = await http.post(
    uri,
    headers: {
      'cookie': sess.cookie,
      'content-type': 'application/x-www-form-urlencoded',
      'referer':
          'https://auth.bupt.edu.cn/authserver/login?service=https://ucloud.bupt.edu.cn',
    },
    body: body,
  );

  if (response.statusCode != 302) {
    var html = response.body;
    var errReg = RegExp(
      r'<div class="alert alert-danger" id="errorDiv">.*?<p>(.*?)<\/p>',
    );
    var errMatch = errReg.firstMatch(html);
    if (response.statusCode == 401 && errMatch != null) {
      var msg = errMatch.group(1) == 'Invalid credentials.'
          ? '登录失败(3): 用户名或者密码错误'
          : '登录失败(4): ${errMatch.group(1)}';
      throw LoginError(msg);
    }
    throw LoginError('登录失败(${response.statusCode}): ${response.reasonPhrase}');
  }

  var location = response.headers['location'];
  if (location == null) {
    throw LoginError('登录失败(5): 无法获取到重定向目标');
  }
  var ticket = Uri.parse(location).queryParameters['ticket'];
  if (ticket == null) {
    throw LoginError('登录失败(6): 无法获取到 ticket');
  }

  // 获取 token
  var tokenUri = Uri.parse(
    'https://apiucloud.bupt.edu.cn/ykt-basics/oauth/token',
  );
  var tokenRes = await http.post(
    tokenUri,
    headers: {
      'accept': 'application/json, text/plain, */*',
      'authorization': 'Basic cG9ydGFsOnBvcnRhbF9zZWNyZXQ=',
      'content-type': 'application/x-www-form-urlencoded',
      'tenant-id': '000000',
      'referer': 'https://ucloud.bupt.edu.cn/',
    },
    body: 'ticket=$ticket&grant_type=third',
  );

  if (tokenRes.statusCode != 200) {
    throw LoginError(
      '登录失败(7): ${tokenRes.statusCode} ${tokenRes.reasonPhrase}',
    );
  }

  return UserInfo.fromJson(json.decode(tokenRes.body));
}

/// 使用外部 OCR 服务进行登录（自动处理验证码）
Future<UserInfo> byrdocsLogin(
  String username,
  String password,
  String token, {
  int retry = 1,
}) async {
  try {
    return await login(username, password);
  } catch (e) {
    if (e is CaptchaError) {
      // 调用第三方 OCR 获取验证码
      var captchaResp = await http.get(
        Uri.parse(
          'https://ocr.byrdocs.org/ocr?url=${Uri.encodeComponent(e.captchaUrl)}&token=$token&cookie=${e.cookie}',
        ),
      );
      var data = json.decode(captchaResp.body);
      var ocrText = data['text'];
      if (ocrText == null) throw OCRError(data['detail'] ?? '未知错误');

      if (retry > 0) {
        return byrdocsLogin(username, password, token, retry: retry - 1);
      } else {
        return await e.resolve(ocrText);
      }
    } else {
      rethrow;
    }
  }
}
