import 'dart:collection';
import 'dart:math';

import 'package:lua/src/5_2/context.dart';
import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/func.dart';
import 'package:lua/src/inst.dart';
import 'package:lua/src/util.dart';
import 'package:meta/meta.dart';
import 'package:lua/src/5_2/state.dart';

class Upval extends LinkedListEntry<Upval> {
  Upval(this.reg, this.base, this.registers) : open = true;
  Upval.store(this.storage) : open = false;
  
  bool open;
  int reg;
  int base;
  List<dynamic> registers;
  dynamic storage;
  
  void close() {
    open = false;
    storage = registers[reg + base];
    registers = null;
    unlink();
  }
  
  void set(dynamic v) {
    if (open) {
      registers[reg + base] = v;
    } else {
      storage = v;
    }
  }
  
  dynamic get() => open ? registers[reg] : storage;
}

class Closure {
  Closure(this.prototype, {
    this.parent,
    Context context,
    List<Upval> upvalues,
  }) :
    context = context ?? parent.closure.context,
    upvalues = upvalues ?? new List.filled(prototype.upvals.length, null) {}
  
  final Frame parent;
  Context context;
  final Prototype prototype;
  Iterable<Frame> frames;

  final List<Upval> upvalues;
  
  List<dynamic> call(List<dynamic> args) {
    var thread = new Thread(
      closure: this,
    );
    
    var res = thread.resume(args);
    
    if (!res.success) {
      throw res.values.isEmpty ? null : maybeAt(res.values, 0);
    } else if (thread.status == CoroutineStatus.SUSPENDED) {
      throw "attempt to yield across Dart call boundary";
    }
    
    return res.values;
  }
}

class Frame {
  Frame(this.closure, {@required this.base}) :
    _top = closure.prototype.registers {}
    
  int base;
  final Closure closure;
  final openUVs = new LinkedList<Upval>();
  
  bool dead = false;
  int _top;
  int pc = 0;
  List<dynamic> args;
}

class Thread {
  Thread({
    @required Closure closure,
  }) : registers = new List.filled(closure.prototype.registers, null, growable: true) {
    _frames.add(new Frame(closure, base: 0));
  }

  List<dynamic> registers;
  
  CoroutineStatus status = CoroutineStatus.SUSPENDED;
  bool started = false;
  
  List<Frame> _frames = [];

  int _getExtraArg() => _code[_frame.pc++].A;
  int _getNextJump() => _code[_frame.pc].B;
  
  dynamic _RK(int x) => x >= 256 ? _K[x - 256].value : _GR(x);
  dynamic _GR(int x) => registers[x + _base];
  dynamic _SR(int x, dynamic y) => registers[x + _base] = y;

  void loadReturns(List<dynamic> ret) {
    var pc = _frame.pc;
    var inst = _code[pc - 1];
    var A = inst.A;
    var B = inst.B;
    var C = inst.C;
  
    if (C == 2) {
      _SR(A, maybeAt(ret, 0));
    } else if (C != 1) {
      if (C == 0) setTop(A + ret.length - 1);
      if (B == 1) {
        if (C == 0) {
          for (int i = A; i < A + ret.length; i++) _SR(i, maybeAt(ret, i - A));
        } else {
          int g = 0;
          for (int i = A; i < A + C; i++) _SR(i, maybeAt(ret, g++));
        }
      } else {
        if (C == 0) {
          for (var i = 0; i < ret.length; i++) _SR(A + i, maybeAt(ret, i));
        } else {
          var g = 0;
          for (int i = A; i < A + C - 1; i++) _SR(i, maybeAt(ret, g++));
        }
      }
    }
  }
  
  dynamic getUpval(int idx) => _closure.upvalues[idx].get();
  dynamic setUpval(int idx, dynamic value) => _closure.upvalues[idx].set(value);
  
  void closeUpvals(int from) {
    if (_frame.openUVs.isEmpty) return;
    
    var e = _frame.openUVs.first;
    while (e != null && e.reg >= from) {
      var next = e.next;
      e.close();
      e = next;
    }
  }

  Upval openUpval(int reg) {
    if (_frame.openUVs.isEmpty) {
      var uv = new Upval(reg, _base, registers);
      _frame.openUVs.addFirst(uv);
      return uv;
    }
    
    var e = _frame.openUVs.first;
    while (e.reg >= reg) {
      if (e.reg == reg) return e;
      if (e.next == null) {
        var uv = new Upval(reg, _base, registers);
        e.insertAfter(uv);
        return uv;
      }
      e = e.next;
    }
    
    var uv = new Upval(reg, _base, registers);
    e.insertBefore(uv);
    return uv;
  }
  
  void setTop(int x) {
    if (x >= registers.length - _base) {
      registers.length = _base + x + 1;
    }
    
    _frame._top = x;
  }
  
  void _updateFrame() {
    _frame = _frames.last;
    _closure = _frame.closure;
    _prototype = _closure.prototype;
    _code = _prototype.code;
    _K = _prototype.constants;
    _G = _frames[0].closure.context;
    _base = _frame.base;
  }
  
  Frame _frame;
  Closure _closure;
  Prototype _prototype;
  List<Inst> _code;
  List<Const> _K;
  Context _G;
  int _base;

  CoroutineResult resume([List<dynamic> params = const []]) {
    if (!started) {
      _updateFrame();
      for (int i = 0; i < max(params.length, _closure.prototype.params); i++) {
        _SR(i, maybeAt(params, i));
        _frame.args = params;
      }
      
      started = true;
    }

    try {
      while (true) {
        var pc = _frame.pc++;
        var inst = _code[pc];
        var OP = inst.OP;
        var A = inst.A;
        var B = inst.B;
        var C = inst.C;
        
        if (OP == 0) { // MOVE(AB)
          _SR(A, _GR(B));
        } else if (OP == 1) { // LOADK(ABx)
          _SR(A, _K[B].value);
        } else if (OP == 2) { // LOADKX(A)
          _SR(A, _K[_getExtraArg()].value);
        } else if (OP == 3) { // LOADBOOL(ABC)
          _SR(A, B != 0);
          if (C != 0) _frame.pc++;
        } else if (OP == 4) { // LOADNIL(AB)
          var a = A;
          registers.fillRange(a + _base, a + B + 1 + _base);
        } else if (OP == 5) { // GETUPVAL(AB)
          _SR(A, getUpval(B));
        } else if (OP == 6) { // GETTABUP(ABC)
          var v = _G.tableIndex(getUpval(B), _RK(C));
          _SR(A, v);
        } else if (OP == 7) { // GETTABLE(ABC)
          _SR(A, _G.tableIndex(_RK(B), _RK(C)));
        } else if (OP == 8) { // SETTABUP(ABC)
          Context.tableSet(getUpval(A), _RK(B), _RK(C));
        } else if (OP == 9) { // SETUPVAL(A)
          setUpval(B, _GR(A));
        } else if (OP == 10) { // SETTABLE(ABC)
          Context.tableSet(_GR(A), _RK(B), _RK(C));
        } else if (OP == 11) { // NEWTABLE(ABC)
          _SR(A, new Table());
        } else if (OP == 12) { // SELF(ABC)
          _SR(A + 1, _GR(B));
          _SR(A, _G.tableIndex(_GR(B), _RK(C)));
        } else if (OP == 13) { // ADD(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__add", Context.add));
        } else if (OP == 14) { // SUB(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__sub", Context.sub));
        } else if (OP == 15) { // MUL(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__mul", Context.mul));
        } else if (OP == 16) { // DIV(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__div", Context.div));
        } else if (OP == 17) { // MOD(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__mod", Context.mod));
        } else if (OP == 18) { // POW(ABC)
          _SR(A, Context.attemptArithmetic(_RK(B), _RK(C), "__pow", pow));
        } else if (OP == 19) { // UNM(AB)
          _SR(A, Context.attemptUnary(_GR(A), "__unm", Context.unm));
        } else if (OP == 20) { // NOT(AB)
          _SR(A, !Context.truthy(_GR(B)));
        } else if (OP == 21) { // LEN(AB)
          _SR(A, Context.getLength(_GR(B)));
        } else if (OP == 22) { // CONCAT
          var o = _GR(B);
          for (int i = B + 1; i <= C; i++) {
            o = Context.luaConcat(o, _GR(i));
          }
          _SR(A, o);
        } else if (OP == 23) { // JMP(AsBx)
          _frame.pc += B;
          if (A > 0) closeUpvals(A - 1);
        } else if (OP == 24) { // EQ
          if (Context.checkEQ(_RK(B), _RK(C)) == (A != 0)) {
            _frame.pc += _getNextJump() + 1;
          } else {
            _frame.pc++;
          }
        } else if (OP == 25) { // LT
          if (Context.checkLT(_RK(B), _RK(C)) == (A != 0)) {
            _frame.pc += _getNextJump() + 1;
          } else {
            _frame.pc++;
          }
        } else if (OP == 26) { // LE
          if (Context.checkLE(_RK(B), _RK(C)) == (A != 0)) {
            _frame.pc += _getNextJump() + 1;
          } else {
            _frame.pc++;
          }
        } else if (OP == 27) { // TEST
          if (!Context.truthy(_GR(A)) == (C != 0)) {
            _frame.pc++;
          } else {
            _frame.pc += _getNextJump() + 1;
          }
        } else if (OP == 28) { // TESTSET
          if (!Context.truthy(_GR(B)) == (C != 0)) {
            _frame.pc++;
          } else {
            _SR(A, _GR(B));
            _frame.pc += _getNextJump() + 1;
          }
        } else if (OP == 29) { // CALL
          if (B != 0) setTop(A + B);
          var x = _GR(A);
          var args = new List(B == 0 ? _frame._top - A : B - 1);
          if (B != 1) for (int i = 0; i < args.length; i++) args[i] = _GR(i + A + 1);
          
          if (x is Closure) {
            _frames.add(new Frame(x, base: _frame.base + _frame._top));
            _updateFrame();
            setTop(_prototype.registers);
            if (_prototype.varag > 0) _frame.args = args;
            for (int i = 0; i < min(args.length, _closure.prototype.params); i++) {
              _SR(i, maybeAt(args, i));
            }
          } else {
            var ret = Context.attemptCall(x, args);
            loadReturns(ret);
          }
        } else if (OP == 30) { // TAILCALL(ABC)
          var args = new List(B == 0 ? _frame._top - A : B - 1);
          if (B != 1) for (int i = 0; i < args.length; i++) args[i] = _GR(i + A + 1);
          var x = _GR(A);
          closeUpvals(0);
          
          if (x is Closure) {
            _frame.dead = true;
            _frames.removeLast();
            _frames.add(new Frame(x, base: _frame.base + _frame._top));
            _updateFrame();
            setTop(_prototype.registers);
            if (_prototype.varag > 0) _frame.args = args;
            for (int i = 0; i < max(args.length, _closure.prototype.params); i++) {
              _SR(i, maybeAt(args, i));
            }
          } else {
            var ret = Context.attemptCall(_GR(A), args);

            if (_frames.length == 1) {
              status = CoroutineStatus.DEAD;
              return new CoroutineResult(true, ret);
            } else {
              _frame.dead = true;
              _frames.removeLast();
              _updateFrame();
              loadReturns(ret);
            }
          }
        } else if (OP == 31) { // RETURN(ABC)
          closeUpvals(0);
          var ret = new List(B == 0 ? 1 + _frame._top - A : B - 1);
          for (int i = A; i < (B == 0 ? _frame._top : A + B - 1); i++) ret[i - A] = _GR(i);
          
          if (_frames.length == 1) {
            status = CoroutineStatus.DEAD;
            return new CoroutineResult(true, ret);
          } else {
            _frame.dead = true;
            _frames.removeLast();
            _updateFrame();
            loadReturns(ret);
          }
        } else if (OP == 32) { // FORLOOP(AsBx)
          var step = _GR(A + 2);
          var idx = _SR(A, _GR(A) + step);
          var limit = _GR(A + 1);
          
          if ((step > 0 && idx <= limit) || (step < 0 && limit <= idx)) {
            _frame.pc += B;
            _SR(A + 3, _GR(A));
          }
        } else if (OP == 33) { // FORPREP(AsBx)
          var init = _GR(A);
          var limit = _GR(A + 1);
          var step = _GR(A + 2);
          
          if (init is! num) throw "'for' initial value must be a number";
          if (limit is! num) throw "'for' limit value must be a number";
          if (step is! num) throw "'for' step value must be a number";
          
          _SR(A, _GR(A) - step);
          _frame.pc += B;
        } else if (OP == 34) { // TFORCALL(ABC)
          var ret = Context.attemptCall(_GR(A), [_GR(A + 1), _GR(A + 2)]);
          var i = 0;
          for (int n = A + 3; n < A + C + 3; n++) _SR(n, maybeAt(ret, i++));
          
          var b = _code[_frame.pc].B;
          var a = _getExtraArg();
          
          if (_GR(a + 1) != null) {
            _SR(a, _GR(a + 1));
            _frame.pc += b;
          }
        } else if (OP == 35) { // TFORLOOP(AsBx)
          if (_GR(A + 1) != null) {
            _SR(A, _GR(A + 1));
            _frame.pc += B;
          }
        } else if (OP == 36) { // SETLIST(ABC)
          if (B > 0) {
            for (int i = 1; i <= B; i++) Context.tableSet(_GR(A), ((C - 1) * 50) + i, _GR(A + i));
          } else {
            for (int i = 1; i <= _frame._top - A; i++) Context.tableSet(_GR(A), ((C - 1) * 50) + i, _GR(A + i));
          }
        } else if (OP == 37) { // CLOSURE(ABC)
          var proto = _prototype.prototypes[B];
          
          _SR(A, new Closure(
            proto,
            parent: _frame,
            upvalues: new List.generate(proto.upvals.length, (i) {
              var def = proto.upvals[i];
              return def.stack ? openUpval(def.reg) : _closure.upvalues[def.reg];
            }),
          ));
        } else if (OP == 38) { // VARARG
          if (B > 0) {
            var i = 0;
            for (int n = A; n <= A + B - 2; n++) _SR(n, _frame.args[i++]);
          } else {
            setTop(A + _frame.args.length - (_prototype.params + 1));
            var i = A;
            for (int n = _prototype.params; n < _frame.args.length; n++) _SR(i++, _frame.args[n]);
          }
        } else {
          throw "invalid instruction";
        }
      }
    } catch(e, bt) {
      if (e is LuaError) rethrow;
      throw new LuaErrorImpl(e, _prototype, _frame.pc - 1, dartStackTrace: bt);
    }
  }

  toString() => "thread: 0x${(hashCode % 0x100000000).toRadixString(16).padLeft(8, "0")}";
}