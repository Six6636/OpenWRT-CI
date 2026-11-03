#!/bin/bash
# 私有扩展脚本：每次构建时在 Packages.sh 末尾自动执行

# 把插件的顶级菜单挂到 "服务" 下
# 只处理 "admin/xxx" 这种一级路径，已经是 admin/services/xxx 的不会被改第二次
move_to_services() {
	local DIR="$1"
	local F

	F=$(find "$DIR" -path '*/usr/share/luci/menu.d/*.json' 2>/dev/null | head -n1)
	if [ -z "$F" ]; then
		echo "move_to_services: $DIR 里没有 menu.d/*.json（可能是老式 Lua 插件）"
		return 0
	fi

	sed -i 's#"admin/\([^"/]*\)":#"admin/services/\1":#g' "$F"
	echo "move_to_services: 已处理 $F"
	grep -n '"admin/' "$F"
}

# 应用过滤 → 服务
move_to_services "./package/OpenAppFilter"
move_to_services "./package/nikki"
move_to_services "./package/tailscale"
