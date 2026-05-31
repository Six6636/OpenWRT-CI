#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Six6636
# Fix missing files for luci-app-cupsd

echo "=========================================="
echo "Fixing luci-app-cupsd missing files..."
echo "=========================================="

# 查找 luci-app-cupsd 目录（先查当前目录，再查feeds）
CUPSD_DIR=$(find . ../feeds/ -maxdepth 3 -type d -name "luci-app-cupsd" 2>/dev/null | head -1)

if [ -z "$CUPSD_DIR" ]; then
    echo "[ERROR] luci-app-cupsd not found!"
    exit 1
fi

echo "[INFO] Found luci-app-cupsd at: $CUPSD_DIR"

# 创建缺失的目录结构
echo "[INFO] Creating directory structure..."
mkdir -p "$CUPSD_DIR/luasrc/controller"
mkdir -p "$CUPSD_DIR/luasrc/view/cupsd"
mkdir -p "$CUPSD_DIR/luasrc/model/cbi/cupsd"
mkdir -p "$CUPSD_DIR/root/etc/config"
mkdir -p "$CUPSD_DIR/root/etc/init.d"
mkdir -p "$CUPSD_DIR/root/usr/share/luci/menu.d"

# 1. 创建/更新 controller 文件（如果不存在或不完整）
if [ ! -f "$CUPSD_DIR/luasrc/controller/cupsd.lua" ]; then
    echo "[INFO] Creating controller file..."
    cat > "$CUPSD_DIR/luasrc/controller/cupsd.lua" << 'EOF'
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

# 2. 创建 view 文件（核心缺失文件）
if [ ! -f "$CUPSD_DIR/luasrc/view/cupsd/basic.htm" ]; then
    echo "[INFO] Creating view file..."
    cat > "$CUPSD_DIR/luasrc/view/cupsd/basic.htm" << 'EOF'
<%+header%>

<div class="container">
	<div class="panel panel-default">
		<div class="panel-heading">
			<h3 class="panel-title"><%:CUPS 打印服务器%></h3>
		</div>
		<div class="panel-body">
			<div id="content_cbi"></div>
		</div>
	</div>
</div>

<script type="text/javascript">
var cbi = new L.cbi.Map({
	config: '<%= mapconfig %>',
	pageTitle: '<%= self.title %>',
	description: '<%= self.description %>'
});
cbi.tabbed = <%= self.tab ~= false and 'true' or 'false' %>;
cbi.http_token = '<%= token %>';
var status = document.getElementById('maincontent');
status.appendChild(cbi.render());
</script>

<%+footer%>
EOF
fi

# 3. 创建 cbi 配置文件（如果不存在）
if [ ! -f "$CUPSD_DIR/luasrc/model/cbi/cupsd/basic.lua" ]; then
    echo "[INFO] Creating cbi model file..."
    cat > "$CUPSD_DIR/luasrc/model/cbi/cupsd/basic.lua" << 'EOF'
local sys = require "luci.sys"
local fs = require "nixio.fs"

m = Map("cupsd", translate("CUPS 打印服务器"), translate("Common UNIX Printing System"))
m.redirect = luci.dispatcher.build_url("admin/services/cupsd")

s = m:section(TypedSection, "cupsd", translate("Settings"))
s.addremove = false
s.anonymous = true

o = s:option(Flag, "enable", translate("Enable CUPS"))
o.rmempty = false
o.default = 1

o = s:option(Value, "port", translate("CUPS Port"))
o.datatype = "port"
o.default = 631
o.rmempty = false

return m
EOF
fi

# 4. 创建配置文件
if [ ! -f "$CUPSD_DIR/root/etc/config/cupsd" ]; then
    echo "[INFO] Creating config file..."
    cat > "$CUPSD_DIR/root/etc/config/cupsd" << 'EOF'
config cupsd
	option enable '1'
	option port '631'
EOF
fi

# 5. 创建初始化脚本
if [ ! -f "$CUPSD_DIR/root/etc/init.d/cupsd" ]; then
    echo "[INFO] Creating init script..."
    cat > "$CUPSD_DIR/root/etc/init.d/cupsd" << 'EOF'
#!/bin/sh /etc/rc.common

START=90
STOP=10

start() {
    /etc/init.d/cupsd start 2>/dev/null || true
}

stop() {
    /etc/init.d/cupsd stop 2>/dev/null || true
}

restart() {
    stop
    sleep 1
    start
}
EOF
    chmod +x "$CUPSD_DIR/root/etc/init.d/cupsd"
fi

# 6. 创建菜单文件
if [ ! -f "$CUPSD_DIR/root/usr/share/luci/menu.d/luci-app-cupsd.json" ]; then
    echo "[INFO] Creating menu file..."
    cat > "$CUPSD_DIR/root/usr/share/luci/menu.d/luci-app-cupsd.json" << 'EOF'
{
  "admin/services/cupsd": {
    "title": "CUPS",
    "order": 100,
    "action": "admin/services/cupsd",
    "depends": "luci-app-cupsd"
  }
}
EOF
fi

echo "[SUCCESS] luci-app-cupsd fix completed!"
echo "=========================================="
