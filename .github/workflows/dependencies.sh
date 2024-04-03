#!/usr/bin/env bash

# Checks dependencies in `versions.env`
# Requires `bats-core/bats-core/contrib/semver` to be on $PATH.
# This expects to be run from GitHub Actions.

set -o allexport -o errexit -o nounset #-o xtrace
source versions.env
set +o allexport

n=$'\n'

# Iterate over all envrionment variables
for repo_var in $(compgen -e); do
    short_name="${!repo_var##*/}" # short repo name
    prefix="${repo_var%_REPO}" # prefix of the environment variable name
    if [[ "$repo_var" == "$prefix" ]]; then
        # This variable does not end with _REPO
        continue
    fi
    version_var=${prefix}_VERSION
    if [[ -z "${!repo_var:-}" ]] || [[ -z "${!version_var:-}" ]]; then
        # repo or version not set; probably a variable name collision
        continue
    fi

    # Read in all the releaseas available, excluding pre-releases and drafts.
    printf "Checking %s...\n" "$short_name"
    IFS=$'\n' read -d '' -r -a all_versions < <({
    gh api "repos/${!repo_var}/releases" --jq \
        '.[] | select((.prerelease or .draft) | not) | .tag_name'
      printf "\0"
    })

    # See if any version is higher than what we already have.
    target_version="${!version_var}"
    for version in "${all_versions[@]}"; do
        if [[ -z "$target_version" ]]; then
            target_version="${version}"
        elif [[ "$(semver compare "$target_version" "$version")" == "-1" ]]; then
            target_version="$version"
        fi
    done

    if [[ "${!version_var}" == "${target_version}" ]]; then
        printf "%s doesn't need to be updated.\n" "$short_name"
        continue
    fi

    branch_name="rddepman/${short_name}/${!version_var}-to-${target_version}"
    # Check for existing pull requests (whether they're open)
    gh_template='#{{ .number }}: {{ .title }}{{"\n"}}'
    if gh pr view --json number,title --template "$gh_template" "$branch_name"; then
        echo "Found existing pull request, not making a new one"
        continue
    fi

    # Create a new branch
    printf "Updating %s from %s to %s...\n" "$short_name" "${!version_var}" "$target_version"
    git switch --force-create "$branch_name" "${GITHUB_REF:-origin/main}"
    git checkout --force HEAD -- versions.env
    # Bump the version
    sed -i.bak "/${version_var}=/c\\$n${version_var}=${target_version}$n" versions.env
    # Commit the changes
    title="Bump ${short_name} from ${!version_var} to ${target_version}"
    message="Automated bump based on GitHub releases.  See .github/workflows/dependencies.yaml"
    git -c user.name="$GIT_AUTHOR_NAME" -c user.email="$GIT_AUTHOR_EMAIL" \
        commit --signoff --message "$title" --message "$message" versions.env
    git push --force origin "$branch_name"
    # Create a PR
    gh pr create --fill --head "$branch_name"
done
