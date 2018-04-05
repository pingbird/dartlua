import 'core.dart';
import 'dart:async';
import 'dart:io';

const count = 16384;

Future main() async {
  var lua51 = Process.run("lua5.1", ["benchmark/sha256.lua"]);
  var lua52 = Process.run("lua5.2", ["benchmark/sha256.lua"]);
  var luajit = Process.run("luajit", ["benchmark/sha256.lua"]);

  var base = 1 / ((await test("benchmark/sha256.lua", count)) / (count * 1000000));
  
  print("LuaDart: ${base.toStringAsFixed(2)} H/s");
  
  diff(String name, ProcessResult res) {
    if (res.stderr != "") throw res.stderr;
    var o = 1 / (int.parse(res.stdout.split("\n").first) / (count * 1000000));
    print("$name: ${o.toStringAsFixed(0)} H/s (${(o / base).toStringAsFixed(2)}x)");
  }
  
  diff("Lua 5.1", await lua51);
  diff("Lua 5.2", await lua52);
  diff("LuaJIT", await luajit);
}