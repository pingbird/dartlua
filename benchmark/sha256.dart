import 'core.dart';
import 'dart:async';
import 'dart:io';

Future main() async {
  await testAll("sha256", 8192);
}