import 'core.dart';
import 'dart:async';

const count = 16384;

Future main() async {
  print("${(1 / ((await test("benchmark/sha256.lua", count)) / (count * 1000000))).toStringAsFixed(2)} H/s");
}