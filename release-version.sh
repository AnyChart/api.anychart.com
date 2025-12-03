#!/usr/bin/env bash
clear

# Helper: print the command, run it, and abort on failure so we never continue with broken state
function run(){
    echo ">$*"
    if eval "$@"; then
        echo [success]
    else
        echo [FAILED]
        exit 1
    fi
    echo
}

# Collect every *.adoc and *.html file once; mapfile keeps spaces/newlines safe
mapfile -t FILESLIST < <(find . -type f \( -iname '*.adoc' -o -iname '*.html' \))
FILESLIST_COUNT=${#FILESLIST[@]}

# Lightweight TOML reader: one awk pass extracts only the four version keys we care about
parse_config_file(){
    local v
    while read -r key v; do
        case "$key" in
            anychart-version)  ANYCHART_VERSION=$v;;  # core library version
            locales-version)   LOCALES_VERSION=$v;;   # i18n data version
            geodata-version)   GEODATA_VERSION=$v;;  # map geodata version
            themes-version)    THEMES_VERSION=$v;;   # bundled themes version
        esac
    done < <(awk -F'[ ="]+' '$1~/^(anychart|locales|geodata|themes)-version/{print $1,$(NF-1)}' config.toml)
}

run parse_config_file

# Sanity-check: show the versions we just parsed
echo "ANYCHART_VERSION : '${ANYCHART_VERSION}'"
echo "LOCALES_VERSION  : '${LOCALES_VERSION}'"
echo "GEODATA_VERSION  : '${GEODATA_VERSION}'"
echo "THEMES_VERSION   : '${THEMES_VERSION}'"
echo

# Build one Perl program string depending on the mode requested by caller
perl_code=""
# Mode 1: replace {{branch-name}} placeholder with actual AnyChart version
[[ $1 == "--branch" ]] &&
perl_code+="s,(releases)/(\\{\\{branch-name\\}\\})+/,\1/$ANYCHART_VERSION/,g;"
# Mode 2: bump hard-coded version numbers inside asset paths
[[ $1 == "--sources" ]] &&
perl_code+="s,(geodata)/([0-9]+\\.[0-9]+\\.[0-9]+)/,\1/$GEODATA_VERSION/,g;"\
"s,(locales)/([0-9]+\\.[0-9]+\\.[0-9]+)/,\1/$LOCALES_VERSION/,g;"\
"s,(themes)/([0-9]+\\.[0-9]+\\.[0-9]+)/,\1/$THEMES_VERSION/,g;"

# Optional verbose progress: second arg "-v" turns on counter
verbose=$([[ $2 == "-v" ]]&&echo 1||echo 0)

# --- timer start ---
start_time=$(date +%s)

# Iterate through every discovered file and apply the Perl substitution in-place
for ((nr=0; nr<FILESLIST_COUNT; nr++)); do
    f=${FILESLIST[nr]}
    [[ -f $f ]] || continue
    # If verbose mode is on, print an updating progress line:
    # \r  – carriage-return returns the cursor to the start of the line so the next print overwrites it
    # %d / %d – current file number vs total count
    # > %s    – the file path being processed right now
    ((verbose)) && printf "\r\e[K%d / %d > %s" $((nr+1)) $FILESLIST_COUNT "$f"
    [[ -n $perl_code ]] && perl -pi -e "$perl_code" "$f"
done
((verbose)) && echo

# --- timer stop & report ---
end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo "Finished in ${elapsed}s"
