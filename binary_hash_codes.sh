#!/usr/bin/env bash
# clear
########################################################################################################################
#
#  Utility function to change all hash codes in js paths
#
#  You can run this command with parameters
#
########################################################################################################################

UUID_HCODE=$(uuidgen | tr "[:upper:]" "[:lower:]" | sed -e "s/-//g")

# function for "fix" file.
function heal_file(){
    perl -pi -e 's,(releases/{{branch-name}}/js/){1}([A-z0-9.-]+.min.js)(\?hcode=[^"]*)?",\1\2",g' $1
    perl -pi -e 's,(releases/{{branch-name}}/[A-z0-9./-]+.css)(\?hcode=[^"]*)?",\1",g' $1
}
# default mode
FILE_MODIFYER="heal_file"

# sugar function
function broke_file(){
    perl -pi -e 's,(releases/{{branch-name}}/js/){1}([A-z0-9.-]+.min.js)(\?hcode=[^"]+)?",\1\2?hcode='${UUID_HCODE}'",g' $1
    perl -pi -e 's,(releases/{{branch-name}}/[A-z0-9./-]+.css)(\?hcode=[^"]+)?",\1?hcode='${UUID_HCODE}'",g' $1
}

FILESLIST=$(find . -type f -name "*.html")
########################################################################################################################
#   Main functioonality
########################################################################################################################

# read command arguments
for ARGUMENT in "$@"
do
    case "$ARGUMENT" in
            replace|r|"-r")    FILE_MODIFYER="broke_file" ;;
            "-h"|"--help"|help|h|"-help")  printf "parameters: \
                \n 'replace (-r)' - to rename all {{branch-name}} to current branch\
                \n" && exit 1 ;;
            *)
    esac
done

echo "FILE_MODIFYER ${FILE_MODIFYER}"
echo "UUID_HCODE ${UUID_HCODE}"

# for each files in tree of folders do (like python walk)
for filename in ${FILESLIST}; do
    # in diff mode file may be marked as deleted
    if [ -f $filename ];then ${FILE_MODIFYER} ${filename} ; fi
done
