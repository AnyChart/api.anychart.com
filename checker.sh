#!/usr/bin/env bash
clear
########################################################################################################################
#
#  Utility function to fix known troubles with production server
#
#  You can run this command with parameters
#
########################################################################################################################

# Install a pre-push Git hook if it doesn't already exist.
# This hook ensures that checker.sh runs automatically before every push to the "develop" branch,
# unless the commit message contains "#without-check".
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
# Determine the current Git branch name by parsing the output of `git branch`.
CURRENT_BRANCH=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/');

# List of files to ignore during non-ASCII checks.
# These files are known to contain intentional non-ASCII characters.
declare -a IGNOREFILES=(
    "./format/_samples/anychart.format.locales_custom.html"
    "./format/_samples/anychart.format.getMessage.html"
    )

# Build a list of files that differ from origin/develop and have .html or .adoc extensions.
# This is the default set of files to process.
FILESLIST=$(git diff --name-only origin/develop | grep -e .html -e .adoc )

# Function to "fix_production_issues" (fix) a file:
# 1. Replace ".stg" domains with ".com" to ensure production URLs.
# 2. Normalize release paths to use the placeholder "{{branch-name}}".
# 3. Check for unexpected non-ASCII characters unless the file is in IGNOREFILES.
function fix_production_issues(){
    filename=$1
    # Replace staging URLs with production ones.
    perl -pi -e 's/\.stg/\.com/g' ${filename}
    # Normalize release paths to use the placeholder.
    perl -pi -e 's,(releases)/([^/])+/,\1/{{branch-name}}/,g' ${filename}

    # Skip non-ASCII checks for explicitly ignored files.
    if [[ ! " ${IGNOREFILES[*]} " == *"$filename"* ]]; then
        # Strip known safe characters and detect any remaining non-ASCII bytes.
        # tr -d '\r' : remove Windows carriage returns.
        # tr -d '\n' : remove newlines to treat file as one long line.
        # sed 's/\xC2\xA0/+/g' : replace non-breaking spaces with a safe placeholder.
        # sed -e "s/'//g;s/[\s\t]/ /g" : remove single quotes and collapse whitespace.
        # sed -e 's/[0-9A-z"*+-=()/&!?.,:;$<>#{}%~|@ ]//g' : strip all expected ASCII characters.
        # awk '{$1=$1}1' : trim leading/trailing spaces.
        match=$(cat ${filename} | tr -d '\r' | tr -d '\n' | sed 's/\xC2\xA0/+/g' | \
            sed -e "s/'//g;s/[\s\t]/ /g" | sed -e 's/[0-9A-z"*+-=()/&!?.,:;$<>#{}%~|@ ]//g' | \
            awk '{$1=$1}1' )
        # If any unexpected characters remain, report them with hex codes.
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

# Default modifier function: fix_production_issues.
FILE_MODIFIER="fix_production_issues"

# "Sugar" function to intentionally "break" files for local testing:
# Replaces the placeholder "{{branch-name}}" with the actual current branch name.
function broke_file(){
    FILENAME=$1
    perl -pi -e "s,(releases)/({{branch-name}})+/,\1/$CURRENT_BRANCH/,g" ${FILENAME}
}

########################################################################################################################
#   Main functionality
########################################################################################################################

# Parse command-line arguments to override defaults.
for ARGUMENT in "$@"
do
    case "$ARGUMENT" in
            # Switch to "broke" mode for local testing.
            replace|r|"-r")    FILE_MODIFIER="broke_file" ;;
            # Process all relevant files instead of just the diff.
            all|a|"-a")        FILESLIST=$(find . -type f | grep -e .html -e .adoc -e .md) ;;
            # Display help text and exit.
            "-h"|"--help"|help|h|"-help")  printf "parameters: \
                \n 'replace (-r)' - to rename all {{branch-name}} to current branch\
                \n 'all (-a)' - modify all files (by default False, modify only diff with origin/develop)\
                \n 'links (-l)' - get links to pg and github.com for changed samples\
                \n" && exit 1 ;;
            # Print playground and GitHub links for changed HTML samples.
            links|link|l|"-l")
                for filename in ${FILESLIST}; do
                    fileext=${filename:${#filename}-4}

                    if [[ "$fileext" = "html" ]]; then
                        pglink="https://playground.anychart.stg/api/$CURRENT_BRANCH/${filename:0:${#filename}-5}\n\t"
                    fi

                    printf "\n*$filename*\n\t${pglink}https://github.com/AnyChart/api.anychart.com/blob/$CURRENT_BRANCH/$filename\n"
                done
                exit 0
                ;;
            *)
    esac
done

echo 'Start checking....'

printf "Items for check: \n$FILESLIST\n\nModifier: ${FILE_MODIFIER}\n"

# Apply the chosen modifier to each file in the list.
for filename in ${FILESLIST}; do
    # in diff mode file may be marked as deleted
    if [ -f $filename ];then ${FILE_MODIFIER} ${filename} ; fi
done

# If any files were modified (autofixed) in fix_production_issues mode, abort and prompt the user to review changes.
CHANGES=$(git diff --name-only)
if [ "$CHANGES" ] && [[ "${FILE_MODIFIER}"=~"fix_production_issues" ]]; then
    echo
    echo 'ABORTED! Files were modified (autofixed). Check them please.'
    echo '   git status'
    exit 1
fi

exit 0
