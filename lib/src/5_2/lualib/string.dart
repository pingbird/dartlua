import 'dart:math';

import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/context.dart';
import 'package:lua/src/util.dart';

loadString(Context ctx) {
  var string = new Table();
  
  ctx.env["string"] = string;
  ctx.stringMetatable = string;

  string["rep"] = (List<dynamic> args) {
    String str = Context.luaToString(Context.getArg(args, 0, "rep", [const TypeMatcher<String>(), const TypeMatcher<num>()]));
    num amount = Context.getArg(args, 1, "rep", [const TypeMatcher<num>()]);
    return [str * amount.floor()];
  };

  string["char"] = (List<dynamic> args) {
    var o = new StringBuffer();
  
    for (int i = 0; i < args.length; i++) {
      int n = (Context.getArg(args, i, "char", [const TypeMatcher<num>()]) as num).floor();
      if (n < 0 || n > 255) throw "bad argument #${i + 1} to 'char' (value out of range)";
      o.writeCharCode(n);
    }
  
    return [o.toString()];
  };

  string["sub"] = (List<dynamic> args) {
    String str = Context.luaToString(Context.getArg(args, 0, "sub", [const TypeMatcher<String>(), const TypeMatcher<num>()]));
    int start = (Context.getArg(args, 1, "sub", [const TypeMatcher<num>()]) as num).floor();
    int end = maybeAt(args, 2) == null ? str.length : (Context.getArg(args, 2, "sub", [const TypeMatcher<num>()]) as num).floor();
    
    if (start == 0) start = 1;
    if (start < 0) start = str.length + start + 1;
    end = min(end, str.length);
    if (end < 0) end = str.length + end + 1;
    
    return start > end ? [""] : [str.substring(start - 1, end)];
  };

  string["byte"] = (List<dynamic> args) {
    String str = Context.luaToString(Context.getArg(args, 0, "sub", [const TypeMatcher<String>(), const TypeMatcher<num>()]));
    int start = (Context.getArg(args, 1, "sub", [const TypeMatcher<num>()]) as num).floor();
    int end = maybeAt(args, 2) == null ? start : (Context.getArg(args, 2, "sub", [const TypeMatcher<num>()]) as num).floor();
  
    if (start == 0) start = 1;
    if (start < 0) start = str.length + start + 1;
    end = min(end, str.length);
    if (end < 0) end = str.length + end + 1;
    
    return start > end ? [] : str.substring(start- 1, end).codeUnits;
  };
}