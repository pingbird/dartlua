import 'dart:math';

import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/context.dart';

int _tobit(num x) {
  if (x is int) return x % 0x100000000;
  return (x + 0.5).floor() % 0x100000000;
}

loadBit(Context ctx) {
  var bit = new Table();
  ctx.env["bit"] = bit;
  
  bit["tobit"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "tobit", [const TypeMatcher<num>()]);
    return [_tobit(x)];
  };
  
  bit["tohex"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "tohex", [const TypeMatcher<num>()]);
    num n = args.length < 2 ? 8 : (Context.getArg(args, 1, "tohex", [const TypeMatcher<num>()]) as num).abs().floor();
    var o = _tobit(x).toRadixString(16).padLeft(n, "0");
    return [o.substring(o.length - n)];
  };
  
  bit["bnot"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "bnot", [const TypeMatcher<num>()]);
    return [~_tobit(x)];
  };
  
  bit["band"] = (List<dynamic> args) {
    var o = 0xFFFFFFFF;
    for (int i = 0; i < max(1, args.length); i++) {
      if (args.length <= i) throw "bad argument #${i + 1} to 'band' (number expected, got no value)";
      if (args[i] is! num) throw "bad argument #${i + 1} to 'band' (number expected, got ${Context.getTypename(args[i])})";
      o = o & _tobit(args[i]);
    }
    return [o];
  };
  
  bit["bor"] = (List<dynamic> args) {
    var o = 0;
    for (int i = 0; i < max(1, args.length); i++) {
      o = o | _tobit(Context.getArg(args, i, "bor", [const TypeMatcher<num>()]));
    }
    return [o];
  };
  
  bit["bxor"] = (List<dynamic> args) {
    var o = 0;
    for (int i = 0; i < max(1, args.length); i++) {
      if (args.length <= i) throw "bad argument #${i + 1} to 'bxor' (number expected, got no value)";
      if (args[i] is! num) throw "bad argument #${i + 1} to 'bxor' (number expected, got ${Context.getTypename(args[i])})";
      o = o ^ _tobit(args[i]);
    }
    return [o];
  };
  
  bit["lshift"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "lshift", [const TypeMatcher<num>()]);
    num y = Context.getArg(args, 1, "lshift", [const TypeMatcher<num>()]);
    return [_tobit(x) << _tobit(y)];
  };
  
  bit["rshift"] = (List<dynamic> args) {
    if (args.length < 1) throw "bad argument #1 to 'rshift' (number expected, got no value)";
    if (args[0] is! num) throw "bad argument #1 to 'rshift' (number expected, got ${Context.getTypename(args[0])})";
    int x = _tobit(args[0]);
    if (args.length < 2) throw "bad argument #2 to 'rshift' (number expected, got no value)";
    if (args[0] is! num) throw "bad argument #2 to 'rshift' (number expected, got ${Context.getTypename(args[1])})";
    int y = _tobit(args[1]);
    
    return [_tobit(x) >> _tobit(y)];
  };
  
  bit["arshift"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "arshift", [const TypeMatcher<num>()]);
    num y = _tobit(Context.getArg(args, 1, "arshift", [const TypeMatcher<num>()]));
    var o = _tobit(x);
    return [(o >> y) | ((o & 0x80000000 == 0 ? 0 : (0xFFFFFFFF << (32 - y)) & 0xFFFFFFFF))];
  };
  
  bit["rol"] = (List<dynamic> args) {
    int x = _tobit(Context.getArg(args, 0, "rol", [const TypeMatcher<num>()]));
    int y = _tobit(Context.getArg(args, 1, "rol", [const TypeMatcher<num>()])) % 32;
    return [(x << y) | (x >> (32 - y))];
  };
  
  bit["ror"] = (List<dynamic> args) {
    if (args.length < 1) throw "bad argument #1 to 'ror' (number expected, got no value)";
    if (args[0] is! num) throw "bad argument #1 to 'ror' (number expected, got ${Context.getTypename(args[0])})";
    int x = _tobit(args[0]);
    if (args.length < 2) throw "bad argument #2 to 'ror' (number expected, got no value)";
    if (args[0] is! num) throw "bad argument #2 to 'ror' (number expected, got ${Context.getTypename(args[1])})";
    int y = _tobit(args[1]);
    
    return [_tobit((x >> y) | (x << (32 - y)))];
  };
  
  bit["bswap"] = (List<dynamic> args) {
    int x = _tobit(Context.getArg(args, 0, "bswap", [const TypeMatcher<num>()]));
    return [
      ((x & 0xFF) << 24) |
      ((x & 0xFF00) << 8) |
      ((x & 0xFF0000) >> 8) |
      ((x & 0xFF000000) >> 24)
    ];
  };
}