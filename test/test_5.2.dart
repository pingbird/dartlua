import 'dart:async';
import 'dart:io';
import 'package:lua/lua5.2.dart';
import 'package:lua/src/util.dart';
import 'package:test/test.dart';

import 'generate_expect.dart' as foo;

main() async {
  await foo.main();
  
  Map<FileSystemEntity, String> tests = {};
  
  await for (var f in new Directory("testcase").list().where((e) => e.path.endsWith(".lua"))) {
    tests[f] = await new File(f.path.replaceAll(".lua", ".txt")).readAsString();
  }
  
  group("Lua 5.2", () {
    for (var f in tests.keys) {
      test(f.uri.pathSegments.last, () async {
        var out = new StringBuffer();

        CoroutineResult res = await runZoned(() async {
          var state = new LuaState();
          return await state.doFile(f.path);
        }, zoneSpecification: new ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            out.writeln(line);
          },
        ));
        
        expect(res.success, true, reason: maybeAt(res.values, 0));
  
        expect(out.toString(), tests[f]);
      });
    }
  });
}