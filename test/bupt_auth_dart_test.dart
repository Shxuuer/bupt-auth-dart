import 'dart:math';
import 'dart:io';

import 'package:test/test.dart';
import 'package:bupt_auth_dart/bupt_auth_dart.dart' as bupt_auth;

void main() {
  group('login', () {
    test('should login successfully', () async {
      final creds = await getTestAccount();
      final buptId = creds['bupt_id'] as String;
      final buptPass = creds['bupt_pass'] as String;

      final res = await bupt_auth.login(buptId, buptPass);
      expect(res.account, equals(buptId));
      expect(res.userName, isNotNull);
      expect(res.realName, isNotNull);
    });

    test('should throw error when login failed', () async {
      final year = DateTime.now().year - 1;
      final serial = Random().nextInt(1000).toString().padLeft(4, '0');
      final account = '${year}21$serial';
      expect(
        () async => await bupt_auth.login(account, 'wrongpassword'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('refresh', () {
    test('should refresh successfully', () async {
      final creds = await getTestAccount();
      final buptId = creds['bupt_id'] as String;
      final buptPass = creds['bupt_pass'] as String;

      final res = await bupt_auth.login(buptId, buptPass);
      final refreshed = await bupt_auth.refreshToken(res.refreshToken!);

      expect(refreshed.account, equals(buptId));
      expect(refreshed.account, equals(res.account));
      expect(refreshed.realName, equals(res.realName));
      expect(refreshed.accessToken, isNotNull);
    });

    test('should throw error when refresh failed', () async {
      expect(
        () async => await bupt_auth.refreshToken('wrongtoken'),
        throwsA(isA<Exception>()),
      );
    });
  });
}

/// Mock or utility to get test credentials
Future<Map<String, String>> getTestAccount() async {
  stdout.write('学号: ');
  String buptId = stdin.readLineSync()!.trim();
  stdout.write('密码: ');
  String buptPass = stdin.readLineSync()!.trim();
  return {'bupt_id': buptId, 'bupt_pass': buptPass};
}
