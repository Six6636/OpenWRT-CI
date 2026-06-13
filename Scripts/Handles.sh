#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

PKG_PATH="$GITHUB_WORKSPACE/wrt/package/"

#预置HomeProxy数据
if [ -d *"homeproxy"* ]; then
	echo " "

	HP_RULE="surge"
	HP_PATH="homeproxy/root/etc/homeproxy"

	rm -rf ./$HP_PATH/resources/*

	git clone -q --depth=1 --single-branch --branch "release" "https://github.com/Loyalsoldier/surge-rules.git" ./$HP_RULE/
	cd ./$HP_RULE/ && RES_VER=$(git log -1 --pretty=format:'%s' | grep -o "[0-9]*")

	echo $RES_VER | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver
	awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt
	sed 's/^\.//g' direct.txt > china_list.txt ; sed 's/^\.//g' gfw.txt > gfw_list.txt
	mv -f ./{china_*,gfw_list}.{ver,txt} ../$HP_PATH/resources/

	cd .. && rm -rf ./$HP_RULE/

	cd $PKG_PATH && echo "homeproxy date has been updated!"
fi

#修改argon主题字体和颜色
if [ -d *"luci-theme-argon"* ]; then
	echo " " && cd ./luci-theme-argon/

	sed -i "s/primary '.*'/primary '#31a1a1'/; s/'0.2'/'0.5'/; s/'none'/'bing'/; s/'600'/'normal'/" ./luci-app-argon-config/root/etc/config/argon

	cd $PKG_PATH && echo "theme-argon has been fixed!"
fi

#修改aurora菜单式样
if [ -d *"luci-app-aurora-config"* ]; then
	echo " " && cd ./luci-app-aurora-config/

	sed -i "s/nav_submenu_type '.*'/nav_submenu_type 'boxed-dropdown'/g" $(find ./root/usr/share/aurora/ -type f -name "*.template")

	cd $PKG_PATH && echo "theme-aurora has been fixed!"
fi

#修改mini-diskmanager菜单位置
if [ -d *"luci-app-mini-diskmanager"* ]; then
	echo " " && cd ./luci-app-mini-diskmanager/

	sed -i "s/services/system/g" ./luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json

	cd $PKG_PATH && echo "mini-diskmanager has been fixed!"
fi

#修改cupsd菜单位置和标题 - 强制版本（确保文件存在）
if [ -d *"luci-app-cupsd"* ]; then
	echo " " && cd ./luci-app-cupsd/

	# 创建必要的目录结构
	mkdir -p ./luasrc/controller
	mkdir -p ./luasrc/model/cbi/cupsd
	mkdir -p ./root/usr/share/luci/menu.d
	mkdir -p ./root/etc/config
	mkdir -p ./root/etc/init.d

	# 1. 强制创建/更新菜单文件
	echo "[INFO] Creating/Updating CUPS menu file..."
	cat > ./root/usr/share/luci/menu.d/luci-app-cupsd.json << 'EOF'
{
  "admin/services/cupsd": {
    "title": "CUPS打印服务",
    "description": "CUPS打印服务管理",
    "order": 100,
    "action": "admin/services/cupsd",
    "depends": "luci-app-cupsd"
  }
}
EOF

	# 2. 强制创建/更新 controller 文件
	if [ ! -f "./luasrc/controller/cupsd.lua" ]; then
		echo "[INFO] Creating controller file..."
		cat > ./luasrc/controller/cupsd.lua << 'EOF'
-- Copyright (C) 2018 dz <dingzhong110@gmail.com>
-- mod by 2021-2022  sirpdboy  <herboy2008@gmail.com> https://github.com/sirpdboy/luci-app-cupsd

module("luci.controller.cupsd", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/cupsd") then
		return
	end

	local page = entry({"admin", "services", "cupsd"}, alias("admin", "services", "cupsd", "basic"), _("CUPS打印服务器"), 60)
	page.dependent = true
	page.acl_depends = { "luci-app-cupsd" }
	entry({"admin", "services", "cupsd", "basic"}, cbi("cupsd/basic"), _("设置"), 10).leaf = true

	entry({"admin", "services", "cupsd_status"}, call("act_status"))
end

function act_status()
	local sys  = require "luci.sys"
	local uci  = require "luci.model.uci".cursor()
	local port = tonumber(uci:get_first("cupsd", "cupsd", "port") )
	local e = { }
	e.running = sys.call("pidof cupsd > /dev/null") == 0
	e.port = port or 631
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end
EOF
	fi

	# 3. 强制创建/更新 CBI 模型文件
	if [ ! -f "./luasrc/model/cbi/cupsd/basic.lua" ]; then
		echo "[INFO] Creating CBI model file..."
		cat > ./luasrc/model/cbi/cupsd/basic.lua << 'EOF'
local sys = require "luci.sys"

m = Map("cupsd", translate("CUPS 打印服务器"), translate("Common UNIX Printing System"))
m.redirect = luci.dispatcher.build_url("admin/services/cupsd")

s = m:section(TypedSection, "cupsd", translate("设置"))
s.addremove = false
s.anonymous = true

o = s:option(Flag, "enable", translate("启用 CUPS"))
o.rmempty = false
o.default = 1

o = s:option(Value, "port", translate("CUPS 端口"))
o.datatype = "port"
o.default = 631
o.rmempty = false

return m
EOF
	fi

	# 4. 强制创建/更新配置文件
	if [ ! -f "./root/etc/config/cupsd" ]; then
		echo "[INFO] Creating config file..."
		cat > ./root/etc/config/cupsd << 'EOF'
config cupsd
	option enable '1'
	option port '631'
EOF
	fi

	cd $PKG_PATH && echo "luci-app-cupsd has been fixed!"
fi

#修改qca-nss-drv启动顺序
NSS_DRV="../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init"
if [ -f "$NSS_DRV" ]; then
	echo " "

	sed -i 's/START=.*/START=85/g' $NSS_DRV

	cd $PKG_PATH && echo "qca-nss-drv has been fixed!"
fi

#修改qca-nss-pbuf启动顺序
NSS_PBUF="./kernel/mac80211/files/qca-nss-pbuf.init"
if [ -f "$NSS_PBUF" ]; then
	echo " "

	sed -i 's/START=.*/START=86/g' $NSS_PBUF

	cd $PKG_PATH && echo "qca-nss-pbuf has been fixed!"
fi

#修复TailScale配置文件冲突
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile")
if [ -f "$TS_FILE" ]; then
	echo " "

	sed -i '/\/files/d' $TS_FILE

	cd $PKG_PATH && echo "tailscale has been fixed!"
fi

#修复Rust编译失败
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile")
if [ -f "$RUST_FILE" ]; then
	echo " "

	sed -i 's/ci-llvm=true/ci-llvm=false/g' $RUST_FILE

	cd $PKG_PATH && echo "rust has been fixed!"
fi
