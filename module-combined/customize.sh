ui_print ""
ui_print "* RevPack Installer"
ui_print "  by Thunderkex"
ui_print ""

# Vol+ = Yes (return 0), Vol- = No (return 1), timeout = Yes (return 0)
_choose() {
	local KEY TIMEOUT=5
	KEY=$(timeout "$TIMEOUT" getevent -lc 16 2>/dev/null | awk '/EV_KEY.*KEY_VOLUME.*DOWN/{print $3; exit}')
	case "$KEY" in
		KEY_VOLUMEUP) return 0 ;;
		KEY_VOLUMEDOWN) return 1 ;;
		*)
			ui_print "  Timeout reached, defaulting to Yes"
			return 0 ;;
	esac
}

if [ "$ARCH" = "arm" ]; then
	ARCH_LIB=armeabi-v7a
elif [ "$ARCH" = "arm64" ]; then
	ARCH_LIB=arm64-v8a
elif [ "$ARCH" = "x86" ]; then
	ARCH_LIB=x86
elif [ "$ARCH" = "x64" ]; then
	ARCH_LIB=x86_64
else abort "ERROR: unsupported arch: ${ARCH}"; fi

set_perm_recursive "$MODPATH/bin" 0 0 0755 0777

if su -M -c true >/dev/null 2>/dev/null; then
	alias mm='su -M -c'
else alias mm='nsenter -t1 -m'; fi

pmex() {
	OP=$(pm "$@" 2>&1 </dev/null)
	RET=$?
	echo "$OP"
	return $RET
}

install_app() {
	local APP_DIR="$1"
	unset PKG_NAME PKG_VER MODULE_ARCH
	. "$APP_DIR/config"

	if [ -n "$MODULE_ARCH" ] && [ "$MODULE_ARCH" != "$ARCH" ]; then
		ui_print "* Skipping $PKG_NAME (arch mismatch: module=$MODULE_ARCH device=$ARCH)"
		return 0
	fi

	ui_print ""
	ui_print "---------------------------------------"
	ui_print "* $PKG_NAME  v$PKG_VER"
	ui_print "  Install this app? (auto-yes in 5s)"
	ui_print "  Vol+ = Yes  |  Vol- = No"
	if ! _choose; then
		ui_print "* Skipped by user: $PKG_NAME"
		return 0
	fi
	ui_print "* Installing $PKG_NAME..."

	local RVPATH=/data/adb/rvhc/${MODPATH##*/}-${PKG_NAME}.apk
	local BASEPATH INS IS_SYS

	mm grep -F "$PKG_NAME" /proc/mounts | while read -r line; do
		ui_print "* Un-mount $PKG_NAME"
		local mp=${line#* }; mp=${mp%% *}
		mm umount -l "${mp%%\\*}"
	done
	am force-stop "$PKG_NAME"

	if ! pmex path "$PKG_NAME" >&2; then
		if pmex install-existing "$PKG_NAME" >&2; then
			pmex uninstall-system-updates "$PKG_NAME"
		fi
	fi

	IS_SYS=false
	INS=true
	if BASEPATH=$(pmex path "$PKG_NAME"); then
		echo >&2 "'$BASEPATH'"
		BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
		if [ "${BASEPATH:1:4}" != data ]; then
			ui_print "* $PKG_NAME is a system app."
			IS_SYS=true
		elif [ ! -f "$APP_DIR/$PKG_NAME.apk" ]; then
			ui_print "* Stock $PKG_NAME APK was not found"
			local VERSION
			VERSION=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 versionName)
			VERSION="${VERSION#*=}"
			if [ "$VERSION" = "$PKG_VER" ] || [ -z "$VERSION" ]; then
				ui_print "* Skipping stock installation"
				INS=false
			else
				abort "ERROR: Version mismatch
			installed: $VERSION
			module:    $PKG_VER
			"
			fi
		elif "${MODPATH:?}/bin/$ARCH/cmpr" "$BASEPATH/base.apk" "$APP_DIR/$PKG_NAME.apk"; then
			ui_print "* $PKG_NAME is up-to-date"
			INS=false
		fi
	fi

	_install_pkg() {
		if [ ! -f "$APP_DIR/$PKG_NAME.apk" ]; then
			abort "ERROR: Stock $PKG_NAME apk was not found"
		fi
		ui_print "* Updating $PKG_NAME to $PKG_VER"
		local install_err=""
		local VERIF1 VERIF2
		VERIF1=$(settings get global verifier_verify_adb_installs)
		VERIF2=$(settings get global package_verifier_enable)
		settings put global verifier_verify_adb_installs 0
		settings put global package_verifier_enable 0
		local SZ SES op
		SZ=$(stat -c "%s" "$APP_DIR/$PKG_NAME.apk")
		for IT in 1 2; do
			if ! SES=$(pmex install-create --user 0 -i com.android.vending -r -d -S "$SZ"); then
				ui_print "ERROR: install-create failed"
				install_err="$SES"
				break
			fi
			SES=${SES#*[} SES=${SES%]*}
			set_perm "$APP_DIR/$PKG_NAME.apk" 1000 1000 644 u:object_r:apk_data_file:s0
			if ! op=$(pmex install-write -S "$SZ" "$SES" "$PKG_NAME.apk" "$APP_DIR/$PKG_NAME.apk"); then
				ui_print "ERROR: install-write failed"
				install_err="$op"
				break
			fi
			if ! op=$(pmex install-commit "$SES"); then
				echo >&2 "$op"
				if echo "$op" | grep -q -e INSTALL_FAILED_VERSION_DOWNGRADE -e INSTALL_FAILED_UPDATE_INCOMPATIBLE; then
					ui_print "* Handling install error"
					pmex uninstall-system-updates "$PKG_NAME"
					BASEPATH=$(pmex path "$PKG_NAME") || abort
					BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
					if [ "${BASEPATH:1:4}" != data ]; then IS_SYS=true; fi
					if [ "$IS_SYS" = true ]; then
						local SCNM="/data/adb/post-fs-data.d/$PKG_NAME-uninstall.sh"
						if [ -f "$SCNM" ]; then
							ui_print "* Remove the old module. Reboot and reflash!"
							ui_print ""
							install_err=" "
							break
						fi
						mkdir -p /data/adb/rvhc/empty /data/adb/post-fs-data.d
						echo "mount -o bind /data/adb/rvhc/empty $BASEPATH" >"$SCNM"
						chmod +x "$SCNM"
						ui_print "* Created the uninstall script."
						ui_print ""
						ui_print "* Reboot and reflash the module!"
						install_err=" "
						break
					else
						ui_print "* Uninstalling..."
						if ! op=$(pmex uninstall -k --user 0 "$PKG_NAME"); then
							ui_print "$op"
							if [ "$IT" = 2 ]; then
								install_err="ERROR: pm uninstall failed."
								break
							fi
						fi
						continue
					fi
				fi
				ui_print "ERROR: install-commit failed"
				install_err="$op"
				break
			fi
			if BASEPATH=$(pmex path "$PKG_NAME"); then
				BASEPATH=${BASEPATH##*:} BASEPATH=${BASEPATH%/*}
			else
				install_err="ERROR: install $PKG_NAME manually and reflash the module"
				break
			fi
			break
		done
		settings put global verifier_verify_adb_installs "$VERIF1"
		settings put global package_verifier_enable "$VERIF2"
		if [ "$install_err" ]; then abort "$install_err"; fi
	}

	if [ "$INS" = true ] && ! _install_pkg; then abort; fi

	local BASEPATHLIB=${BASEPATH}/lib/${ARCH}
	if [ "$INS" = true ] || [ -z "$(ls -A1 "$BASEPATHLIB")" ]; then
		ui_print "* Extracting native libs for $PKG_NAME"
		if [ ! -d "$BASEPATHLIB" ]; then mkdir -p "$BASEPATHLIB"; else rm -f "$BASEPATHLIB"/* >/dev/null 2>&1 || :; fi
		if ! op=$(unzip -o -j "$APP_DIR/$PKG_NAME.apk" "lib/${ARCH_LIB}/*" -d "$BASEPATHLIB" 2>&1); then
			ui_print "WARNING: extracting native libs failed for $PKG_NAME"
		else
			set_perm_recursive "${BASEPATH}/lib" 1000 1000 755 755 u:object_r:apk_data_file:s0
		fi
	fi

	ui_print "* Setting permissions for $PKG_NAME"
	set_perm "$APP_DIR/base.apk" 1000 1000 644 u:object_r:apk_data_file:s0

	ui_print "* Mounting $PKG_NAME"
	mkdir -p /data/adb/rvhc
	mv -f "$APP_DIR/base.apk" "$RVPATH"

	if ! op=$(mm mount -o bind "$RVPATH" "$BASEPATH/base.apk" 2>&1); then
		ui_print "ERROR: Mount failed for $PKG_NAME!"
		ui_print "$op"
	fi
	am force-stop "$PKG_NAME"
	ui_print "* Optimizing $PKG_NAME"
	cmd package compile -m speed-profile -f "$PKG_NAME"

	if [ "${KSU:-}" ]; then
		local UID
		UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 uid)
		UID=${UID#*=} UID=${UID%% *}
		if [ -z "$UID" ]; then
			UID=$(dumpsys package "$PKG_NAME" 2>&1 | grep -m1 userId)
			UID=${UID#*=} UID=${UID%% *}
		fi
		if [ "$UID" ]; then
			if ! OP=$("${MODPATH:?}/bin/$ARCH/ksu_profile" "$UID" "$PKG_NAME" 2>&1); then
				ui_print "  $OP"
				ui_print "* Because you are using a fork of KernelSU,"
				ui_print "  go to your root manager and disable"
				ui_print "  'Unmount modules' for $PKG_NAME"
			fi
		else
			ui_print "WARNING: UID could not be found for $PKG_NAME"
		fi
	fi

	rm -f "$APP_DIR/$PKG_NAME.apk"
	ui_print "* Done: $PKG_NAME"
}

APP_COUNT=0
for app_dir in "$MODPATH/apps"/*/; do
	[ -f "$app_dir/config" ] || continue
	APP_COUNT=$((APP_COUNT + 1))
done
ui_print "* Found $APP_COUNT app(s) to install"

for app_dir in "$MODPATH/apps"/*/; do
	[ -f "$app_dir/config" ] || continue
	install_app "$app_dir"
done

rm -rf "${MODPATH:?}/bin"
ui_print ""
ui_print "* All apps installed!"
ui_print "  by thunderkex"
ui_print " "
