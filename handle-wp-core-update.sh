#!/bin/bash
PATH_DIR="${GITHUB_WORKSPACE}/${PATH_DIR}"
# SSH_COMMAND="${SSH_COMMAND}"


# we need a script, that will check if core is at wrong version & fail - like consistency check
# and also not update if at the same version. 

echo 'HELLO!. I am in place.'
echo "PATH_DIR: ${PATH_DIR}"
echo "SSH_COMMAND: ${SSH_COMMAND}"

    # - name: Check for WP Core version attribute
    #   id: wpcore
    #   continue-on-error: true
    #   shell: bash
    #   run: |
    #     cd "${{ inputs.built }}"
    #     core_version=$(composer config extra.wordpress-core)
    #     echo core_update_cmd="wp core update --version=$core_version --force --path=${{ inputs.env-remote-root }}" >> $GITHUB_OUTPUT
