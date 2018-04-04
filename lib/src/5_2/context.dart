import 'package:lua/src/5_2/state.dart';
import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/vm.dart';
import 'package:lua/src/func.dart';
import 'package:lua/src/util.dart';
import 'package:meta/meta.dart';

class LuaErrorImpl extends LuaError {
  LuaErrorImpl(this.value, this.proto, this.inst, {this.dartStackTrace});
  final dynamic value;
  final Prototype proto;
  final int inst;
  String get source => proto.root.name;
  StackTrace dartStackTrace;
  
  toStringShort() => "${proto.root.name}:${proto.lines[inst]}: $value";
  toString() => "${toStringShort()}${dartStackTrace == null ? "" : "\n$dartStackTrace"}";
}

typedef List<dynamic> LuaDartFunc(List<dynamic> params);
typedef num ArithCB(num x, num y);
typedef num UArithCB(num x);

class TypeMatcher<T> {
  const TypeMatcher();
  bool matches(dynamic x) => x is T;
  toString() {
    if (T == String) return "string";
    if (T == Table) return "table";
    if (T == num) return "number";
    if (T == Closure) return "function";
    if (T == LuaDartFunc) return "function";
    if (T == Thread) return "thread";
    if (T == Null) return "nil";
    return T.toString();
  }
}

class Context {
  Context({
    this.userdata,
    @required this.env,
  });
  
  dynamic userdata;
  
  Table env;
  
  Table stringMetatable;
  
  static String getTypename(dynamic v) {
    if (v is String) return "string";
    if (v is Table) return "table";
    if (v is num) return "number";
    if (v is Closure) return "function";
    if (v is LuaDartFunc) return "function";
    if (v is Thread) return "thread";
    if (v == null) return "nil";
    return "${v.runtimeType}";
  }
  
  static dynamic getArg(List<dynamic> args, int idx, String name, List<TypeMatcher> matchers) {
    if (args.length < idx + 1) throw
    "bad argument #${idx + 1} to '$name' (${matchers[0]} expected, got no value)";
    if (matchers.any((m) => m.matches(args[idx]))) return args[idx];
    throw "bad argument #${idx + 1} to '$name' (${matchers[0]} expected, got ${getTypename(args[idx])})";
  }
  
  static dynamic getMetatable(dynamic x) {
    if (x is Table && x.metatable != null) {
      return x.metatable.map.containsKey("__metatable") ? x.metatable.map["__metatable"] : x.metatable;
    } // TODO: strings
    return null;
  }
  
  static List<dynamic> attemptCall(dynamic x, [List<dynamic> args = const []]) {
    if (x is Table) {
      return invokeMetamethod(x, "__call", args);
    } else if (x is LuaDartFunc) {
      return x(args);
    } else if (x is Closure) {
      return x(args);
    } else {
      throw "attempt to call a ${getTypename(x)} value";
    }
  }
  
  static dynamic getLength(dynamic x) {
    if (hasMetamethod(x, "__len")) {
      return maybeAt(invokeMetamethod(x, "__len", [x]), 0);
    } else if (x is Table) {
      return x.length;
    } else if (x is String) {
      return x.length;
    } else {
      throw "attempt to get length of a ${getTypename(x)} value";
    }
  }
  
  dynamic tableIndex(dynamic x, dynamic y) {
    if (x is Table) {
      if (!x.map.containsKey(y) && x.metatable != null && x.metatable.map.containsKey("__index")) {
        var ni = x.metatable.map["__index"];
        if (ni is Closure) {
          return ni([this, y]);
        } else {
          return tableIndex(ni, y);
        }
      } else {
        return x.rawget(y);
      }
    } else if (x is String) {
      return stringMetatable.rawget(y);
    } else { // TODO: strings
      throw "attempt to index a ${getTypename(x)} value";
    }
  }
  
  static void tableSet(dynamic x, dynamic k, dynamic v) {
    if (x is Table) {
      if (x.map.containsKey(k) && x.metatable != null && x.metatable.map.containsKey("__newindex")) {
        var ni = x.metatable.map["__newindex"];
        if (ni is Closure) {
          ni([x, k, v]);
        } else {
          tableSet(ni, k, v);
        }
      } else {
        x.rawset(k, v);
      }
    } else { // TODO: strings
      throw "attempt to index a ${getTypename(x)} value";
    }
  }
  
  static dynamic luaToString(dynamic x) {
    if (x == null) {
      return "nil";
    } else if (x is double) {
      if (x == double.INFINITY) return "inf";
      if (x != x) return "-nan";
      if (x == double.NEGATIVE_INFINITY) return "-inf";
      return x.toString().replaceFirst(new RegExp(r"\.0$"), "");
    } else if (hasMetamethod(x, "__tostring")) {
      return invokeMetamethod(x, "__tostring", [x]);
    } else if (x is String) {
      return x;
    } else if (x is int || x is bool) {
      return x.toString();
    } else {
      return "${getTypename(x)}: ${(x.hashCode % 0x100000000).toRadixString(16).padLeft(8, "0")}";
    }
  }
  
  static const keywords = const [
    "and", "break", "do", "else", "elseif", "or",
    "end", "false", "for", "function", "goto",
    "if", "in", "local", "nil", "not", "while",
    "repeat", "return", "then", "true", "until",
  ];
  
  static String luaSerialize(dynamic x) {
    if (x is String) return "\"${luaEscape(x)}\"";
    else if (x is Table) {
      var o = "{";
      for (var e in x.arr) {
        o += luaSerialize(e) + ",";
      }
      
      for (var k in x.map.keys) {
        if (k is String && new RegExp("^[a-zA-Z_][a-zA-Z0-9_]*\$").hasMatch(k) && !keywords.contains(k)) {
          o += "$k = ";
        } else {
          o += "[${luaSerialize(k)}] = ";
        }
        o += "${luaSerialize(x)},";
      }
      
      if (o.endsWith(",")) o = o.substring(0, o.length - 1);
      return "$o}";
    } else return luaToString(x);
  }
  
  static dynamic luaConcat(dynamic x, dynamic y) {
    if (hasMetamethod(x, "__concat")) {
      return maybeAt(invokeMetamethod(x, "__concat", [x, y]), 0);
    } else if (hasMetamethod(y, "__concat")) {
      return maybeAt(invokeMetamethod(y, "__concat", [x, y]), 0);
    } else if (x is! num && x is! String) {
      throw "attempt to concatenate a ${getTypename(x)} value";
    } else if (y is! num && x is! String) {
      throw "attempt to concatenate a ${getTypename(y)} value";
    } else {
      return luaToString(x) + luaToString(y);
    }
  }
  
  static List<dynamic> invokeMetamethod(dynamic x, String name, List<dynamic> params) {
    if (x is Table) {
      if (x.map[name] is! Closure) throw "attempt to call table value";
      return x.map[name](params);
    } else { // TODO: strings
      throw "attempt to invoke metamethod on a ${getTypename(x)} value";
    }
  }
  
  // TODO: strings
  static bool hasMetamethod(dynamic x, String method) => x is Table && x.metatable != null && x.metatable.map.containsKey(method);
  
  static dynamic attemptArithmetic(dynamic x, dynamic y, String method, ArithCB op) {
    if (hasMetamethod(x, method)) {
      return maybeAt(invokeMetamethod(x, method, [x, y]), 0);
    } else if (hasMetamethod(y, method)) {
      return maybeAt(invokeMetamethod(y, method, [x, y]), 0);
    } else if (x is! num) {
      throw "attempt to perform arithmetic on a ${getTypename(x)} value";
    } else if (y is! num) {
      throw "attempt to perform arithmetic on a ${getTypename(y)} value";
    } else {
      return op(x, y);
    }
  }
  
  static num attemptUnary(dynamic x, String method, UArithCB op) {
    if (hasMetamethod(x, method)) {
      return maybeAt(invokeMetamethod(x, method, [x]), 0);
    } else if (x is! num) {
      throw "attempt to perform arithmetic on a ${getTypename(x)} value";
    } else {
      return op(x);
    }
  }
  
  static bool checkEQ(dynamic x, dynamic y) {
    if (
    hasMetamethod(x, "__eq") && hasMetamethod(y, "__eq") &&
      (x as Table).map["__eq"] == (y as Table).map["__eq"]
    ) {
      return truthy(invokeMetamethod(x, "__eq", [x, y]));
    } else {
      return x == y;
    }
  }
  
  static bool checkLT(dynamic x, dynamic y) {
    if (hasMetamethod(x, "__lt")) {
      return maybeAt(invokeMetamethod(x, "__lt", [x, y]), 0);
    } else if (hasMetamethod(y, "__lt")) {
      return maybeAt(invokeMetamethod(y, "__lt", [x, y]), 0);
    } else if (x is! num) {
      throw "attempt to compare ${getTypename(x)} with ${getTypename(y)}";
    } else if (y is! num) {
      throw "attempt to compare ${getTypename(y)} with ${getTypename(x)}";
    } else {
      return x < y;
    }
  }
  
  static bool checkLE(dynamic x, dynamic y) {
    if (hasMetamethod(x, "__le")) {
      return maybeAt(invokeMetamethod(x, "__le", [x, y]), 0);
    } else if (hasMetamethod(y, "__le")) {
      return maybeAt(invokeMetamethod(y, "__le", [x, y]), 0);
    } else if (x is! num) {
      throw "attempt to compare ${getTypename(x)} with ${getTypename(y)}";
    } else if (y is! num) {
      throw "attempt to compare ${getTypename(y)} with ${getTypename(x)}";
    } else {
      return !checkLT(y, x);
    }
  }
  
  static bool truthy(dynamic x) => x != null && x != false;
  static num add(num x, num y) => x + y;
  static num sub(num x, num y) => x - y;
  static num mul(num x, num y) => x * y;
  static num div(num x, num y) => x / y;
  static num mod(num x, num y) => x % y;
  static num unm(num x) => -x;
  static bool not(dynamic x) => !truthy(x);
}