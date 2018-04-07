import 'core.dart';
import 'dart:async';
import 'dart:developer';

Future main() async {
  await testAll("arithmetic", 16384);

  print("(paused for debugging)");
  debugger();
}