#include "skynet_malloc.h"

#include "skynet_socket.h"

#include <lua.h>
#include <lauxlib.h>

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define SMALLSTRING 2048

#define TYPE_DATA 1
#define TYPE_MORE 2
#define TYPE_ERROR 3
#define TYPE_OPEN 4
#define TYPE_CLOSE 5

static int
filter_data_(lua_State *L, int fd, uint8_t * buffer, int size) {
	lua_pushvalue(L, lua_upvalueindex(TYPE_DATA));
	lua_pushinteger(L, fd);
	lua_pushlstring(L, (char *)buffer, size);
	lua_pushinteger(L, size);
	return 4;
}

static inline int
filter_data(lua_State *L, int fd, uint8_t * buffer, int size) {
	int ret = filter_data_(L, fd, buffer, size);
	// buffer is the data of socket message, it malloc at socket_server.c : function forward_message .
	// it should be free before return,
	skynet_free(buffer);
	return ret;
}

static void
pushstring(lua_State *L, const char * msg) {
	if (msg) {
		lua_pushstring(L, msg);
	} else {
		lua_pushliteral(L, "");
	}
}

/*
	userdata queue
	lightuserdata msg
	integer size
	return
		userdata queue
		integer type
		integer fd
		string msg | lightuserdata/integer
 */
static int
lfilter(lua_State *L) {
	struct skynet_socket_message *message = lua_touserdata(L,1);
	int size = luaL_checkinteger(L,2);
	char * buffer = message->buffer;
	if (buffer == NULL) {
		buffer = (char *)(message+1);
		size -= sizeof(*message);
	} else {
		size = -1;
	}

	switch(message->type) {
	case SKYNET_SOCKET_TYPE_DATA:
		// ignore listen id (message->id)
		assert(size == -1);	// never padding string
		return filter_data(L, message->id, (uint8_t *)buffer, message->ud);
	case SKYNET_SOCKET_TYPE_CONNECT:
		// ignore listen fd connect
		return 0;
	case SKYNET_SOCKET_TYPE_CLOSE:
		lua_pushvalue(L, lua_upvalueindex(TYPE_CLOSE));
		lua_pushinteger(L, message->id);
		return 2;
	case SKYNET_SOCKET_TYPE_ACCEPT:
		lua_pushvalue(L, lua_upvalueindex(TYPE_OPEN));
		// ignore listen id (message->id);
		lua_pushinteger(L, message->ud);
		pushstring(L, buffer);
		return 3;
	case SKYNET_SOCKET_TYPE_ERROR:
		lua_pushvalue(L, lua_upvalueindex(TYPE_ERROR));
		lua_pushinteger(L, message->id);
		pushstring(L, buffer);
		return 3;
	default:
		// never get here
		return 0;
	}
}

// int
// luaopen_httppack(lua_State *L) {
// 	luaL_checkversion(L);

// 	// the order is same with macros : TYPE_* (defined top)
// 	lua_pushliteral(L, "data");
// 	lua_pushliteral(L, "more");
// 	lua_pushliteral(L, "error");
// 	lua_pushliteral(L, "open");
// 	lua_pushliteral(L, "close");

// 	lua_pushcclosure(L, lfilter, 5);
// 	lua_setfield(L, -2, "filter");

// 	return 1;
// }

int luaopen_httppack(lua_State* L) {
    luaL_checkversion(L);

    struct luaL_Reg funcs[] = {
        {"filter", lfilter},
        {NULL,  NULL}
    };
	luaL_newlib(L, funcs);

	// the order is same with macros : TYPE_* (defined top)
	lua_pushliteral(L, "data");
	lua_pushliteral(L, "more");
	lua_pushliteral(L, "error");
	lua_pushliteral(L, "open");
	lua_pushliteral(L, "close");

	lua_pushcclosure(L, lfilter, 5);
	lua_setfield(L, -2, "filter");

    return 1;
}