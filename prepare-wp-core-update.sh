#!/bin/bash

echo "Running prepare-wp-core-update.sh"

cd "${GITHUB_WORKSPACE}/${PATH_DIR}" || exit 1;

## Hook into the hook system for ssh deployment
HOOK_PATH="${RUNNER_TEMP}/.saucal/ssh-deploy/pre"
mkdir -p "${HOOK_PATH}"
ln -s "${GITHUB_ACTION_PATH}/handle-wp-core-update.sh" "${HOOK_PATH}/10-handle-wp-core-update.sh"
chmod +x "${HOOK_PATH}/10-handle-wp-core-update.sh"

echo "Hooked handle-wp-core-update.sh to ${HOOK_PATH}/10-handle-wp-core-update.sh"

CORE_VERSION_COMPOSER_TO=$(composer config extra.wordpress-core) || CORE_VERSION_COMPOSER_TO=""

echo "CORE_VERSION_COMPOSER_TO: $CORE_VERSION_COMPOSER_TO"

cd "${GITHUB_WORKSPACE}/${FROM_DIR}" || exit 1;

CORE_VERSION_COMPOSER_FROM=$(composer config extra.wordpress-core) || CORE_VERSION_COMPOSER_FROM=""

echo "CORE_VERSION_COMPOSER_FROM: $CORE_VERSION_COMPOSER_FROM"

if [ -z "$CORE_VERSION_COMPOSER_TO" ]; then
    echo "CORE_VERSION_COMPOSER_TO is not set."
    exit 0
fi

echo "$CORE_VERSION_COMPOSER_TO" > "${RUNNER_TEMP}/core-version-composer-to"

if [ ! -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    echo "$CORE_VERSION_COMPOSER_FROM" > "${RUNNER_TEMP}/core-version-composer-from"
fi
