import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watcher/main.dart';

// Load the real fonts so text widths match the app (the default test font is wider).
Future<void> _loadFonts() async {
  for (final (family, files) in [
    ('Geist', ['Geist-Regular', 'Geist-Medium', 'Geist-SemiBold', 'Geist-Bold']),
    ('GeistMono', ['GeistMono-Regular', 'GeistMono-Medium']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('phone layout shows Overview with tab bar', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WatcherApp());
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('6/7'), findsOneWidget);
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();
    expect(find.text('IMG_2041.jpg'), findsOneWidget);
  });

  testWidgets('desktop layout shows sidebar and Files details', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WatcherApp());
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Photos 2026'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });
}
