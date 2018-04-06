import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:lua/src/5_2/context.dart';
import 'package:lua/src/5_2/lualib/base.dart';
import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/vm.dart';
import 'package:lua/src/decode.dart';
import 'package:lua/src/func.dart';

Map<String, CodeDump> cache = {};

// Returns microseconds elapsed
Future<int> test(String path, int count) async {
  CodeDump code;
  
  if (cache.containsKey(path)) {
    code = cache[path];
  } else {
    var res = await Process.run("luac", [path]);
  
    if (res.stderr != "") throw res.stderr;
  
    var f = new File("luac.out");
  
    if (!await f.exists()) throw "luac.out not found";
    var fh = await f.open(mode: FileMode.READ);
    var buffer = new Uint8List(await f.length());
    await fh.readInto(buffer);
  
    await f.delete();
  
    var decoder = new Decoder(buffer.buffer);
    code = decoder.readCodeDump(path);
  }

  var env = new Table();
  env["test"] = true;
  var context = new Context(env: env);
  
  loadBase(context);
  loadMath(context);
  loadString(context);
  loadBit(context);
  loadTable(context);

  var cl = new Closure(
    code.main,
    context: context,
    upvalues: [new Upval.store(context.env)],
  );

  var res = new Thread(closure: cl).resume();
  if (!res.success) throw res.values[0];
  
  var step = env["step"] as Closure;
  if (step == null) throw "Benchmark diddn't create step function";

  for (int i = 0; i < count; i++) { // Warm up
    new Thread(closure: step).resume();
  }
  
  int dt;
  
  runZoned(() {
    var t0 = new DateTime.now().microsecondsSinceEpoch;
    
    for (int i = 0; i < count; i++) {
      new Thread(closure: step).resume();
    }
    
    dt = new DateTime.now().microsecondsSinceEpoch - t0;
  }, zoneSpecification: new ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {},
  ));
  
  if (env["finish"] as Closure != null) {
    new Thread(closure: env["finish"]).resume();
  }
  
  return dt;
}

Future<double> testAll(String file, int count) async {
  var lua51 = Process.run("lua5.1", ["benchmark/$file.lua"]);
  var lua52 = Process.run("lua5.2", ["benchmark/$file.lua"]);
  var luajit = Process.run("luajit", ["benchmark/$file.lua"]);
  
  var base = 1 / ((await test("benchmark/$file.lua", count)) / (count * 1000000));
  
  print("LuaDart:   ${base.toStringAsFixed(2)} H/s");
  
  diff(String name, ProcessResult res) {
    if (res.stderr != "") throw res.stderr;
    var o = 1 / (int.parse(res.stdout.split("\n").first) / (count * 1000000));
    print("${"$name:".padRight(10)} ${o.toStringAsFixed(0)} H/s (${(o / base).toStringAsFixed(2)}x)");
  }
  
  diff("Lua 5.1", await lua51);
  diff("Lua 5.2", await lua52);
  diff("LuaJIT", await luajit);
  
  return base;
}