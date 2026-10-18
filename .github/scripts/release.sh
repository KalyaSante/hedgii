#!/bin/bash
# Creates a GitHub release (and its tag) for every version bump on the first-parent history of
# HEAD that has no tag yet: the commit where ./version changed gets "v<version>". Run by CI on
# pushes to master; it is idempotent, so a failed or skipped run is caught up by the next one.
# Needs the full history with tags (actions/checkout fetch-depth: 0) and GH_TOKEN for gh.
set -euo pipefail

repo_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-KalyaSante/hedgii}"

# Only bumps after the newest existing release tag (older versions were never released)
# prev: tag of the previous release (compare link); prev_ref: its commit (tags created by gh
# below exist on GitHub only, not in this checkout)
prev=$(git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD 2>/dev/null || true)
prev_ref="$prev"
range="${prev:+$prev..}HEAD"

created=0
while read -r commit; do
    [[ -n "$commit" ]] || continue
    version=$(git show "$commit:version" 2>/dev/null | tr -d '[:space:]') || continue
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Skipping $commit: invalid version '$version'"
        continue
    fi
    tag="v$version"
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || gh release view "$tag" >/dev/null 2>&1; then
        echo "$tag already released"
        prev="$tag"
        prev_ref="$commit"
        continue
    fi

    notes=$(mktemp)
    {
        echo "## Changes"
        echo
        # Version bumps and Copilot's empty planning commits carry no information
        git log --no-merges --format='- %s (%h)' "${prev_ref:+$prev_ref..}$commit" \
            | grep -vE '^- (build: v[0-9]|Initial plan|Apply remaining changes)' || true
        if [[ -n "$prev" ]]; then
            echo
            echo "**Full changelog**: $repo_url/compare/$prev...$tag"
        fi
    } > "$notes"

    echo "Creating release $tag at $commit"
    gh release create "$tag" --target "$commit" --title "Hedgii $version" --notes-file "$notes"
    rm -f "$notes"
    prev="$tag"
    prev_ref="$commit"
    created=$((created + 1))
done < <(git log --first-parent --reverse --format=%H "$range" -- version)

echo "$created release(s) created"
