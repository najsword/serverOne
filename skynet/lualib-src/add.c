#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "luaconf.h"

double add(double x, double y) {
    return x+y;
}

static int ladd(lua_State* L) {
    double x = luaL_checknumber(L, 1);
    double y = luaL_checknumber(L, 2);
    lua_pushnumber(L, add(x, y));
    return 1;
}

int luaopen_add(lua_State* L) {
    luaL_checkversion(L);

    struct luaL_Reg funcs[] = {
        {"add", ladd},
        {NULL,  NULL}
    };
    luaL_newlib(L, funcs);
    return 1;
}