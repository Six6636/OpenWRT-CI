#!/bin/bash
# 私有扩展脚本：在 Packages.sh 末尾自动执行

# 把插件的顶级菜单挂到 "服务" 下，可选改标题
# 用法: move_menu_to_services <源码目录> ["新标题"]
move_menu_to_services() {
	local DIR="$1"
	local TITLE="$2"
	local FOUND=0 F

	while IFS= read -r F; do
		[ -z "$F" ] && continue
		FOUND=1

		# 只改一层路径：admin/xxx → admin/services/xxx
		sed -i 's#"admin/\([^"/]*\)":#"admin/services/\1":#g' "$F"

		# 只改文件里第一个 title，避免误改分组标题
		if [ -n "$TITLE" ]; then
			sed -i "0,/\"title\": *\"[^\"]*\"/s//\"title\": \"$TITLE\"/" "$F"
		fi

		echo "menu -> services: $F"
		grep -n '"admin/' "$F"
	done < <(find "$DIR" -path '*/usr/share/luci/menu.d/*.json' 2>/dev/null)

	[ "$FOUND" = "1" ] || echo "skip: $DIR 里没有 menu.d/*.json（可能是老式 Lua 插件）"
}

move_menu_to_services "./package/OpenAppFilter"      "应用过滤"
move_menu_to_services "./package/OpenWrt-nikki"      "Nikki"
move_menu_to_services "./package/luci-app-tailscale" "Tailscale"
