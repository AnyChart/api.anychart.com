# AnyChart API Release Versioning Tool Guide

The `release-version.sh` script is a high-performance, cross-platform utility designed to manage version strings across the AnyChart API Reference documentation (`.adoc` and `.html` files).

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Flag Reference](#flag-reference)
4. [Usage Examples](#usage-examples)
5. [How it Works](#how-it-works)
6. [Safety & Validation](#safety--validation)
7. [Cross-Platform Compatibility](#cross-platform-compatibility)

---

## Overview
As the AnyChart API evolves, hardcoded version strings and branch placeholders (like `{{branch-name}}`) need to be updated to specific release versions (e.g., `8.14.0`). This tool automates that process using parallel processing for maximum speed.

## Prerequisites
- **Configuration**: A `config.toml` file must be present in the root directory.
- **Tools**: Bash (4.0+), `awk`, `sed`, `grep`, and `xargs`.
- **Operating Systems**: 
  - **Linux** (Nproc supported)
  - **macOS** (BSD Sed compatible)
  - **Windows 11** (via Git Bash)

## Flag Reference

| Flag | Long Option | Description |
| :--- | :--- | :--- |
| `-b` | `--branch` | Replaces `{{branch-name}}` with the version defined in `config.toml`. |
| `-s` | `--sources` | Updates versioned paths for `geodata`, `locales`, and `themes`. |
| `-a` | `--all` | Combines both `-b` and `-s` (Full Release). |
| `-r` | `--reverse` | Reverts numeric versions back to placeholders and `.stg` to `.com`. |
| `-d` | `--dry-run` | Previews changes in the terminal without modifying any files. |
| `-v` | `--verbose` | Output the exact `sed` commands being executed. |
| `-h` | `--help` | Display usage information. |

---

## Usage Examples

### 1. Simple Release (Branch names only)
Use this when you only want to point the core library to a specific version.
```bash
./release-version.sh --branch
```

### 2. Full Release (All sources)
Replaces all placeholders and source versions at once.
```bash
./release-version.sh -a
```

### 3. Safety Check / Preview
See exactly what patterns will be matched and what the output would look like without writing to disk.
```bash
./release-version.sh --all --dry-run
```

### 4. Reverting for Development
Convert a release-ready directory back into a template format.
```bash
./release-version.sh --reverse
```

---

## How it Works

1. **Config Loading**: The script parses `config.toml` for `anychart-version`, `geodata-version`, etc.
2. **Replacement Engine**: It builds a series of `sed` expressions based on the selected mode.
3. **Parallel Execution**: It detects available CPU cores and splits the work into parallel streams using `xargs -P`.
4. **Cleanup**: Automatically cleans up temporary artifacts left behind by some OS implementations of `sed`.

## Safety & Validation
- **Conflict Prevention**: You cannot run `--all` with `--branch` or `--sources`, as they are mutually exclusive.
- **Strict Reverse Validation**: In `--reverse` mode, the script scans for any versions that *don't* match your current configuration and issues a warning before potentially inconsistent data is reverted.
- **State Check**: The script will prevent you from running a "Release" mode if release versions are already detected in the files, preventing double-nesting or corruption.

## Cross-Platform Compatibility
- **macOS**: Automatically detects BSD `sed` and adjusts the `-i` flag logic.
- **Windows**: Handles CRLF line endings in the config and uses Windows environment variables for CPU detection.
- **Exit Codes**: Uses `set -eo pipefail` for strict error reporting; any failure in the middle of the batch will stop the process and report.
