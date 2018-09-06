#!/usr/bin/env bash

mkdir build
cd build

RED='\033[1;92m\033[1m'
NC='\033[0m'

echo -e "${RED}Downloading lua...${NC}"

sudo apt-get install libreadline-dev libncurses-dev

wget -N http://www.lua.org/ftp/lua-5.2.4.tar.gz &
wget -N http://www.lua.org/ftp/lua-5.1.5.tar.gz &
wget -N http://luajit.org/download/LuaJIT-2.1.0-beta3.tar.gz &
wait

echo -e "${RED}Unpacking lua...${NC}"

tar zxf lua-5.2.4.tar.gz > /dev/null &
tar zxf lua-5.1.5.tar.gz > /dev/null &
tar zxf LuaJIT-2.1.0-beta3.tar.gz > /dev/null &
wait

echo -e "${RED}Building Lua 5.2...${NC}"

cd lua-5.2.4
make clean
make linux -j`grep -c ^processor /proc/cpuinfo` > /dev/null

echo -e "${RED}Building Lua 5.1...${NC}"

cd ../lua-5.1.5
make clean
make linux -j`grep -c ^processor /proc/cpuinfo` > /dev/null

echo -e "${RED}Building LuaJIT 2.1...${NC}"

cd ../LuaJIT-2.1.0-beta3
make clean
make -j`grep -c ^processor /proc/cpuinfo` > /dev/null

echo -e "${RED}Copying to bin...${NC}"

cd ../..
mkdir bin
cp -f build/lua-5.2.4/src/lua bin/lua5.2
cp -f build/lua-5.2.4/src/luac bin/luac5.2
cp -f build/lua-5.1.5/src/lua bin/lua5.1
cp -f build/lua-5.1.5/src/luac bin/luac5.1
cp -f build/LuaJIT-2.1.0-beta3/src/luajit bin/luajit

echo -e "${RED}Done!${NC}"