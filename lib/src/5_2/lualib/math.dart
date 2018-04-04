import 'dart:math';
import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/context.dart';

const rpd = PI / 180;

loadMath(Context ctx) {
  var math = new Table();
  ctx.env["math"] = math;

  math["abs"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "abs", [const TypeMatcher<num>()]);
    return [x.abs()];
  };

  math["acos"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "acos", [const TypeMatcher<num>()]);
    return [acos(x)];
  };

  math["asin"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "asin", [const TypeMatcher<num>()]);
    return [asin(x)];
  };

  math["atan"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "atan", [const TypeMatcher<num>()]);
    return [atan(x)];
  };

  math["atan2"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "atan2", [const TypeMatcher<num>()]);
    num y = Context.getArg(args, 1, "atan2", [const TypeMatcher<num>()]);
    return [atan2(x, y)];
  };

  math["ceil"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "ceil", [const TypeMatcher<num>()]);
    return [x.ceil()];
  };

  math["cos"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "cos", [const TypeMatcher<num>()]);
    return [cos(x)];
  };

  math["cosh"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "cosh", [const TypeMatcher<num>()]);
    return [
      (pow(E, x) + pow(E, -x)) / 2,
    ];
  };

  math["deg"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "deg", [const TypeMatcher<num>()]);
    return [x / rpd];
  };

  math["exp"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "exp", [const TypeMatcher<num>()]);
    return [pow(E, x)];
  };

  math["floor"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "floor", [const TypeMatcher<num>()]);
    return [x.floor()];
  };

  math["fmod"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "fmod", [const TypeMatcher<num>()]);
    num y = Context.getArg(args, 1, "fmod", [const TypeMatcher<num>()]);
    return [(x % y) * x.sign];
  };

  math["frexp"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "frexp", [const TypeMatcher<num>()]);
    
    int e = 0;

    while (x < 0.5) {
      x *= 2;
      e--;
    }
    
    while (x > 1.0) {
      x /= 2;
      e++;
    }
    
    return [x, e];
  };
  
  math["huge"] = double.INFINITY;
  
  math["ldexp"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "ldexp", [const TypeMatcher<num>()]);
    num y = Context.getArg(args, 1, "ldexp", [const TypeMatcher<num>()]);
    return [x * pow(2, y)];
  };
  
  math["log"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "log", [const TypeMatcher<num>()]);
    if (args.length < 2) return [log(x)];
    num y = Context.getArg(args, 1, "log", [const TypeMatcher<num>()]);
    return [log(x) / log(y)];
  };
  
  math["max"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "max", [const TypeMatcher<num>()]);
    for (int i = 1; i < args.length; i++) {
      x = max(x, Context.getArg(args, 0, "max", [const TypeMatcher<num>()]));
    }
    return [x];
  };
  
  math["min"] = (List<dynamic>args) {
    num x = Context.getArg(args, 0, "min", [const TypeMatcher<num>()]);
    for (int i = 1; i < args.length; i++) {
      x = min(x, Context.getArg(args, 0, "min", [const TypeMatcher<num>()]));
    }
    return [x];
  };
  
  math["modf"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "modf", [const TypeMatcher<num>()]);
    var o = x.floor();
    return [o, x - o];
  };
  
  math["pi"] = PI;

  math["pow"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "pow", [const TypeMatcher<num>()]);
    num y = Context.getArg(args, 1, "pow", [const TypeMatcher<num>()]);
    return [pow(x, y)];
  };

  math["rad"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "rad", [const TypeMatcher<num>()]);
    return [x * rpd];
  };

  var rng = new Random();
  
  math["random"] = (List<dynamic> args) {
    if (args.length == 0) return [rng.nextDouble()];
    num mn = Context.getArg(args, 0, "random", [const TypeMatcher<num>()]);
    num mx;
    
    if (args.length < 2) {
      mx = mn;
      mn = 1;
    } else {
      mx = Context.getArg(args, 1, "random", [const TypeMatcher<num>()]);
      if (mx < mn) throw "bad argument #2 to 'random' (interval is empty)";
    }
    
    return [rng.nextInt(mx.floor() - mn.floor()) + mn.floor()];
  };

  math["randomseed"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "randomseed", [const TypeMatcher<num>()]);
    rng = new Random(x.floor());
    return [];
  };

  math["sin"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "sin", [const TypeMatcher<num>()]);
    return [sin(x)];
  };

  math["sinh"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "sinh", [const TypeMatcher<num>()]);
    return [(pow(E, x) - pow(E, -x)) / 2];
  };

  math["sqrt"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "sqrt", [const TypeMatcher<num>()]);
    return [sqrt(x)];
  };

  math["tan"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "tan", [const TypeMatcher<num>()]);
    return [tan(x)];
  };

  math["tanh"] = (List<dynamic> args) {
    num x = Context.getArg(args, 0, "tanh", [const TypeMatcher<num>()]);
    return [(pow(E, x) - pow(E, -x)) / (pow(E, x) + pow(E, -x))];
  };
}