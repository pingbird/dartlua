import 'dart:io';
import 'dart:typed_data';
import 'package:args/args.dart';
import 'package:lua/lua5.2.dart';
import 'package:lua/src/decode.dart';
import 'package:lua/src/disassemble.dart';

const help =
  "Usage: dartlua [options] [command] [script [args]]";

const commandHelp =
  "Available commands:\n"
  "  run           Runs the Lua script\n"
  "  disassemble   Disassembles the Lua script";

main(List<String> rawArgs) async {
  var argParser = new ArgParser();
  var args = argParser.parse(rawArgs);
  
  if (args.rest.length == 0) {
    stderr.writeln(help);
    stderr.writeln(commandHelp);
    exit(1);
  }
  
  var command = args.rest[0];

  if (command == "run") {
    if (args.rest.length < 2) {
      stderr.writeln("Error: no file provided.");
      stderr.writeln(help);
      exit(1);
    }
  
    var state = new LuaState();
    state.doFile(args.rest[1], args: args.rest.skip(2).toList());
  } else if (command == "disassemble") {
    if (args.rest.length < 2) {
      stderr.writeln("Error: no file provided.");
      stderr.writeln(help);
      exit(1);
    }

    var path = args.rest[1];
    var res = await Process.run("luac", [path]);

    if (res.stderr != "") throw res.stderr;

    var f = new File("luac.out");

    if (!await f.exists()) throw "luac.out not found";
    var fh = await f.open(mode: FileMode.READ);
    var buffer = new Uint8List(await f.length());
    await fh.readInto(buffer);
    
    await f.delete();
    
    var decoder = new Decoder(buffer.buffer);
    print(disassemble(decoder.readCodeDump(path)));
  } else {
    stderr.writeln("Error: no such command '$command'");
    stderr.writeln(commandHelp);
  }
}