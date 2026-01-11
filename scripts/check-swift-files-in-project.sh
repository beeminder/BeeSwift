#!/bin/bash
#
# Pre-commit hook to ensure all Swift files in the repository
# are included in the Xcode project.
#
# This helps prevent accidentally committing Swift files that
# won't be compiled because they weren't added to the project.

set -euo pipefail

# Find the repository root
REPO_ROOT="$(git rev-parse --show-toplevel)"
PROJECT_FILE="$REPO_ROOT/BeeSwift.xcodeproj/project.pbxproj"

if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Error: Could not find Xcode project file at $PROJECT_FILE"
    exit 1
fi

# Known files that are intentionally not in the Xcode project.
# Add files here only if they should NOT be compiled (e.g., templates, samples).
# If a file SHOULD be compiled, add it to the Xcode project instead of excluding it here.
EXCLUDED_FILES=(
    "Config.sample.swift"  # Template file for creating Config.swift
    # TODO: Remove this exclusion after adding RefreshGoalIntent.swift to the Xcode project.
    # This file was added in commit 99e9571 but wasn't included in the project.
    # See: https://github.com/beeminder/BeeSwift/commit/99e9571
    "RefreshGoalIntent.swift"
)

# Extract synchronized folder names from PBXFileSystemSynchronizedRootGroup section
# These folders are automatically synchronized with Xcode and don't need individual file references
SYNCED_FOLDERS=$(grep -A 10 "isa = PBXFileSystemSynchronizedRootGroup" "$PROJECT_FILE" | \
    grep "path = " | \
    sed 's/.*path = \([^;]*\);.*/\1/' | \
    tr -d '"' || true)

# Find all Swift files in the repository, excluding build artifacts and dependencies
SWIFT_FILES=$(cd "$REPO_ROOT" && find . -name "*.swift" -type f \
    ! -path "*/Pods/*" \
    ! -path "*/.build/*" \
    ! -path "*/DerivedData/*" \
    | sed 's|^\./||' | sort)

MISSING_FILES=()

for file in $SWIFT_FILES; do
    # Get just the filename without the path
    filename=$(basename "$file")

    # Check if this file is in the exclusion list
    is_excluded=false
    for excluded in "${EXCLUDED_FILES[@]}"; do
        if [[ "$filename" == "$excluded" ]]; then
            is_excluded=true
            break
        fi
    done

    if $is_excluded; then
        continue
    fi

    # Check if the file is inside a synchronized folder
    in_synced_folder=false
    for folder in $SYNCED_FOLDERS; do
        if [[ "$file" == *"/$folder/"* ]]; then
            in_synced_folder=true
            break
        fi
    done

    if $in_synced_folder; then
        # Files in synchronized folders are automatically included
        continue
    fi

    # Check if this file is referenced in the project file
    # We look for the filename in PBXFileReference entries
    if ! grep -q "path = $filename;" "$PROJECT_FILE" && \
       ! grep -q "path = \"$filename\";" "$PROJECT_FILE" && \
       ! grep -q "name = $filename;" "$PROJECT_FILE" && \
       ! grep -q "name = \"$filename\";" "$PROJECT_FILE"; then
        MISSING_FILES+=("$file")
    fi
done

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
    echo "Error: The following Swift files are not included in the Xcode project:"
    echo ""
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "Please add these files to BeeSwift.xcodeproj or add them to the"
    echo "exclusion list in scripts/check-swift-files-in-project.sh if they"
    echo "should not be compiled."
    exit 1
fi

echo "All Swift files are included in the Xcode project."
exit 0
