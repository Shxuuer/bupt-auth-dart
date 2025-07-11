import 'dart:io';
import 'package:bupt_auth_dart/bupt_auth_dart.dart' as bupt_auth;

void main() async {
  stdout.write('学号: ');
  String buptId = stdin.readLineSync()!.trim();
  stdout.write('密码: ');
  String buptPass = stdin.readLineSync()!.trim();

  try {
    // 尝试登录
    bupt_auth.UserInfo user = await bupt_auth.login(buptId, buptPass);
    print('登录成功: $user');
  } catch (e) {
    if (e is bupt_auth.CaptchaError) {
      print('需要验证码');
      print('\tCaptcha URL: ${e.captchaUrl}');
      print('\tCookie: ${e.cookie}');
      stdout.write('Captcha: ');
      String captcha = stdin.readLineSync()!.trim();
      bupt_auth.UserInfo user = await e.resolve(captcha);
      print('登录成功: $user');
    } else {
      rethrow;
    }
  }
}
