#!/usr/bin/env bash
clear
########################################################################################################################
#
#  Utility function to fix known troubles with production server
#
#  You can run this command with parameters
#
########################################################################################################################

# install pre-push hook if it not exists
hook='.git/hooks/pre-push'
if [ ! -f ${hook} ]; then
   echo 'Install pre-push hook'
   touch ${hook}
   echo '#!/bin/bash' >> ${hook}
   echo 'if [ $(git symbolic-ref HEAD | sed -e "s,.*/\(.*\),\1,") = "develop" ] && [[ ! $(git log -1 --pretty=%B) =~ "#without-check" ]] ' >> ${hook}
   echo 'then  . ./checker.sh; fi' >> ${hook}
   chmod +x ${hook}
   echo 'done'
fi

########################################################################################################################
#   Define default variables
########################################################################################################################
CURRENT_BRANCH=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/');

# IGNORE files
declare -a IGNOREFILES=(
    "./format/_samples/anychart.format.locales_custom.html" 
    "./format/_samples/anychart.format.getMessage.html"
    )

# filter only files that diff with origin/develop
FILESLIST=$(git diff --name-only origin/develop | grep -e .html -e .adoc )

# function for "fix" file.
function heal_file(){
    filename=$1
    # replace all STG url on COM and  non-{{branch-name}}
    perl -pi -e 's/\.stg/\.com/g' ${filename}
    perl -pi -e 's,(releases)/([^/])+/,\1/{{branch-name}}/,g' ${filename}

    if [[ ! " ${IGNOREFILES[*]} " == *"$filename"* ]]; then
        # match all non-ascii symbols
        # Search charcode by symbol here  https://www.compart.com/en/unicode/search?q=
        # Search symbol by hex code here https://utf8-chartable.de/unicode-utf8-table.pl?start=8192&number=128&utf8=string-literal
        match=$(cat ${filename} | tr -d '\r' | tr -d '\n' | sed 's/\xC2\xA0/+/g' | \
            sed -e "s/'//g;s/[\s\t]/ /g" | sed -e 's/[0-9A-z"*+-=()/&!?.,:;$<>#{}%~|@ ]//g' | \
            awk '{$1=$1}1' )
        if [ ! ${#match} -eq 0 ]; then
            res=""
            for i in $(seq 1 ${#match});do
                char=${match:i-1:1}
                res="$res $char($(echo ${char} | tr -d '\n' | xxd -u -p | sed 's/\(..\)/\\x\1/g' ))"
            done
            echo "[Non-ASCII] $filename: $res"
            # echo ${match:0:1} | tr -d '\n' | xxd -ps -c 200
        fi
    fi
}
# default mode
FILE_MODIFYER="heal_file"

# sugar function
function broke_file(){
    FILENAME=$1
    perl -pi -e "s,(releases)/({{branch-name}})+/,\1/$CURRENT_BRANCH/,g" ${FILENAME}
}

########################################################################################################################
#   Main functioonality
########################################################################################################################

# read command arguments
for ARGUMENT in "$@"
do
    case "$ARGUMENT" in
            replace|r|"-r")    FILE_MODIFYER="broke_file" ;;
            all|a|"-a")        FILESLIST=$(find . -type f -name "*.html") ;;
            "-h"|"--help"|help|h|"-help")  printf "parameters: \
                \n 'replace (-r)' - to rename all {{branch-name}} to current branch\
                \n 'all (-a)' - modify all files (by default False, modify only diff with origin/develop)\
                \n 'links (-l)' - get links to pg and github.com for changed samples\
                \n" && exit 1 ;;
            links|link|l|"-l")
                for filename in ${FILESLIST}; do
                    fileext=${filename:${#filename}-4}

                    if [[ "$fileext" = "html" ]]; then
                        pglink="http://playground.anychart.stg/api/$CURRENT_BRANCH/${filename:0:${#filename}-5}\n\t"
                    fi

                    printf "\n*$filename*\n\t${pglink}https://github.com/AnyChart/api.anychart.com/blob/$CURRENT_BRANCH/$filename\n"
                done
                exit 0
                ;;
            *)
    esac
done

echo 'Start checking....'

printf "Items for check: \n$FILESLIST\n\nModifier: ${FILE_MODIFYER}\n"

# for each files in tree of folders do (like python walk)
for filename in ${FILESLIST}; do
    # in diff mode file may be marked as deleted
    if [ -f $filename ];then ${FILE_MODIFYER} ${filename} ; fi
done

CHANGES=$(git diff --name-only)
if [ "$CHANGES" ] && [[ "${FILE_MODIFYER}"=~"heal_file" ]]; then
    echo
    echo 'ABORTED! Files was modified (autofixed). Check them pleaze.'
    echo '   git status'
    exit 1
fi

exit 0
