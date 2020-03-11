#!/usr/bin/env bash
clear

# print and exec command
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

# ./checker.sh -a
# echo
# echo

# filter only files that diff with origin/develop
FILESLIST=$(find . -type f | grep -e .adoc -e .html)
FILESLIST_COUNT=$(find . -type f | grep -e .adoc -e .html | wc -l)

function parse_config_file(){
    local line key val
    while IFS= read -r line; do
        read -r key <<< "${line%% *}"
        read -r val <<< "${line#* }"
        if [[ -z "$val" ]]; then
            continue
        else
           val=$(echo $val | tr -d '=' | tr -d '"' | tr -d ' ')
        fi
        case "$key" in
            anychart-version)
                ANYCHART_VERSION=${val};;

            locales-version)
                LOCALES_VERSION=${val};;

            geodata-version)
                GEODATA_VERSION=${val};;

            themes-version)
                THEMES_VERSION=${val};;
        esac
    done
}

run "parse_config_file < './config.toml'"

echo "ANYCHART_VERSION : '${ANYCHART_VERSION}'"
echo "LOCALES_VERSION : '${LOCALES_VERSION}'"
echo "GEODATA_VERSION : '${GEODATA_VERSION}'"
echo "THEMES_VERSION : '${THEMES_VERSION}'"
echo

# for each files in tree of folders do (like python walk)
nr=0
for filename in ${FILESLIST}; do
    (( ++nr ))
    # in diff mode file may be marked as deleted
    if [ -f $filename ];then
        # echo -ne "${nr} / ${FILESLIST_COUNT} > ${filename}                                              \r"
        perl -pi -e "s,(releases)/({{branch-name}})+/,\1/$ANYCHART_VERSION/,g" ${filename}
        perl -pi -e "s,(geodata)/([0-9]+\.[0-9]+\.[0-9]+)/,\1/$GEODATA_VERSION/,g" ${filename}
        perl -pi -e "s,(locales)/([0-9]+\.[0-9]+\.[0-9]+)/,\1/$LOCALES_VERSION/,g" ${filename}
        perl -pi -e "s,(themes)/([0-9]+\.[0-9]+\.[0-9]+)/,\1/$THEMES_VERSION/,g" ${filename}

    fi
done

# cause echo -ne previous
echo
