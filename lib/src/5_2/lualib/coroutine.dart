import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/5_2/vm.dart';
import 'package:lua/src/5_2/state.dart';
import 'package:lua/src/5_2/context.dart';

loadCoroutine(Context ctx) {
  var coroutine = new Table();
  ctx.env["coroutine"] = coroutine;

  coroutine["create"] = (List<dynamic> args) {
    Closure x = Context.getArg1<Closure>(args, 0, "create");
    return [new Thread(closure: x)];
  };

  coroutine["resume"] = (List<dynamic> args) {
    Thread x = Context.getArg1<Thread>(args, 0, "resume");
    
    if (x.status != CoroutineStatus.SUSPENDED) {
      return [false, "cannot resume non-suspended coroutine"];
    }
    
    var res = x.resume(args.skip(1).toList(growable: false));
    
    if (!res.success) return [];
    
    var o = [];
    o.addAll(res.values);
  };
}