#Directories
BUILDDIR := $(shell pwd)
LUA_MOD_DIR = usr/local/share/lua/5.1
STAGE_DIR = opkg
M01_DIR = M01
WWW_DIR = usr/local/www/html

NET_LUA_PATH := './src/?.lua;../L001-507/src/?.lua'

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

test:
	busted -p 'lut$$' --suppress-pending -m './src/?.lua' $(BUSTED_OPTS) src

net:
	busted -p 'lnt$$' --suppress-pending -m $(NET_LUA_PATH) $(BUSTED_OPTS) src

pdf: all
	htmldoc -f rinApp.pdf --webpage --size universal --no-title --no-toc \
		--numbered --links --format pdf11 --book --color \
		`find opkg/usr/local/www/html/libdocs -type f -name '*.html'`

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
	
	cp -rp examples/* $(DEST_DIR)/home/lualib_examples
	find $(DEST_DIR)/home/lualib_examples -type d -exec chmod 775 {} \;
	find $(DEST_DIR)/home/lualib_examples -type f -exec chmod 755 {} \;
	
	$(MKDIR) $(DEST_DIR)/$(WWW_DIR)
	lua /usr/local/share/lua/5.1/ldoc.lua src --dir $(DEST_DIR)/$(WWW_DIR)/libdocs
	
	sed -i s/%LATEST%/$(PKGVERS)/g $(DEST_DIR)/$(LUA_MOD_DIR)/rinApp.lua

# Rule to create M01 release target
$(RELEASE_M01_TARGET): override DEST_DIR=$(BUILDDIR)/$(STAGE_DIR)
$(RELEASE_M01_TARGET): install
#Opkg it....
	$(MKDIR) $(M01_DIR)
	./opkg-build -O -o root -g root $(STAGE_DIR)
	mv $(PKGNAME)_$(PKGVERS)_$(PKGARCH).opk $(RELEASE_M01_TARGET)
