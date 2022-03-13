#!/bin/sh

set -euo pipefail

proton_ver="6.21-GE-2"
dxvk_ver="1.10"
wine_pkgs=(dotnet48 vcrun2019)

proton_name="Proton-$proton_ver"
dxvk_name="dxvk-$dxvk_ver"
dir=$(dirname "$0")
curdir="$(cd "$dir" && pwd -P)"
steam_path="$HOME/.local/share/Steam/steamapps/compatdata/0/pfx/drive_c/Program Files (x86)/Steam"

export WINE="$curdir/$proton_name/files/bin/wine"
export WINEPREFIX="$curdir/prefix"
export WINEARCH=win64
export PATH="$curdir/$proton_name/files/bin:$PATH"
export XL_WINEONLINUX=true
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH=$WINEPREFIX

steam_link="$WINEPREFIX/drive_c/Program Files (x86)/Steam"

usage(){ cat <<EOF
Usage: $0 [options] command
Run FFXIV for Steam on Linux.

Commands:
  info         Show
  install      Install XIVLauncher and required software into Wine
  run          Run XIVLauncher from Wine

Options:
  -H string    Set DXVK_HUD variable
  -F int       Set DXVK_FRAME_RATE variable
  -M 0|1       Set MANGOHUD variable
  -k           Keep files after install
EOF
}

info(){
    [ -f "$WINE" ] && ws="present" || ws="missing"
    if [ -d "$WINEPREFIX" ]; then
        [ -f "$WINEPREFIX/system.reg" ] && wps="present" || wps="invalid"
    else wps="missing"; fi
    [ -L "$steam_link" ] && sls="present" || sls="missing"
    dxvk_cfg=${DXVK_CONFIG_FILE:-$curdir/game/dxvk.conf}
    [ -f "$dxvk_cfg" ] && dcs="present" || dcs="missing"
    cat <<EOF
--- Environment Variables
DXVK_FRAME_RATE:  ${DXVK_FRAME_RATE:-[not set]}
DXVK_HUD:         ${DXVK_HUD:-[not set]}
MANGOHUD:         ${MANGOHUD:-[not set]}

--- Paths
Wine executable:  [$ws] $WINE
Wine prefix:      [$wps] $WINEPREFIX
Steam symlink:    [$sls] $steam_link
EOF
# DXVK config: [missing] may be inferred as an issue requiring fixing, hide
# unless there's a reasonable cause to show.
([ -n "${DXVK_CONFIG_FILE+x}" ] || [ -f "$dxvk_cfg" ]) && echo "DXVK config:      [$dcs] $dxvk_cfg"
}

setup_dxvk(){
    [ -f "$dxvk_name/setup_dzvk.sh" ] || curl -L https://github.com/doitsujin/dxvk/releases/download/v$dxvk_ver/$dxvk_name.tar.gz | tar xz
    patch $dxvk_name/setup_dxvk.sh <<'EOF'
--- dxvk-1.10/setup_dxvk.sh    2022-03-04 17:22:12.000000000 +0100
+++ dxvk-1.10_/setup_dxvk.sh    2022-03-09 20:02:32.028057943 +0100
@@ -64,7 +64,7 @@
 # Pure 64-bit Wine (non Wow64) requries skipping 32-bit steps.
 # In such case, wine64 and winebooot will be present, but wine binary will be missing,
 # however it can be present in other PATHs, so it shouldn't be used, to avoid versions mixing.
-wine_path=$(dirname "$(which $wineboot)")
+wine_path=$(dirname "$(which $wine)")
 wow64=true
 if ! [ -f "$wine_path/$wine" ]; then
    wine=$wine64
@@ -80,7 +80,7 @@

 # ensure wine placeholder dlls are recreated
 # if they are missing
-$wineboot -u
+# $wineboot -u

 win64_sys_path=$($wine64 winepath -u 'C:\windows\system32' 2> /dev/null)
 win64_sys_path="${win64_sys_path/$'\r'/}"
EOF
    cd $dxvk_name
    ./setup_dxvk.sh install
    cd $curdir
    ${keep_files:-false} || rm -r $dxvk_name
}

check_prereqs(){
    if [ -d "$WINEPREFIX" ]; then echo "Wine prefix already exists"
    elif ! [ -d "$steam_path" ]; then echo "Failed to locate Proton Steam"
    elif ! which winetricks; then :
    elif ! which curl; then :
    else return 0; fi
    echo "Errors reported, aborting"
    return 1
}

install(){
    check_prereqs || exit 1
    cd "$curdir"
    curl -L "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$proton_ver/$proton_name.tar.gz" | tar xz
    for pkg in ${wine_pkgs[*]}; do
        winetricks -q $pkg || echo "Failed to install $pkg, please review output above"
    done
    echo "Installing DXVK into Wine prefix.."
    setup_dxvk
    echo "Creating Steam symlink in Wine prefix.."
    ln -s "$steam_path" "$steam_link"
    echo "Disabling startup cutscenes.."
    mygames_ffxiv="drive_c/users/steamuser/Documents/My Games/FINAL FANTASY XIV - A Realm Reborn/"
    mkdir -p "$WINEPREFIX/$mygames_ffxiv"
    echo -e "<FINAL FANTASY XIV Config File>\n\n<Cutscene Settings>\nCutsceneMovieOpening 1" > "$WINEPREFIX/$mygames_ffxiv/FFXIV.cfg"
    echo -e "<FINAL FANTASY XIV Boot Config File>\n\n<Version>\nBrowser 1\nStartupCompleted    1" > "$WINEPREFIX/$mygames_ffxiv/FFXIV_BOOT.cfg"
    # XIVLauncher
    echo "Installing XIVLauncher into Wine prefix.."
    [ -f Setup.exe ] || curl -LO https://kamori.goats.dev/Proxy/Update/Release/Setup.exe
    "$WINE" Setup.exe
    ${keep_files:-false} || rm Setup.exe
}

run(){
    [ -f "$WINEPREFIX/system.reg" ] || (echo "Missing or invalid Wine prefix" ; exit 1)
    "$WINE" "$WINEPREFIX/drive_c/users/steamuser/AppData/Local/XIVLauncher/XIVLauncher.exe"
}

while getopts "H:F:M:k" o; do case "${o}" in
    H) export DXVK_HUD="$OPTARG" ;;
    F) export DXVK_FRAME_RATE="$OPTARG" ;;
    M) export MANGOHUD="$OPTARG" ;;
    k) keep_files=true ;;
    *) usage; exit 1 ;;
esac done

shift "$(( OPTIND - 1 ))"

cmd="${1:-x}"
case "${cmd:-x}" in
    info) info ;;
    install) install ;;
    run) run ;;
    *) usage; exit 1 ;;
esac
