import 'core.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:io';

var count = 8192;

Future main() async {
  var base = await testAll("sha256", 8192);
  
  var shabench = await Process.run("/home/pixel/CLionProjects/shabenchmark/shabenchmark", []);
  var o = 1 / (int.parse(shabench.stdout.split("\n").first) / (count * 1000000));
  print("C:         ${o.toStringAsFixed(0)} H/s (${(o / base).toStringAsFixed(2)}x)");
  
  print("(paused for debugging)");
  debugger();
}