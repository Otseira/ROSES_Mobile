import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ untuk initializeDateFormatting
import 'package:intl/intl.dart';                   // ✅ untuk Intl.defaultLocale
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ WAJIB: muat data locale Indonesia SEBELUM DateFormat('...', 'id_ID') dipakai.
  //    Tanpa ini → LocaleDataException (layar merah).
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Kunci orientasi portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Gaya status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: SiroApp(),
    ),
  );
}
