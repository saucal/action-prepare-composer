#!/bin/bash

cd "${GITHUB_WORKSPACE}/${PATH_DIR}" || exit 1;

CORE_VERSION_COMPOSER_TO=$(composer config extra.wordpress-core 2>/dev/null) || CORE_VERSION_COMPOSER_TO=""

# Core isn't managed by composer here: nothing to say, but still hook the (probe-only, quiet)
# handler so consistency self-heal learns the server's version and whether the deploy user can
# write core — where it can, self-heal brings the line back at the server's version.
if [ -z "$CORE_VERSION_COMPOSER_TO" ]; then
    HOOK_PATH="${RUNNER_TEMP}/.saucal/ssh-deploy/pre"
    mkdir -p "${HOOK_PATH}"
    ln -sf "${GITHUB_ACTION_PATH}/handle-wp-core-update.sh" "${HOOK_PATH}/10-handle-wp-core-update.sh"
    exit 0
fi

cd "${GITHUB_WORKSPACE}/${FROM_DIR}" || exit 1;

CORE_VERSION_COMPOSER_FROM=$(composer config extra.wordpress-core 2>/dev/null) || CORE_VERSION_COMPOSER_FROM=""

echo "CORE_VERSION_COMPOSER_TO: $CORE_VERSION_COMPOSER_TO"
echo "CORE_VERSION_COMPOSER_FROM: $CORE_VERSION_COMPOSER_FROM"

echo "$CORE_VERSION_COMPOSER_TO" > "${RUNNER_TEMP}/core-version-composer-to"

if [ ! -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    echo "$CORE_VERSION_COMPOSER_FROM" > "${RUNNER_TEMP}/core-version-composer-from"
fi

## Hook into the hook system for ssh deployment
HOOK_PATH="${RUNNER_TEMP}/.saucal/ssh-deploy/pre"
mkdir -p "${HOOK_PATH}"
ln -s "${GITHUB_ACTION_PATH}/handle-wp-core-update.sh" "${HOOK_PATH}/10-handle-wp-core-update.sh"
chmod +x "${HOOK_PATH}/10-handle-wp-core-update.sh"

echo "Hooked handle-wp-core-update.sh to ${HOOK_PATH}/10-handle-wp-core-update.sh"
