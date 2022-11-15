#!/bin/bash
TARGET_DIR="${GITHUB_WORKSPACE}/${TARGET_DIR}"
SOURCE_DIR="${GITHUB_WORKSPACE}/${SOURCE_DIR}"

if [ ! -f "${TARGET_DIR}/composer.json" ]; then
	echo "Not going to install anything with composer"
	# Nothing to do here
	exit 0;
fi

if [ ! -f "${SOURCE_DIR}/vendor/composer/installed.json" ]; then
	echo "We don't have previously installed dependencies"
	# Nothing to do here either
	exit 0;
fi



# initialize composer on build dir
mkdir -p "${TARGET_DIR}/vendor"
rm -rf "${TARGET_DIR}/vendor/composer"
cp -rf "${SOURCE_DIR}/vendor/composer" "${TARGET_DIR}/vendor/composer"

# build list of plugins to be installed
WHITELIST=$(jq -crM '[ .packages[] | .name ] + ["composer/installers"] | unique' "${TARGET_DIR}/composer.lock")

# refresh installed.json based on packages previously installed
{
	jq --indent 4 -rM --argjson whitelist "${WHITELIST}" 'del(.packages[] | select( .name as $in | $whitelist | index($in) | not))' "${TARGET_DIR}/vendor/composer/installed.json"
} > "${TARGET_DIR}/vendor/composer/installed_new.json"

rm -rf "${TARGET_DIR}/vendor/composer/installed.json"
mv "${TARGET_DIR}/vendor/composer/installed_new.json" "${TARGET_DIR}/vendor/composer/installed.json"

# move files from location to new one
while IFS=\= read PACKAGE; do
	PACKAGE_DIR="${PACKAGE#"../../"}"
	PACKAGE_PARENT_DIR="$(dirname "$PACKAGE_DIR")"
	echo "Attempting to restore ${PACKAGE_DIR}"
	mkdir -p "${TARGET_DIR:?}/${PACKAGE_PARENT_DIR}"
	rm -rf "${TARGET_DIR:?}/${PACKAGE_DIR}"
	cp -rf "${SOURCE_DIR:?}/${PACKAGE_DIR}" "${TARGET_DIR:?}/${PACKAGE_DIR}"
	# TODO: ^ move, instead of copy
done < <(jq -crM 'del(.packages[] | select( .name as $in | ["composer/installers"] | index($in))) | .packages[]."install-path"' "${TARGET_DIR}/vendor/composer/installed.json")
unset IFS
