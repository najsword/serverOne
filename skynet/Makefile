include platform.mk

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice

SKYNET_BUILD_PATH ?= .

CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
# CFLAGS += -DUSE_PTHREAD_LOCK

# lua

LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua

$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC='$(CC) -std=gnu99' $(PLAT)

# jemalloc 

JEMALLOC_STATICLIB := 3rd/jemalloc/lib/libjemalloc_pic.a
JEMALLOC_INC := 3rd/jemalloc/include/jemalloc

all : jemalloc zlib
	
.PHONY : jemalloc update3rd

MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)

$(JEMALLOC_STATICLIB) : 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && $(MAKE) CC=$(CC) 

3rd/jemalloc/autogen.sh :
	git submodule update --init

3rd/jemalloc/Makefile : | 3rd/jemalloc/autogen.sh
	cd 3rd/jemalloc && find ./ -name "*.sh" | xargs chmod +x && ./autogen.sh --with-jemalloc-prefix=je_ --disable-valgrind

jemalloc : $(MALLOC_STATICLIB)

update3rd :
	rm -rf 3rd/jemalloc && git submodule update --init

#zlib(in vi :set ff=unix)
ZLIB_STATICLIB := 3rd/lua-zlib/src/libz.a
Z_LIB ?= $(ZLIB_STATICLIB)

$(ZLIB_STATICLIB) :
	cd 3rd/lua-zlib/src && chmod +x ./configure && dos2unix configure && ./configure --libdir=./ && $(MAKE)
zlib : $(ZLIB_STATICLIB)

# skynet

CSERVICE = snlua logger gate harbor

LUA_CLIB = skynet \
  client \
  bson  md5 skynet_crypt sproto lpeg \
  cjson protobuf \
  websocketnetpack clientwebsocket webclient \
  zlib mt19937 snowflake \
  unqlite lsqlite3 \
  httppack add\
  
  
LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-profile.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-mysqlaux.c \
  lua-debugchannel.c \
  lua-datasheet.c \

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

all : \
  $(SKYNET_BUILD_PATH)/skynet \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/skynet : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) $(LUA_LIB) $(MALLOC_STATICLIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src -I$(JEMALLOC_INC) $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ -Iskynet-src

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/client.so : lualib-src/lua-clientsocket.c lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/skynet_crypt.so : lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilualib-src/sproto $^ -o $@ 

$(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg $^ -o $@ 

#websocket解析库
$(LUA_CLIB_PATH)/websocketnetpack.so: lualib-src/lua-websocketnetpack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -Iskynet-src -o $@ 

#用于客户端的websocket
$(LUA_CLIB_PATH)/clientwebsocket.so: lualib-src/lua-clientwebsocket.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lpthread

#用于请求http, https
$(LUA_CLIB_PATH)/webclient.so: lualib-src/lua-webclient.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lcurl

#mt19937随机数
$(LUA_CLIB_PATH)/mt19937.so: lualib-src/mt19937-64/mt19937-64.c lualib-src/mt19937-64/lmt19937.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

#snowflake全局uuid生成器
$(LUA_CLIB_PATH)/snowflake.so: lualib-src/lua-snowflake.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@

#zlib
$(LUA_CLIB_PATH)/zlib.so: 3rd/lua-zlib/lua_zlib.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-zlib -L3rd/lua-zlib/src $^ -o $@ -lz

#cjson
$(LUA_CLIB_PATH)/cjson.so: | $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE) LUA_INCLUDE_DIR=../../$(LUA_INC) CC=$(CC) \
	CJSON_LDFLAGS="$(SHARED)" && cd ../.. && cp 3rd/lua-cjson/cjson.so $@

#unqlite
$(LUA_CLIB_PATH)/unqlite.so: 3rd/lua-unqlite/lua-unqlite.c 3rd/unqlite/unqlite.c | $(LUA_CLIB_PATH)
	$(CC) $(DEFS) $(CFLAGS) $(SHARED) -I3rd/unqlite $^ -o $@ $(LDFLAGS)

#lsqlite3
$(LUA_CLIB_PATH)/lsqlite3.so: 3rd/lua-sqlite3/lsqlite3.c 3rd/sqlite3/sqlite3.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-sqlite3 -I3rd/sqlite3  $^ -o $@ 

#httppack
$(LUA_CLIB_PATH)/httppack.so: lualib-src/lua-httppack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ 

$(LUA_CLIB_PATH)/add.so: lualib-src/add.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED)  $^ -o $@ 

#protobuf
$(LUA_CLIB_PATH)/protobuf.so :  3rd/lua-pbc/alloc.c 3rd/lua-pbc/array.c 3rd/lua-pbc/bootstrap.c \
	3rd/lua-pbc/context.c 3rd/lua-pbc/decode.c 3rd/lua-pbc/map.c 3rd/lua-pbc/pattern.c 3rd/lua-pbc/proto.c \
	3rd/lua-pbc/register.c 3rd/lua-pbc/rmessage.c 3rd/lua-pbc/stringpool.c 3rd/lua-pbc/varint.c \
	3rd/lua-pbc/wmessage.c 3rd/lua-pbc/pbc-lua.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-pbc $^ -o $@


clean :
	rm -f $(SKYNET_BUILD_PATH)/skynet $(CSERVICE_PATH)/* $(LUA_CLIB_PATH)/*

cleanall: clean
ifneq (,$(wildcard 3rd/jemalloc/Makefile))
	cd 3rd/jemalloc && $(MAKE) clean && rm Makefile
endif
	cd 3rd/lua && $(MAKE) clean
	rm -f $(LUA_STATICLIB)

