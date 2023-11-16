
cd "${GITHUB_WORKSPACE}/${PATH_DIR}" || exit 1;

cp "$GITHUB_ACTION_PATH/handle-wp-core-update.sh" "${RUNNER_TEMP}/handle-wp-core-update.sh"

pwd
ls -als

CORE_VERSION_COMPOSER_TO=$(composer config extra.wordpress-core)

cd "${GITHUB_WORKSPACE}/${FROM_DIR}" || exit 1;

pwd
ls -als

CORE_VERSION_COMPOSER_FROM=$(composer config extra.wordpress-core)

if [ -z "$CORE_VERSION_COMPOSER_TO" ]; then
    echo "CORE_VERSION_COMPOSER_TO is not set."
    exit 0
fi

echo "CORE_VERSION_COMPOSER_TO: $CORE_VERSION_COMPOSER_TO"
echo "$CORE_VERSION_COMPOSER_TO" > "${RUNNER_TEMP}/core-version-composer-to"

if [ -z "$CORE_VERSION_COMPOSER_FROM" ]; then
    echo "CORE_VERSION_COMPOSER_FROM: $CORE_VERSION_COMPOSER_FROM"
    echo "$CORE_VERSION_COMPOSER_FROM" > "${RUNNER_TEMP}/core-version-composer-from"
fi

ls -als "${RUNNER_TEMP}/" # TODO: remove

