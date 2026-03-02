#!/system/bin/sh
MODDIR=${0%/*}

err() {
	[ ! -f "$MODDIR/err" ] && cp "$MODDIR/module.prop" "$MODDIR/err"
	sed -i "s/^des.*/description=⚠️ Needs reflash: '${1}'/g" "$MODDIR/module.prop"
}

until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 1; done
until [ -d "/sdcard/Android" ]; do sleep 1; done
while
	pm list packages >/dev/null 2>&1
	PMRET=$?
	[ $PMRET = 20 ]
do sleep 2; done

mount_app() {
	local APP_DIR="$1"
	unset PKG_NAME PKG_VER MODULE_ARCH
	. "$APP_DIR/config"

	local RVPATH=/data/adb/rvhc/${MODDIR##*/}-${PKG_NAME}.apk

	if [ ! -f "$RVPATH" ]; then
		err "$PKG_NAME apk not found"
		return
	fi

	local BASEPATH
	BASEPATH=$(pm path "$PKG_NAME" 2>&1 </dev/null)
	local SVCL=$?

	if [ $SVCL != 0 ]; then
		err "$PKG_NAME not installed"
		return
	fi

	sleep 4

	BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}

	if [ ! -d "$BASEPATH/lib" ]; then
		err "$PKG_NAME mount failed (ROM issue)"
		return
	fi

	local VERSION
	VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName)
	VERSION="${VERSION#*=}"
	if [ "$VERSION" != "$PKG_VER" ] && [ "$VERSION" ]; then
		err "$PKG_NAME version mismatch (installed:${VERSION}, module:$PKG_VER)"
		return
	fi

	grep "$PKG_NAME" /proc/mounts | while read -r line; do
		local mp=${line#* }; mp=${mp%% *}
		umount -l "${mp%%\\*}"
	done

	if ! chcon u:object_r:apk_data_file:s0 "$RVPATH"; then
		err "$PKG_NAME apk SELinux label failed"
		return
	fi

	mount -o bind "$RVPATH" "$BASEPATH/base.apk"
	am force-stop "$PKG_NAME"
}

run_all() {
	for app_dir in "$MODDIR/apps"/*/; do
		[ -f "$app_dir/config" ] || continue
		mount_app "$app_dir" &
	done
	wait
	[ -f "$MODDIR/err" ] && mv -f "$MODDIR/err" "$MODDIR/module.prop"
}

run_all
