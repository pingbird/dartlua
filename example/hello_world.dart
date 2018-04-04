import 'package:lua/lua5.2.dart';

main() async {
  var state = new LuaState();
  await state.doFile("example/hello_world.lua");
}