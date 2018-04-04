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
  var context = new Context(env: env);
  
  loadBase(context);
  loadMath(context);
  loadString(context);
  loadBit(context);
  loadTable(context);

  var cl = new Closure(
    code.main,
    context: context,
    upvalues: [new UStorage()..open = false..storage = context.env],
  );

  var res = new Thread(closure: cl).resume();
  if (!res.success) throw res.values[0];

  return runZoned(() {
    var t0 = new DateTime.now().microsecondsSinceEpoch;
    
    for (int i = 0; i < count; i++) {
      new Thread(closure: env["step"]).resume();
    }
    
    return new DateTime.now().microsecondsSinceEpoch - t0;
  }, zoneSpecification: new ZoneSpecification(
    print: (Zone self, ZoneDelegate parent, Zone zone, String line) {},
  ));
}