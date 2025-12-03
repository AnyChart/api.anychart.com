#!/usr/bin/env bash
clear

# Parse config.toml for version numbers
awk -F'[ ="]+' '$1~/^(anychart|locales|geodata|themes)-version/{
    gsub("-","_",$1); gsub("-","_",$2); print toupper($1)"="$2
}' config.toml > /tmp/vars && source /tmp/vars && rm /tmp/vars

echo "ANYCHART_VERSION : '${ANYCHART_VERSION}'"
echo "LOCALES_VERSION  : '${LOCALES_VERSION}'"
echo "GEODATA_VERSION  : '${GEODATA_VERSION}'"
echo "THEMES_VERSION   : '${THEMES_VERSION}'"
echo

# Build sed expressions based on mode
# Mode 1(default): --sources – replace version numbers in source paths
sed_exprs=("-e" "s|\(geodata\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$GEODATA_VERSION/|g" \
            "-e" "s|\(locales\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$LOCALES_VERSION/|g" \
            "-e" "s|\(themes\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$THEMES_VERSION/|g")

# Mode 2: --branch – replace branch-name placeholder with AnyChart version
[[ $1 == "--branch" ]] &&
sed_exprs=("-e" "s|\(releases\)/\({{branch-name}}\)/|\1/$ANYCHART_VERSION/|g")

# Setup parallelization parameters
CORES=$(nproc 2>/dev/null || echo 4)   # Default to 4 cores if nproc unavailable
BATCH_SIZE=200                         # Files per sed process for optimal throughput

verbose_flag=""
[[ $2 == "-v" ]] && verbose_flag="-t"   # Enable verbose xargs output

echo "Strategy: ${CORES} parallel streams, ${BATCH_SIZE} files per sed process."

# Start timer
start_time=$(date +%s)

# Apply sed replacements in parallel to all *.adoc and *.html files
find . -type f \( -iname '*.adoc' -o -iname '*.html' \) -print0 | \
    xargs -0 -P "$CORES" -n "$BATCH_SIZE" $verbose_flag \
    sed -i "${sed_exprs[@]}"

# Abort if any sed process failed
if [[ $? -ne 0 ]]; then
    echo
    echo "[FAILED] Some files could not be processed."
    exit 1
fi

# Report elapsed time
end_time=$(date +%s)
elapsed=$((end_time - start_time))
printf "\nFinished in ${elapsed}s"