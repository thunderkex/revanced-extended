#!/system/bin/sh
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
