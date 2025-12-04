#!/usr/bin/env bash
clear

# Start timer
start_time=$(date +%s)

# Parse command-line options with getopt and build sed expressions based on mode
OPTS=$(getopt -o bsavr --long branch,sources,all,verbose,reverse -n "$0" -- "$@") || exit 1
eval set -- "$OPTS"
VERBOSE_FLAG=""
BRANCH_MODE=false
REVERSE_MODE=false
SOURCES_MODE=false
ALL_MODE=false
sed_exprs=()
while true; do
    case "$1" in
        --branch | -b) BRANCH_MODE=true; shift ;;
        --sources | -s) SOURCES_MODE=true; shift ;;
        --all | -a) ALL_MODE=true; shift ;;
        --verbose | -v) VERBOSE_FLAG="-t"; shift ;;
        --reverse | -r) REVERSE_MODE=true; shift ;;
        --) shift; break ;;
        *) echo "Invalid option: $1"; exit 1 ;;
    esac
done

# Count release versions in adoc and html files and exit if the wrong mode is chosen
RELEASE_COUNT=$(grep -ro 'releases/[0-9]\+\.[0-9]\+\.[0-9]\+' --include=*.{adoc,html} . | wc -l)
if [[ ($RELEASE_COUNT -ne 0) && ($BRANCH_MODE == true || $ALL_MODE == true) ]] then
    printf "Error: There are release versions present.\n";
    exit 1;
elif [[ $REVERSE_MODE == true && $RELEASE_COUNT -eq 0 ]]; then
    printf "Error: There are no release versions present.\n";
    exit 1;
fi

# Parse config.toml for version numbers
awk -F'[ ="]+' '$1~/^(anychart|locales|geodata|themes)-version/{
    gsub("-","_",$1); gsub("-","_",$2); print toupper($1)"="$2
}' config.toml > /tmp/vars && source /tmp/vars && rm /tmp/vars

# Merge --branch + --sources into --all and forbid conflicting flags
if [[ $BRANCH_MODE == true && $SOURCES_MODE == true ]]; then
    ALL_MODE=true
    BRANCH_MODE=false
    SOURCES_MODE=false
fi
if [[ ($BRANCH_MODE == true || $SOURCES_MODE == true) && $ALL_MODE == true ]]; then
    printf "\nError: --branch or --sources cannot be used with --all.\n"
    exit 1
elif [[ ($BRANCH_MODE == true || $SOURCES_MODE == true || $ALL_MODE == true) && $REVERSE_MODE == true ]]; then
    printf "\nError: --reverse cannot be used with --branch, --sources, or --all.\n"
    exit 1
fi

# Build sed expressions according to the chosen mode
if [[ $ALL_MODE == true ]]; then
    # Mode 3: branch + sources combined
    sed_exprs=(
        -e "s|\(releases\)/\({{branch-name}}\)/|\1/$ANYCHART_VERSION/|g"
        -e "s|\(geodata\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$GEODATA_VERSION/|g"
        -e "s|\(locales\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$LOCALES_VERSION/|g"
        -e "s|\(themes\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$THEMES_VERSION/|g"
    )
elif [[ $BRANCH_MODE == true ]]; then
    # Mode 1: branch-name placeholder only
    sed_exprs=(-e "s|\(releases\)/\({{branch-name}}\)/|\1/$ANYCHART_VERSION/|g")
elif [[ $SOURCES_MODE == true ]]; then
    # Mode 2: version numbers in source paths only
    sed_exprs=(
        -e "s|\(geodata\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$GEODATA_VERSION/|g"
        -e "s|\(locales\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$LOCALES_VERSION/|g"
        -e "s|\(themes\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$THEMES_VERSION/|g"
    )
elif [[ $REVERSE_MODE == true ]]; then
    # Mode 4: reverse branch-name replacements
    sed_exprs=(
        -e "s|\.stg|\.com|g"
        -e "s|\(releases\)/[^/][^/]*/|\1/{{branch-name}}/|g"
    )
else
    # Exit with error if no sed expressions were built
    printf "\nError: no replacement mode selected. Use --branch, --sources, --all or --reverse.\n"
    exit 1
fi

printf "ANYCHART_VERSION : '${ANYCHART_VERSION}'
LOCALES_VERSION  : '${LOCALES_VERSION}'
GEODATA_VERSION  : '${GEODATA_VERSION}'
THEMES_VERSION   : '${THEMES_VERSION}'\n"

# Setup parallelization parameters
# Defaults to 4 cores if nproc unavailable
CORES=$(nproc 2>/dev/null || echo 4)
# Files per sed process for optimal throughput on 32 cores 4Ghz processor
BATCH_SIZE=200

printf "\nStrategy: ${CORES} parallel streams, ${BATCH_SIZE} files per sed process.\n"

# Apply sed replacements in parallel to all *.adoc and *.html files
find . -type f \( -iname '*.adoc' -o -iname '*.html' \) -print0 | \
    xargs -0 -P "$CORES" -n "$BATCH_SIZE" $VERBOSE_FLAG \
    sed -i "${sed_exprs[@]}"

# Abort if any sed process failed
if [[ $? -ne 0 ]]; then
    printf "\n[FAILED] Some files could not be processed."
    exit 1
fi

# Sometimes sed leaves some temporary files behind, so we clean them up
trap "find . -type f -name 'sed??????' -exec rm -f {} \; 2>/dev/null" EXIT INT TERM

# Stop timer and report elapsed time
end_time=$(date +%s)
elapsed=$((end_time - start_time))
printf "\nFinished in ${elapsed}s"