pub mod bundle;
pub mod single;
pub mod webui;

pub use bundle::build_bundle_module;
pub use single::build_single_module;

use anyhow::{Context, Result};
use tracing::info;

pub fn verify_bundle(zip_path: &str) -> Result<()> {
    let file = std::fs::File::open(zip_path)
        .with_context(|| format!("Failed to open module zip at {zip_path}"))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| "Failed to read zip archive")?;

    let mut has_update_binary = false;
    let mut has_updater_script = false;
    let mut has_module_prop = false;
    let mut has_customize_sh = false;
    let mut has_service_sh = false;
    let mut has_utils_sh = false;
    let mut apk_count = 0;

    for i in 0..archive.len() {
        let mut item = archive.by_index(i)?;
        let name = item.name().to_string();

        match name.as_str() {
            "META-INF/com/google/android/update-binary" => {
                if item.size() > 0 {
                    has_update_binary = true;
                }
            }
            "META-INF/com/google/android/updater-script" => {
                use std::io::Read;
                let mut content = String::new();
                item.read_to_string(&mut content)?;
                if content.contains("#MAGISK") {
                    has_updater_script = true;
                }
            }
            "module.prop" => {
                use std::io::Read;
                let mut content = String::new();
                item.read_to_string(&mut content)?;
                if content.contains("id=") && content.contains("name=") && content.contains("version=") {
                    has_module_prop = true;
                }
            }
            "customize.sh" => {
                if item.size() > 0 {
                    has_customize_sh = true;
                }
            }
            "service.sh" => {
                if item.size() > 0 {
                    has_service_sh = true;
                }
            }
            "utils.sh" => {
                if item.size() > 0 {
                    has_utils_sh = true;
                }
            }
            _ => {
                if name.starts_with("apks/") && name.ends_with(".apk") && item.size() > 50 {
                    apk_count += 1;
                }
            }
        }
    }

    if !has_update_binary {
        anyhow::bail!("Verification failed: missing or empty update-binary");
    }
    if !has_updater_script {
        anyhow::bail!("Verification failed: updater-script does not contain #MAGISK");
    }
    if !has_module_prop {
        anyhow::bail!("Verification failed: missing or invalid module.prop");
    }
    if !has_customize_sh {
        anyhow::bail!("Verification failed: missing or empty customize.sh");
    }
    if !has_service_sh {
        anyhow::bail!("Verification failed: missing or empty service.sh");
    }
    if !has_utils_sh {
        anyhow::bail!("Verification failed: missing or empty utils.sh");
    }
    if apk_count == 0 {
        anyhow::bail!("Verification failed: no valid APKs found under apks/");
    }

    info!("Magisk module verification passed! {apk_count} APKs bundled.");
    Ok(())
}

pub const UPDATE_BINARY: &[u8] = br#"#!/sbin/sh
SKIPUNZIP=1
unzip -o "$ZIPFILE" 'customize.sh' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'module.prop' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'utils.sh' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'service.sh' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'action.sh' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'uninstall.sh' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'apps.list' -d "$MODPATH" >/dev/null 2>&1
unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >/dev/null 2>&1
set_perm_recursive "$MODPATH" root root 0755 0644
"#;

pub const CUSTOMIZE_SH: &[u8] = br#"#!/system/bin/sh
# ReVanceX Module Installer
MODDIR="$MODPATH"
. "$MODPATH/utils.sh"

ui_print "****************************************"
ui_print "*           ReVanceX Module            *"
ui_print "*         Systemless Installer         *"
ui_print "****************************************"

mkdir -p /data/adb/rvex

# Extract all module files (scripts, prop, webroot, apks, apps.list)
unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >/dev/null 2>&1

set_perm_recursive "$MODPATH" 0 0 0755 0644
[ -d "$MODPATH/webroot" ] && set_perm_recursive "$MODPATH/webroot" 0 0 0755 0644
[ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
[ -f "$MODPATH/action.sh" ] && set_perm "$MODPATH/action.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
[ -f "$MODPATH/utils.sh" ] && set_perm "$MODPATH/utils.sh" 0 0 0755

if [ ! -f "$MODPATH/apps.list" ]; then
    for f in "$MODPATH"/apks/*.apk; do
        [ -f "$f" ] || continue
        name=$(basename "$f" .apk)
        echo "$name:$name:patch" >> "$MODPATH/apps.list"
    done
fi

while IFS=: read -r APP_ID PKG_NAME APP_MODE; do
    [ -z "$APP_ID" ] && continue
    [ "$APP_ID" = "microg" ] && continue

    APK_SRC="$MODPATH/apks/${APP_ID}.apk"
    [ ! -f "$APK_SRC" ] && APK_SRC=$(ls "$MODPATH"/apks/${APP_ID}*.apk 2>/dev/null | head -1)
    [ ! -f "$APK_SRC" ] && APK_SRC=$(ls "$MODPATH"/system/app/${APP_ID}*/*.apk 2>/dev/null | head -1)

    if [ ! -f "$APK_SRC" ]; then
        ui_print "! APK for $APP_ID not found in module"
        continue
    fi

    ui_print "* Processing $APP_ID ($PKG_NAME)..."

    # In root mount mode, clean up duplicate/incompatible standalone installations if present
    BASEPATH=$(get_basepath "$PKG_NAME")

    if [ "$APP_MODE" != "install" ]; then
        if [ -z "$BASEPATH" ] || [ ! -f "$BASEPATH" ]; then
            ui_print "  - Stock app not detected in system, installing base..."
            INSTALL_RES=$(pm install -r -d "$APK_SRC" 2>&1)
            if echo "$INSTALL_RES" | grep -q -e "INSTALL_FAILED_UPDATE_INCOMPATIBLE" -e "INSTALL_FAILED_SHARED_USER_INCOMPATIBLE" -e "INSTALL_FAILED_VERSION_DOWNGRADE"; then
                ui_print "  - Removing conflicting package signature..."
                pm uninstall "$PKG_NAME" >/dev/null 2>&1 || :
                pm install -r -d "$APK_SRC" >/dev/null 2>&1 || :
            fi
            BASEPATH=$(get_basepath "$PKG_NAME")
        fi

        if [ -n "$BASEPATH" ] && [ -f "$BASEPATH" ]; then
            RVPATH="/data/adb/rvex/${APP_ID}.apk"
            cp -f "$APK_SRC" "$RVPATH"
            chcon u:object_r:apk_data_file:s0 "$RVPATH" 2>/dev/null || :
            chmod 0644 "$RVPATH"

            umount_app "$PKG_NAME"
            mount -o bind "$RVPATH" "$BASEPATH" 2>/dev/null || :
            am force-stop "$PKG_NAME" 2>/dev/null || :
            ui_print "  - Replaced & mounted seamlessly over stock app"
        else
            ui_print "  - Note: Installed as standalone fallback"
        fi
    else
        pm install -r -d "$APK_SRC" >/dev/null 2>&1 || :
        ui_print "  - Standalone install complete."
    fi
done < "$MODPATH/apps.list"

ui_print "****************************************"
ui_print "* Installation complete! Enjoy!        *"
ui_print "****************************************"
"#;

pub const UTILS_SH: &[u8] = br#"#!/system/bin/sh
pmex() {
    OP=$(pm "$@" 2>&1 </dev/null)
    RET=$?
    echo "$OP"
    return $RET
}

get_app_version() {
    VERSION=$(dumpsys package "$1" 2>&1 | grep -m1 versionName=)
    VERSION="${VERSION#*=}"
    echo "$VERSION"
}

get_basepath() {
    BASEPATH=$(pm path "$1" 2>/dev/null | head -1 | sed 's/^package://' | tr -d '\r')
    echo "$BASEPATH"
    [ -n "$BASEPATH" ] && [ -f "$BASEPATH" ]
}

umount_app() {
    local pkg="$1"
    su -M -c grep -F "$pkg" /proc/mounts | while read -r line; do
        mp=$(echo "$line" | awk '{print $2}')
        su -M -c umount -l "${mp}" 2>/dev/null || :
    done
    am force-stop "$pkg" 2>/dev/null || :
}

mount_app_apk() {
    local app_id="$1"
    local pkg_name="$2"
    local apk_src="$3"

    local basepath
    basepath=$(get_basepath "$pkg_name")
    if [ -z "$basepath" ] || [ ! -f "$basepath" ]; then
        return 1
    fi

    local rvpath="/data/adb/rvex/${app_id}.apk"
    mkdir -p /data/adb/rvex
    cp -f "$apk_src" "$rvpath"
    chcon u:object_r:apk_data_file:s0 "$rvpath" 2>/dev/null || :
    chmod 0644 "$rvpath"

    umount_app "$pkg_name"
    mount -o bind "$rvpath" "$basepath" 2>/dev/null || :
    am force-stop "$pkg_name" 2>/dev/null || :
    return 0
}
"#;

pub const SERVICE_SH: &[u8] = br#"#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
export MODDIR
. "$MODDIR/utils.sh"

run() {
    until [ "$(getprop sys.boot_completed)" = "1" ]; do
        sleep 2
    done
    sleep 3

    [ -f "$MODDIR/disabled_by_action" ] && return 0

    if [ -f "$MODDIR/apps.list" ]; then
        while IFS=: read -r APP_ID PKG_NAME APP_MODE; do
            [ -z "$APP_ID" ] && continue
            [ "$APP_MODE" = "install" ] && continue

            BASEPATH=$(get_basepath "$PKG_NAME")
            RVPATH="/data/adb/rvex/${APP_ID}.apk"
            if [ -n "$BASEPATH" ] && [ -f "$BASEPATH" ] && [ -f "$RVPATH" ]; then
                chcon u:object_r:apk_data_file:s0 "$RVPATH" 2>/dev/null || :
                mount -o bind "$RVPATH" "$BASEPATH" 2>/dev/null || :
                am force-stop "$PKG_NAME" 2>/dev/null || :
            fi
        done < "$MODDIR/apps.list"
    fi

    if [ -f "$MODDIR/webui/server" ]; then
        "$MODDIR/webui/server" >/dev/null 2>&1 &
    fi
}

run &
"#;

pub const ACTION_SH: &[u8] = br#"#!/system/bin/sh
MODDIR="$(dirname "$(readlink -f "$0")")"
export MODDIR
. "$MODDIR/utils.sh"

echo ""
DFILE="$MODDIR/disabled_by_action"

if [ -f "$DFILE" ]; then
    rm -f "$DFILE"
    if [ -f "$MODDIR/apps.list" ]; then
        while IFS=: read -r APP_ID PKG_NAME APP_MODE; do
            [ -z "$APP_ID" ] && continue
            [ "$APP_MODE" = "install" ] && continue
            mount_app_apk "$APP_ID" "$PKG_NAME" "$MODDIR/apks/${APP_ID}.apk" || :
        done < "$MODDIR/apps.list"
    fi
    echo "* Apps mounted and enabled!"
else
    touch "$DFILE"
    if [ -f "$MODDIR/apps.list" ]; then
        while IFS=: read -r APP_ID PKG_NAME APP_MODE; do
            [ -z "$PKG_NAME" ] && continue
            umount_app "$PKG_NAME"
        done < "$MODDIR/apps.list"
    fi
    echo "* Apps unmounted and disabled!"
fi
"#;

pub const UNINSTALL_SH: &[u8] = br#"#!/system/bin/sh
MODDIR=${0%/*}

if [ -f "$MODDIR/apps.list" ]; then
    while IFS=: read -r APP_ID PKG_NAME APP_MODE; do
        [ -z "$PKG_NAME" ] && continue
        su -M -c grep -F "$PKG_NAME" /proc/mounts | while read -r line; do
            mp=$(echo "$line" | awk '{print $2}')
            su -M -c umount -l "$mp" 2>/dev/null || :
        done
        rm -f "/data/adb/rvex/${APP_ID}.apk"
    done < "$MODDIR/apps.list"
fi

rmdir /data/adb/rvex 2>/dev/null || :
"#;
