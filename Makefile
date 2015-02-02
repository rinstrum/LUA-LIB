#Directories
BUILDDIR := $(shell pwd)
export LUA_MOD_DIR = usr/local/share/lua/5.1
export STAGE_DIR = opkg
M01_DIR = M01
WWW_DIR = usr/local/www/html
DEST_DIR ?=$(BUILDDIR)/$(STAGE_DIR)

# Test hosts
#export UPPER_HOST := m4223testbox-upper.rinstrumau.local
#export UPPER_PORT := 2222
#export LOWER_HOST := m4223testbox-lower.rinstrumau.local
#export LOWER_PORT := 2222
#export TEST_USERNAME := root
#export TEST_PASSWORD := root

BASEDIR ?= $(shell pwd)/..
L001_507_DIR=$(BASEDIR)/L001-507
NET_LUA_PATH := "./src/?.lua;$(L001_507_DIR)/src/?.lua"
BUSTED_OPTS := --suppress-pending

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
PDF_M01_TARGET := $(M01_DIR)/$(PKGNAMEVERS)-M01.pdf
CHECKSUM_M01_TARGET := $(M01_DIR)/$(PKGNAMEVERS)-checksum
LDOCOUT := $(shell mktemp /tmp/$(PKGNAMEVERS)-XXXXXXXXX)

CHECKSUM_FILES := src/rinLibrary/checksum-file-list.lua
CHECKSUM_TEMP := $(CHECKSUM_FILES).new

.PHONY: clean install compile net pdf checksum $(RELEASE_M01_TARGET)

all: $(RELEASE_M01_TARGET)

clean:
	cd $(STAGE_DIR) && rm -rf `ls | grep -v CONTROL`
	rm -rf $(M01_DIR) $(CHECKSUM_FILES) $(CHECKSUM_TEMP)

compile: 
	luac -p $(shell find src -type f -name '*.lua')
	luac -p $(shell find examples -type f -name '*.lua')

unit test:
	busted -p 'lua$$' -m './src/?.lua' $(BUSTED_OPTS) tests/unit

net:
	./lock obtain
	-busted -p 'lua$$' -m $(NET_LUA_PATH) $(BUSTED_OPTS) tests/network
	./lock release

pdf: install
	$(MKDIR) $(M01_DIR)
	htmldoc -f $(PDF_M01_TARGET) --webpage --size universal --no-title --no-toc \
		--numbered --links --format pdf11 --book --color \
		`find opkg/usr/local/www/html/libdocs -type f -name '*.html'`

checksum: install
	$(MKDIR) $(M01_DIR)
	lua checksum.lua >$(CHECKSUM_M01_TARGET)

install: compile
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/IOSocket
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary/display
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinSockets
	$(MKDIR) $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinTimers
	$(MKDIR) $(DEST_DIR)/home/lualib_examples
	@rm -f $(CHECKSUM_FILES) $(CHECKSUM_TEMP)
	echo '--- Active file list.' >$(CHECKSUM_TEMP)
	@echo '--' >>$(CHECKSUM_TEMP)
	@echo '-- This file is automatically generated and should not be edited' >>$(CHECKSUM_TEMP)
	@echo '-- @module rinLibrary.checksum-file-list' >>$(CHECKSUM_TEMP)
	@echo 'return {' >>$(CHECKSUM_TEMP)
	@find src -name '*.lua' | sed -e 's:^src/:    ":' -e 's:[.]lua$$:",:'| sort >>$(CHECKSUM_TEMP)
	@echo '}' >>$(CHECKSUM_TEMP)
	mv $(CHECKSUM_TEMP) $(CHECKSUM_FILES)
	$(INSTALL_EXEC) src/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)
	$(INSTALL_EXEC) src/IOSocket/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/IOSocket
	$(INSTALL_EXEC) src/rinLibrary/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary	
	$(INSTALL_EXEC) src/rinLibrary/display/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinLibrary/display
	$(INSTALL_EXEC) src/rinSystem/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem
	$(INSTALL_EXEC) src/rinSystem/rinSockets/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinSockets
	$(INSTALL_EXEC) src/rinSystem/rinTimers/*.lua $(DEST_DIR)/$(LUA_MOD_DIR)/rinSystem/rinTimers
	
	cp -rp examples/* $(DEST_DIR)/home/lualib_examples
	find $(DEST_DIR)/home/lualib_examples -type d -exec chmod 775 {} \;
	find $(DEST_DIR)/home/lualib_examples -type f -exec chmod 755 {} \;
	
	$(MKDIR) $(DEST_DIR)/$(WWW_DIR)
	sed s/%LATEST%/$(PKGVERS)/g <src/config.ld.master >src/config.ld
	lua /usr/local/share/lua/5.1/ldoc.lua src $(LDOC_OPTS) --dir $(DEST_DIR)/$(WWW_DIR)/libdocs 2>$(LDOCOUT)
	@if [ -s $(LDOCOUT) ]; then echo Errors in LuaDoc; cat $(LDOCOUT); rm -f $(LDOCOUT); exit 1; fi
	@rm -f $(LDOCOUT)
	
	sed -i s/%LATEST%/$(PKGVERS)/g $(DEST_DIR)/$(LUA_MOD_DIR)/rinApp.lua

# Rule to create M01 release target
$(RELEASE_M01_TARGET): install checksum pdf
#Opkg it....
	$(MKDIR) $(M01_DIR)
	opkg-build -O -o root -g root $(STAGE_DIR)
	mv $(PKGNAME)_$(PKGVERS)_$(PKGARCH).opk $(RELEASE_M01_TARGET)

