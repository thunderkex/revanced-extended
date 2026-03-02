#!/system/bin/sh
{
	until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
	until [ -d "/sdcard/Android" ]; do sleep 1; done

	MODDIR=${0%/*}

	for app_dir in "$MODDIR/apps"/*/; do
		[ -f "$app_dir/config" ] || continue
		unset PKG_NAME
		. "$app_dir/config"
		rm -f "/data/adb/rvhc/${MODDIR##*/}-${PKG_NAME}.apk"
		rm -f "/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
	done

	rmdir "/data/adb/rvhc" 2>/dev/null || :
} &
