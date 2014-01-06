#Directories
BUILDDIR := $(shell pwd)
LUA_MOD_DIR = usr/local/share/lua/5.1
STAGE_DIR = opkg
M01_DIR = M01
WWW_DIR = usr/local/www/html

#Commands
MKDIR= mkdir -p
INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755
INSTALL_DATA= $(INSTALL) -m 0644

#Variables for opkg-ing
PKGNAME := $(shell sed -n -r "s/Package: (.*)/\1/p" < $(STAGE_DIR)/CONTROL/control)
PKGVERS := $(shell sed -n -r "s/Version: (.*)/\1/p" < $(STAGE_DIR)/CONTROL/control)
PKGARCH := $(shell sed -n -r "s/Architecture: (.*)/\1/p" < $(STAGE_DIR)/CONTROL/control)
PKGNAMEVERS=$(PKGNAME)-$(PKGVERS)
RELEASE_M01_TARGET = $(M01_DIR)/$(PKGNAMEVERS)-M01.opk

SRC_BASE = *.lua

SRC_LOC_BASE = src

.PHONY: clean install $(RELEASE_M01_TARGET)

all: $(RELEASE_M01_TARGET)

clean:
	cd $(STAGE_DIR) && rm -rf `ls | grep -v CONTROL`
	rm -rf $(M01_DIR)

install:
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/IOSocket
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinSockets
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinTimers
	$(MKDIR) $(DEST_DIR)/home/lualib_examples
	$(INSTALL_EXEC) src/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)
	$(INSTALL_EXEC) src/IOSocket/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/IOSocket
	$(INSTALL_EXEC) src/rinLibrary/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary	
	$(INSTALL_EXEC) src/rinSystem/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem
	$(INSTALL_EXEC) src/rinSystem/rinSockets/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinSockets
	$(INSTALL_EXEC) src/rinSystem/rinTimers/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinTimers
	$(INSTALL_EXEC) examples/*.lua $(DEST_DIR)/home/lualib_examples
	$(MKDIR) $(DEST_DIR)/$(WWW_DIR)
	lua /usr/local/share/lua/5.1/ldoc.lua src --dir $(DEST_DIR)/$(WWW_DIR)/libdocs

# Rule to create M01 release target
$(RELEASE_M01_TARGET): override DEST_DIR=$(BUILDDIR)/$(STAGE_DIR)
$(RELEASE_M01_TARGET): install
#Opkg it....
	$(MKDIR) $(M01_DIR)
	./opkg-build -O -o root -g root $(STAGE_DIR)
	mv $(PKGNAME)_$(PKGVERS)_$(PKGARCH).opk $(RELEASE_M01_TARGET)
