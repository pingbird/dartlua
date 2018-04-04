import 'dart:math';
import 'dart:typed_data';

import 'package:lua/src/5_2/context.dart';
import 'package:lua/src/5_2/table.dart';
import 'package:lua/src/func.dart';
import 'package:lua/src/util.dart';
import 'package:meta/meta.dart';
import 'package:lua/src/5_2/state.dart';

class Closure {
  Closure(this.prototype, {
    this.parent,
    Context context,
    List<UStorage> upvalues,
  }) :
    context = context ?? parent.closure.context,
    upvalues = upvalues ?? new List.filled(prototype.upvals.length, null),
    instructions = new Int32List(prototype.code.length * 4) {
    
    for (int i = 0; i < prototype.code.length; i++) {
      var inst = prototype.code[i];
      instructions[i * 4] = inst.OP;
      instructions[(i * 4) + 1] = inst.A;
      instructions[(i * 4) + 2] = inst.B;
      instructions[(i * 4) + 3] = inst.C;
    }
  }
  
  final Frame parent;
  Context context;
  final Prototype prototype;
  Iterable<Frame> frames;
  Int32List instructions;

  final List<UStorage> upvalues;
  
  List<dynamic> call(List<dynamic> args) {
    var thread = new Thread(
      closure: this,
    );
    
    var res = thread.resume(args);
    
    if (!res.success) {
      throw res.result.isEmpty ? null : maybeAt(res.result, 0);
    } else if (res.yielded) {
      throw "attempt to yield across Dart call boundary";
    }
    
    return res.result;
  }
}

typedef void UpvalueSetter(dynamic x);
typedef dynamic UpvalueGetter();

class UStorage {
  bool open = true;
  dynamic storage;
}

class DecodedInst {
  DecodedInst(this.OP, [this.A = 0, this.B = 0, this.C = 0]);
  final int OP;
  final int A;
  final int B;
  final int C;
}

class Frame {
  Frame(this.closure, {@required this.bottom}) :
    openUpvalues = new List.filled(closure.prototype.registers, null),
    _top = closure.prototype.registers {}
    
  int bottom;
  final Closure closure;
  final List<UStorage> openUpvalues;
  
  bool dead = false;
  int _top;
  int pc = 0;
  List<dynamic> args;
}

class ThreadResult {
  ThreadResult(this.success, this.yielded, this.result);
  final bool success;
  final bool yielded;
  final List<dynamic> result;
}

class Thread {
  Thread({
    @required Closure closure,
  }) : registers = new List.filled(closure.prototype.registers, null, growable: true) {
    _frames.add(new Frame(closure, bottom: 0));
  }

  List<dynamic> registers;
  
  CoroutineStatus status = CoroutineStatus.SUSPENDED;
  bool started = false;
  
  List<Frame> _frames = [];

  int _getExtraArg() => _code[_frame.pc++ * 4 + 1];
  int _getNextJump() => _code[_frame.pc * 4 + 2];
  
  dynamic _RK(int x) => x >= 256 ? _K[x - 256].value : _GR(x);
  dynamic _GR(int x) {
    return registers[x + _bottom];
  }
  dynamic _SR(int x, dynamic y) {
    x += _bottom;
    if (x < _bottom) throw "Register out of bounds $x (${_bottom}, ${_frame._top})";
    return registers[x] = y;
  }

  void loadReturns(List<dynamic> ret) {
    var code = _closure.instructions;
    var pc = _frame.pc;
    var A = code[pc * 4 - 3];
    var B = code[pc * 4 - 2];
    var C = code[pc * 4 - 1];
  
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
  
  dynamic _getUpval(Frame f, int idx) {
    var uv = f.closure.upvalues[idx];
    var pr = f.closure.prototype.upvals[idx];
    if (uv.open) {
      if (pr.stack) {
        if (f.closure.parent.dead) throw "dead parent ${new LuaErrorImpl("", f.closure.parent.closure.prototype, 0)}";
        return registers[f.closure.parent.bottom + pr.reg];
      } else {
        return _getUpval(f.closure.parent, pr.reg);
      }
    } else return uv.storage;
  }
  
  dynamic getUpval(Frame f, int idx) {
    var o = _getUpval(f, idx);
    return o;
  }

  void setUpval(Frame f, int idx, dynamic value) {
    var uv = f.closure.upvalues[idx];
    var pr = f.closure.prototype.upvals[idx];
    if (!uv.open) {
      uv.storage = value;
    } else if (pr.stack) {
      registers[f.closure.parent.bottom + pr.reg] = value;
    } else {
      setUpval(f.closure.parent, pr.reg, value);
    }
  }
  
  void closeUpvals(int from) {
    for (int i = from; i < _prototype.registers; i++) {
      if (_frame.openUpvalues[i] != null) {
        _frame.openUpvalues[i]
          ..storage = _GR(i)
          ..open = false;
      }
    }
  }
  
  void setTop(int x) {
    if (x >= registers.length - _bottom) {
      registers.length = _bottom + x + 1;
    }
    
    _frame._top = x;
  }
  
  void _updateFrame() {
    _frame = _frames.last;
    _closure = _frame.closure;
    _prototype = _closure.prototype;
    _code = _closure.instructions;
    _K = _prototype.constants;
    _G = _frames[0].closure.context;
    _bottom = _frame.bottom;
  }
  
  Frame _frame;
  Closure _closure;
  Prototype _prototype;
  Int32List _code;
  List<Const> _K;
  Context _G;
  int _bottom;

  ThreadResult resume([List<dynamic> params = const []]) {
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
        var OP = _code[pc * 4];
        var A = _code[pc * 4 + 1];
        var B = _code[pc * 4 + 2];
        var C = _code[pc * 4 + 3];
        
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
          registers.fillRange(a + _bottom, a + B + 1 + _bottom);
        } else if (OP == 5) { // GETUPVAL(AB)
          _SR(A, getUpval(_frame, B));
        } else if (OP == 6) { // GETTABUP(ABC)
          var v = _G.tableIndex(getUpval(_frame, B), _RK(C));
          _SR(A, v);
        } else if (OP == 7) { // GETTABLE(ABC)
          _SR(A, _G.tableIndex(_RK(B), _RK(C)));
        } else if (OP == 8) { // SETTABUP(ABC)
          Context.tableSet(getUpval(_frame, A), _RK(B), _RK(C));
        } else if (OP == 9) { // SETUPVAL(A)
          setUpval(_frame, B, _GR(A));
        } else if (OP == 10) { // SETTABLE(ABC)
          Context.tableSet(_GR(A), _RK(B), _RK(C));
        } else if (OP == 11) { // NEWTABLE(ABC)
          _SR(A, new Table()); // TODO: pre-allocate
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
            _frames.add(new Frame(x, bottom: _frame.bottom + _frame._top));
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
            _frames.add(new Frame(x, bottom: _frame.bottom + _frame._top));
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
              return new ThreadResult(true, false, ret);
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
            return new ThreadResult(true, false, ret);
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
          
          var b = _code[_frame.pc * 4 + 2];
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
          
          for (int i = 0; i < proto.upvals.length; i++) {
            var uv = proto.upvals[i];
            if (uv.stack) {
              _frame.openUpvalues[uv.reg] ??= new UStorage();
            }
          }
          
          _SR(A, new Closure(
            proto,
            parent: _frame,
            upvalues: new List.generate(proto.upvals.length, (i) =>
              (proto.upvals[i].stack ? _frame.openUpvalues[proto.upvals[i].reg] : null) ?? new UStorage()
            ),
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