#include <stdint.h>
#include <pthread.h>
#include <time.h>
#include <sys/time.h>
#include "spinlock.h"

#include <lua.h>
#include <lauxlib.h>

#define MAX_INDEX_VAL       0x0fff
#define MAX_WORKID_VAL      0x03ff
#define MAX_TIMESTAMP_VAL   0x01ffffffffff

#define __atomic_read(var)        __sync_fetch_and_add(&(var), 0)
#define __atomic_set(var, val)    __sync_lock_test_and_set(&(var), (val))

typedef struct _t_ctx {
    int64_t last_timestamp;
    int32_t work_id;
    int16_t index;
} ctx_t;

static volatile int g_inited = 0;
static ctx_t g_ctx = { 0, 0, 0 };
static struct spinlock sync_policy = { 0 };

static int64_t
get_timestamp() {
	struct timeval tv;
	gettimeofday(&tv, 0);
	return tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static void
wait_next_msec() {
    int64_t current_timestamp = 0;
    do {
        current_timestamp = get_timestamp();
    } while (g_ctx.last_timestamp >= current_timestamp);
    g_ctx.last_timestamp = current_timestamp;
    g_ctx.index = 0;
}

static uint64_t
next_id() {
    if (!__atomic_read(g_inited)) {
        return -1;
    }
    spinlock_lock(&sync_policy);
    int64_t current_timestamp = get_timestamp();
    if (current_timestamp == g_ctx.last_timestamp) {
        if (g_ctx.index < MAX_INDEX_VAL) {
            ++g_ctx.index;
        } else {
            wait_next_msec();
        }
    } else {
        g_ctx.last_timestamp = current_timestamp;
        g_ctx.index = 0;
    }
    int64_t nextid = (int64_t)(
        ((g_ctx.last_timestamp & MAX_TIMESTAMP_VAL) << 22) | 
        ((g_ctx.work_id & MAX_WORKID_VAL) << 12) | 
        (g_ctx.index & MAX_INDEX_VAL)
    );
    spinlock_unlock(&sync_policy);
    return nextid;
}

static int
init(uint16_t work_id) {
    if (__atomic_read(g_inited)) {
        return 0;
    }
    spinlock_lock(&sync_policy);
    g_ctx.work_id = work_id;
    g_ctx.index = 0;
    __atomic_set(g_inited, 1);
    spinlock_unlock(&sync_policy);
    return 0;
}

static int
linit(lua_State* l) {
    int16_t work_id = 0;
    if (lua_gettop(l) > 0) {
        lua_Integer id = luaL_checkinteger(l, 1);
        if (id < 0 || id > MAX_WORKID_VAL) {
            return luaL_error(l, "Work id is in range of 0 - 1023.");
        }
        work_id = (int16_t)id;
    }
    if (init(work_id)) {
        return luaL_error(l, "Init instance error, not enough memory.");
    }
    lua_pushboolean(l, 1);
    return 1;
}

static int
lnextid(lua_State* l) {
    int64_t id = next_id();
    lua_pushinteger(l, (lua_Integer)id);
    return 1;
}

int
luaopen_snowflake(lua_State* l) {
    luaL_checkversion(l);
    luaL_Reg lib[] = {
        { "init", linit },
        { "next_id", lnextid },
        { NULL, NULL }
    };
    luaL_newlib(l, lib);
    return 1;
}