import 'core.dart';
import 'dart:async';

const count = 8192;

Future main() async {
  print("${1 / ((await test("benchmark/sha256.lua", count)) / (count * 1000000))} H/s");
}