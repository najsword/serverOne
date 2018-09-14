# Top level makefile, the real shit is at src/Makefile
all: skynet/skynet redis/redis-server lsocket

skynet/skynet:
    #yum install dos2unix; yum install libcurl-dev libcurl-devel
	cd skynet && $(MAKE) linux

JEMALLOC_STATICLIB := redis/deps/jemalloc/lib/libjemalloc_pic.a
REDIS_SERVER := redis/src/redis-server

redis/redis-server: | $(REDIS_SERVER)
	cp $(REDIS_SERVER) redis/

$(REDIS_SERVER): | $(JEMALLOC_STATICLIB)
	cd redis && $(MAKE)

$(JEMALLOC_STATICLIB): redis/deps/jemalloc/Makefile
	cd redis/deps/jemalloc && $(MAKE) CC=$(CC) 

lsocket:
	cd lsocket && $(MAKE) LUA_INCLUDE=../skynet/3rd/lua

redis/deps/jemalloc/Makefile:
	cd redis/deps/jemalloc && find ./ -name "*.sh" | xargs chmod +x && ./autogen.sh --with-jemalloc-prefix=je_ --disable-valgrind