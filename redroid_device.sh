#!/system/bin/sh
cd "$(dirname "$0")"

magisk=`which magisk`
magiskhide=`which magiskhide`
logdir=/sdcard/.mitm-install
logfile=${logdir}/install.log

log() {
    line="$(date + '[%Y-%m-%dT%H:%M:%S %Z]') $@"
    echo "$line"
}

mkdir -p "$logdir"
touch "$logfile"
exec 1>>"$logfile" 2>>"$logfile"
tail -f "$logfile" &

if [ "$(id -u)" -ne 0 ]; then
    log '[shell] root required, re-run as root.'
    exit 1
fi

setup_magisk_app() {
    # initialize magisk application setup by completing final steps
    if [ -f "$logdir/setup_magisk_app" ]; then
        log '[script] setup_magisk_app already configured, skipping'
        return 0
    fi
    log '[magisk] final install steps initiating'
    am start io.github.huskydg.magisk/com.topjohnwu.magisk.ui.MainActivity || return 1
    # wait for pop-up to finish magisk install
    sleep 5
    input keyevent 80
    # tap OK
    input keyevent 61
    sleep 1
    input keyevent 61
    sleep 1
    input keyevent 61
    sleep 1
    input keyevent 23
    log '[magisk] rebooting redroid to complete install'
    touch $logdir/setup_magisk_app
}

setup_magisk_settings() {
    # root access for shell:
    if [ -f "$logdir/setup_magisk_settings" ]; then
        log '[script] setup_magisk_settings already configured, skipping'
        return 0
    fi
    shell_uid=$(id -u shell)
    log "Got $shell_uid for shell UID"
    "$magisk" --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES($shell_uid,2,0,1,1);" || return 1
    touch $logdir/setup_magisk_settings
}

do_settings() {
    # add global settings to avoid pop-ups and obstructions for input events
    if [ -f "$logdir/do_settings" ]; then
        log '[script] do_settings already configured, skipping'
        return 0
    fi
    settings put global policy_control 'immersive.navigation=*' || return 1
    settings put global policy_control 'immersive.full=*' || return 1
    settings put secure immersive_mode_confirmations confirmed || return 1
    settings put global heads_up_enabled 0 || return 1
    settings put global heads_up_notifications_enabled 0 || return 1
    settings put global bluetooth_disabled_profiles 1 || return 1
    settings put global bluetooth_on 0 || return 1
    settings put global package_verifier_user_consent -1 || return 1
    appops set com.android.vending POST_NOTIFICATION ignore || return 1
    appops set com.google.android.gms POST_NOTIFICATION ignore || return 1
    touch $logdir/do_settings
}

setup_magisk_denylist() {
    # add packages to denylist
    if [ -f "$logdir/setup_magisk_denylist" ]; then
        log '[script] setup_magisk_denylist already configured, skipping'
        return 0
    fi
    "$magisk" --sqlite "REPLACE INTO denylist (package_name,process) VALUES('com.android.vending','com.android.vending');" || return 1
    "$magisk" --sqlite "REPLACE INTO denylist (package_name,process) VALUES('com.google.android.gms','com.google.android.gms');" || return 1
    "$magisk" --sqlite "REPLACE INTO denylist (package_name,process) VALUES('com.google.android.gms.setup','com.google.android.gms.setup');" || return 1
    "$magisk" --sqlite "REPLACE INTO denylist (package_name,process) VALUES('com.google.android.gsf','com.google.android.gsf');" || return 1
    "$magisk" --sqlite "REPLACE INTO denylist (package_name,process) VALUES('com.nianticlabs.pokemongo','com.nianticlabs.pokemongo');" || return 1
    touch $logdir/setup_magisk_denylist
}

setup_magisksulist_app() {
    # enable magiskhide and sulist enforcement
    if [ -f "$logdir/setup_magisksulist_app" ]; then
        log '[script] setup_magisksulist_app already configured, skipping'
        return 0
    fi
    log '[magisk] magisk is nekkid, attempting to censor it'
    am start io.github.huskydg.magisk/com.topjohnwu.magisk.ui.MainActivity
    sleep 5
    input keyevent 80
    sleep 1
    input keyevent 61
    sleep 1
    input keyevent 61
    sleep 1
    input keyevent 23
    sleep 1
    # touch settings:
    input tap 624 56
    sleep 2
    # touch hide magiskhide
    for i in $(seq 1 12); do
      input keyevent 20
      sleep 1
    done
    input keyevent 23
    sleep 1
    # touch magisk sulist
    input keyevent 20
    sleep 1
    input keyevent 23
    sleep 1
    input keyevent HOME
    touch $logdir/setup_magisksulist_app
}

setup_exeggcute_policies() {
    # insert exeggcute into magisk policies for root
    if [ -f "$logdir/setup_exeggcute_policies" ]; then
        log '[script] setup_exeggcute_policies already configured, skipping'
        return 0
    fi
    exeggcute_uid=$(dumpsys package com.gocheats.launcher | grep userId= | awk -F= '{ print $2 }')
    if [ -n "$exeggcute_uid" ]; then
        "$magisk" --sqlite "REPLACE INTO policies (uid,policy,until,logging,notification) VALUES($exeggcute_uid,2,0,1,0);" || return 1
        log '[exeggcute] policy update complete!'
        touch $logdir/setup_exeggcute_policies
    else
        log '[exeggcute] policy update failed... package does not exist'
        return 1
    fi
}

setup_magisk_sulist() {
    # add exeggcute and shell to sulist enforcement
    if [ -f "$logdir/setup_magisk_sulist" ]; then
        log '[script] setup_magisk_sulist already configured, skipping'
        return 0
    fi
    "$magiskhide" add com.gocheats.launcher com.gocheats.launcher || return 1
    "$magiskhide" add com.android.shell com.android.shell || return 1
    touch $logdir/setup_magisk_sulist
}

repackage_magisk() {
    # repackage magisk to hide it's package name as a detection point
    if [ -f "$logdir/repackage_magisk" ]; then
        log '[script] repackage_magisk already configured, skipping'
        return 0
    fi
    ver=$(dumpsys package io.github.huskydg.magisk | grep versionName | sed -e 's/ //g' | awk -F= '{ print $2 }')
    if [ -n "$ver" ]; then
        log '[magisk] magisk is nekkid, attempting to censor it'
        output=$(am start io.github.huskydg.magisk/com.topjohnwu.magisk.ui.MainActivity 2>&1)
        echo $output
        sleep 10
        input keyevent 80
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 23
        sleep 2
        # touch settings:
        input tap 624 56
        sleep 2
        # touch hide magisk
        for i in $(seq 1 7); do
            input keyevent 20
            sleep 1
        done
        input keyevent 23
        sleep 2
        # Select 'Magisk' from 'install unknown apps sidebar'
        input keyevent 61
        sleep 1
        input keyevent 23
        sleep 1
        # back up
        input keyevent BACK
        sleep 1
        # Touch 'Hide the Magisk app' again
        input keyevent 61
        sleep 1
        input keyevent 23
        for i in $(seq 1 7); do
            input keyevent 20
            sleep 1
        done
        input keyevent 23
        sleep 2
        # Touch OK
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 23
        sleep 15
        # This will take a bit of time and the app will restart
        # and ask if you want shortcut on home screen.
        # Touch 'OK' to add shortcut.
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 23
        sleep 1
        # Tap 'add automatically'
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 61
        sleep 1
        input keyevent 23
        # that's it.
        sleep 1
        input keyevent HOME
        ver=$(dumpsys package io.github.huskydg.magisk | grep versionName | sed -e 's/ //g' | awk -F= '{ print $2 }')
        if [ -n "$ver" ]; then
            log '[magisk] repackage failed.'
            return 1
        else
            touch $logdir/repackage_magisk
        fi

    fi
}

# If no arguments are provided, run all functions
if [ $# -eq 0 ]; then
    main() {
        # check if setup has already been completed
        if [ -f "$logdir/mitm_setup_complete" ]; then
            log '[script] this device is already complete.'
            return 0
        fi
        setup_magisk_app || { log "Error setting up Magisk app"; exit 1; }
        setup_magisk_settings || { log "Error setting up Magisk settings"; exit 1; }
        do_settings || { log "Error doing settings"; exit 1; }
        setup_magisk_denylist || { log "Error setting up Magisk denylist"; exit 1; }
        setup_magisksulist_app || { log "Error setting up Magisk sulist"; exit 1; }
        setup_exeggcute_policies || { log "Error setting up exeggcute policies"; exit 1; }
        setup_magisk_sulist || { log "Error setting up Magisk sulist"; exit 1; }
        setup_exeggcute_perms || { log "Error setting up Magisk sulist"; exit 1; }
        touch $logdir/mitm_setup_complete
    }

    main

# If argument is provided, attempt to call the function with that name
else
    while [[ $# -gt 0 ]]; do
        "$1" || { log "Error running function '$1'"; exit 1; }
        shift
    done
fi
