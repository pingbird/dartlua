import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/context.dart';
import 'package:lua/src/5_2/state.dart';
import 'package:lua/src/util.dart';

export 'bit.dart';
export 'coroutine.dart';
export 'math.dart';
export 'string.dart';
export 'table.dart';

loadBase(Context ctx) {
  ctx.env["assert"] = (List<dynamic> args) {
    if (args.length < 1 || args[0] == null || args[0] == false) {
      throw args.length < 2 ? "assertion failed!" : args[1];
    }
    
    return [args[0]];
  };

  ctx.env["collectgarbage"] = (List<dynamic> args) {
    throw "NYI"; // TODO
  };

  ctx.env["dofile"] = (List<dynamic> args) {
    throw "NYI"; // TODO
  };

  ctx.env["error"] = (List<dynamic> args) {
    throw (args.length < 1 ? null : args[0]) ?? "";
  };

  ctx.env["_G"] = ctx.env;

  ctx.env["getmetatable"] = (List<dynamic> args) {
    return [Context.getMetatable(args.length < 1 ? null : args[0])];
  };

  ctx.env["ipairs"] = (List<dynamic> args) {
    var t = args[0];
    
    if (Context.hasMetamethod(t, "__ipairs")) {
      return Context.invokeMetamethod(t, "__ipairs", [t]).take(3).toList(growable: false);
    }
    
    return [
      (List<dynamic> args) {
        var i = args[1] + 1;
        var v = ctx.tableIndex(args[0], i);
        return v != null ? [i, v] : [];
      }, t, 0,
    ];
  };

  ctx.env["load"] = (List<dynamic> args) {
    var ld = Context.getArg(args, 0, "load", [
      const TypeMatcher<LuaDartFunc>(), // 🧐
      const TypeMatcher<dynamic>(),
    ]);
    
    if (ld is! LuaDartFunc) ld = Context.luaToString(ld);
    
    var source = maybeAt(args, 1) ?? ld;
    var mode = maybeAt(args, 2) ?? "bt";
    var env = maybeAt(args, 3) ?? ctx.env;
    
    throw "NYI"; // TODO
  };

  ctx.env["loadfile"] = (List<dynamic> args) {
    throw "NYI"; // TODO
  };

  ctx.env["next"] = (List<dynamic> args) {
    Table table = Context.getArg(args, 0, "next", [const TypeMatcher<Table>()]);
    var k = table.next(maybeAt(args, 1));
    return [k, table.rawget(k)];
  };

  ctx.env["pairs"] = (List<dynamic> args) {
    return [ctx.env["next"], Context.getArg(args, 0, "pairs", [const TypeMatcher<Table>()]), null];
  };

  ctx.env["pcall"] = (List<dynamic> args) {
    var f = Context.getArg(args, 0, "pcall", [const TypeMatcher<dynamic>()]);
    try {
      return <dynamic>[true]..addAll(Context.attemptCall(f, args.skip(1).toList(growable: false)));
    } on LuaError catch(e) {
      if (e.value is String) {
        return [false, e.toStringShort()];
      } else {
        return [false, e.value];
      }
    } catch(e) {
      return [
        false,
        e,
      ];
    }
  };
  
  ctx.env["print"] = (List<dynamic> args) {
    print(args.map((a) => Context.luaToString(a).toString()).join("\t"));
    return [];
  };

  ctx.env["rawequal"] = (List<dynamic> args) {
    return [maybeAt(args, 0) == maybeAt(args, 1)];
  };

  ctx.env["rawget"] = (List<dynamic> args) {
    Table t = Context.getArg(args, 0, "rawget", [const TypeMatcher<Table>()]);
    var k = Context.getArg(args, 1, "rawget", [const TypeMatcher<dynamic>()]);
    return [
      t.rawget(k),
    ];
  };

  ctx.env["rawlen"] = (List<dynamic> args) {
    Table t = Context.getArg(args, 0, "rawlen", [const TypeMatcher<Table>()]);
    return [
      t.length,
    ];
  };

  ctx.env["rawset"] = (List<dynamic> args) {
    Table t = Context.getArg(args, 0, "rawset", [const TypeMatcher<Table>()]);
    var k = Context.getArg(args, 1, "rawset", [const TypeMatcher<dynamic>()]);
    var v = Context.getArg(args, 2, "rawset", [const TypeMatcher<dynamic>()]);
    t.rawset(k, v);
    return [];
  };

  ctx.env["select"] = (List<dynamic> args) {
    var a = Context.getArg(args, 0, "select", [
      const TypeMatcher<num>(),
      const TypeMatcher<String>(),
    ]);
    
    if (a is String) {
      if (a == "#") {
        return [args.length - 1];
      } else {
        throw "bad argument #1 to 'select' (number expected, got string)";
      }
    }
    
    var n = (a as num).floor();
    if (n < 1) throw "bad argument #1 to 'select' (index out of range)";
    return args.skip(n).toList(growable: false);
  };

  ctx.env["setmetatable"] = (List<dynamic> args) {
    Table t = Context.getArg(args, 0, "setmetatable", [const TypeMatcher<Table>()]);
    
    if (args.length < 2) throw "bad argument #2 to 'setmetatable' (nil or table expected)";
    
    Table v = Context.getArg(args, 1, "setmetatable", [
      const TypeMatcher<Table>(),
      const TypeMatcher<Null>(),
    ]);
    
    t.metatable = v;
    
    return [t];
  };

  ctx.env["tonumber"] = (List<dynamic> args) {
    if (args.length == 0) throw "bad argument #1 to 'tonumber' (value expected)";
    var x = args[0];
    
    if (x is num) return [x];
    
    if (x is String) return [
      int.parse(x, onError: (_) => null) ?? double.parse(x, (_) => null),
    ];
    
    return [null];
  };

  ctx.env["tostring"] = (List<dynamic> args) {
    if (args.length == 0) throw "bad argument #1 to 'tostring' (value expected)";
    return [Context.luaToString(args[0])];
  };

  ctx.env["type"] = (List<dynamic> args) {
    if (args.length == 0) throw "bad argument #1 to 'type' (value expected)";
    return [Context.getTypename(args[0])];
  };

  ctx.env["_VERSION"] = "Lua 5.2";
}

