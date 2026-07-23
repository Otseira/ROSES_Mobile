import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siro_mobile/features/auth/models/user_model.dart';
import 'package:siro_mobile/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('LoginScreen menampilkan form login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Selamat Datang'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  test('UserModel.fromJson memetakan field dengan benar', () {
    final user = UserModel.fromJson({
      'id': 1,
      'nik': '12345',
      'username': 'ahmad',
      'nama': 'dr. Ahmad',
      'role': 'staf',
      'unit_kerja': 'IGD',
    });

    expect(user.id, 1);
    expect(user.nik, '12345');
    expect(user.nama, 'dr. Ahmad');
    expect(user.canAbsen, isTrue);
    expect(user.isSuperadmin, isFalse);
  });
}
