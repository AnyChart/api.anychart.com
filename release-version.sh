#!/usr/bin/env bash

# release-version.sh
# Portably manage version replacements in AnyChart API Reference documentation.
# Compatible with macOS, Linux, and Windows (Git Bash).

set -eo pipefail # Exit on error, pipe failure

# --- Helper Functions ---

log() {
    printf "%b\n" "$*"
}

error() {
    log "\n\033[0;31m[ERROR]\033[0m $*" >&2
    exit 1
}

get_cores() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.ncpu
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "$NUMBER_OF_PROCESSORS"
    else
        command -v nproc >/dev/null && nproc || echo 4
    fi
}

# --- Initialization ---

start_time=$(date +%s)
VERBOSE_FLAG=false
DRY_RUN=false
BRANCH_MODE=false
REVERSE_MODE=false
SOURCES_MODE=false
ALL_MODE=false

# --- Argument Parsing (Manual loop for portability) ---

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--branch)   BRANCH_MODE=true; shift ;;
        -s|--sources)  SOURCES_MODE=true; shift ;;
        -a|--all)      ALL_MODE=true; shift ;;
        -v|--verbose)  VERBOSE_FLAG=true; shift ;;
        -r|--reverse)  REVERSE_MODE=true; shift ;;
        -d|--dry-run)  DRY_RUN=true; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -b, --branch    Replace branch placeholder"
            echo "  -s, --sources   Replace source versions"
            echo "  -a, --all       Replace both branch and sources"
            echo "  -r, --reverse   Revert branch replacements"
            echo "  -v, --verbose   Show verbose output"
            echo "  -d, --dry-run   Show changes without applying them"
            exit 0
            ;;
        --) shift; break ;;
        *) error "Invalid option: $1" ;;
    esac
done

# --- Validation & Configuration ---

[[ -f config.toml ]] || error "config.toml not found in current directory."

# Parse config.toml into environment variables portably
eval "$(awk -F '[ ="]+' '/-version/ {
    key=$1; 
    value=$2; 
    if (key == "") { key=$2; value=$3; } # Handle leading space if any
    gsub("-","_",key); 
    print toupper(key) "=\"" value "\""
}' config.toml)"

# Guard against missing version strings in config.toml
: "${ANYCHART_VERSION:?Missing anychart-version in config.toml}"
: "${GEODATA_VERSION:?Missing geodata-version in config.toml}"
: "${LOCALES_VERSION:?Missing locales-version in config.toml}"
: "${THEMES_VERSION:?Missing themes-version in config.toml}"

# Strict Version Validation (Upgrade #4)
# Check if existing hardcoded versions in files match the config.toml intended for replacement
if [[ $REVERSE_MODE == true ]]; then
    log "Performing Strict Validation for Reverse Mode..."
    MISMATCHED=$(find . -maxdepth 3 -type f \( -name "*.adoc" -o -name "*.html" \) -exec grep -oE 'releases/[0-9]+\.[0-9]+\.[0-9]+' {} + | grep -v "$ANYCHART_VERSION" || true)
    if [[ -n "$MISMATCHED" ]]; then
        log "\033[0;33m[WARNING]\033[0m Found versions that do not match ANYCHART_VERSION ($ANYCHART_VERSION):"
        echo "$MISMATCHED" | head -n 5
        log "... (showing first 5 matches)"
    fi
fi

# Count release versions portably.
# We turn off pipefail for this specific check because grep returns 1 if no matches are found, 
# which would normally kill the script under 'set -e'.
NUMERIC_VERSION_COUNT=$(grep -rE 'releases/[0-9]+\.[0-9]+\.[0-9]+' --include='*.adoc' --include='*.html' . | wc -l | xargs || true)

if [[ $NUMERIC_VERSION_COUNT -ne 0 ]] && [[ $BRANCH_MODE == true || $ALL_MODE == true ]]; then
    error "There are release versions already present. Cannot apply branch/all mode."
elif [[ $REVERSE_MODE == true && $NUMERIC_VERSION_COUNT -eq 0 ]]; then
    error "No release versions found to reverse."
fi

# Conflict resolution
if [[ $BRANCH_MODE == true && $SOURCES_MODE == true ]]; then
    ALL_MODE=true; BRANCH_MODE=false; SOURCES_MODE=false
fi

if [[ ($BRANCH_MODE == true || $SOURCES_MODE == true) && $ALL_MODE == true ]]; then
    error "--branch or --sources cannot be used with --all."
fi
if [[ ($BRANCH_MODE == true || $SOURCES_MODE == true || $ALL_MODE == true) && $REVERSE_MODE == true ]]; then
    error "--reverse cannot be used with modification flags."
fi

# --- Build SED Expressions ---

sed_exprs=()
if [[ $ALL_MODE == true ]]; then
    sed_exprs+=("-e" "s|\(releases\)/\({{branch-name}}\)/|\1/$ANYCHART_VERSION/|g")
    sed_exprs+=("-e" "s|\(geodata\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$GEODATA_VERSION/|g")
    sed_exprs+=("-e" "s|\(locales\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$LOCALES_VERSION/|g")
    sed_exprs+=("-e" "s|\(themes\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$THEMES_VERSION/|g")
elif [[ $BRANCH_MODE == true ]]; then
    sed_exprs+=("-e" "s|\(releases\)/\({{branch-name}}\)/|\1/$ANYCHART_VERSION/|g")
elif [[ $SOURCES_MODE == true ]]; then
    sed_exprs+=("-e" "s|\(geodata\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$GEODATA_VERSION/|g")
    sed_exprs+=("-e" "s|\(locales\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$LOCALES_VERSION/|g")
    sed_exprs+=("-e" "s|\(themes\)/[0-9]\+\.[0-9]\+\.[0-9]\+/|\1/$THEMES_VERSION/|g")
elif [[ $REVERSE_MODE == true ]]; then
    sed_exprs+=("-e" "s|\.stg|\.com|g")
    sed_exprs+=("-e" "s|\(releases\)/[^/][^/]*/|\1/{{branch-name}}/|g")
else
    error "No mode selected. Use --branch, --sources, --all or --reverse."
fi

# --- Execution ---

log "VERSIONS: AnyChart:$ANYCHART_VERSION, Geodata:$GEODATA_VERSION, Locales:$LOCALES_VERSION, Themes:$THEMES_VERSION"

CORES=$(get_cores)
BATCH_SIZE=200

# Detect if we're using GNU sed or BSD sed
if sed --version >/dev/null 2>&1; then
    SED_CMD=("sed" "-i") # GNU
else
    SED_CMD=("sed" "-i" "") # BSD (macOS)
fi

# Dry Run Logic (Upgrade #1)
if [[ $DRY_RUN == true ]]; then
    log "\n\033[0;35m[DRY RUN]\033[0m No files will be modified."
    SED_CMD=("sed") 
fi

log "Strategy: ${CORES} parallel streams via xargs, using ${SED_CMD[*]}"

FILE_COUNT=$(find . -type f \( -iname '*.adoc' -o -iname '*.html' \) | wc -l | xargs)


# Find and process files
# We use a temporary trap just in case sed leaves artifacts (mostly for GNU sed -i)
trap "find . -type f -name 'sed??????' -exec rm -f {} \; 2>/dev/null" EXIT INT TERM

xargs_verbose=""
[[ $VERBOSE_FLAG == true ]] && xargs_verbose="-t"

# Execute replacements
find . -type f \( -iname '*.adoc' -o -iname '*.html' \) -print0 | \
    xargs -0 -P "$CORES" -n "$BATCH_SIZE" $xargs_verbose "${SED_CMD[@]}" "${sed_exprs[@]}"

# Completion
end_time=$(date +%s)
log "\n\033[0;32m[SUCCESS]\033[0m Finished in $((end_time - start_time))s. Processed ${FILE_COUNT} files."