import 'core.dart';
import 'dart:async';
import 'dart:developer';

Future main() async {
  await testAll("variables", 4096);
  
  print("(paused for debugging)");
  debugger();
}