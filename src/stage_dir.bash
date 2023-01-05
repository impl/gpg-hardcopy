# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Set up a temporary directory for staging files under $TMPDIR.
gpg_hardcopy::stage_dir::set_up() {
  declare -g gpg_hardcopy__stage_dir
  if [[ -z "${gpg_hardcopy__stage_dir-}" ]]; then
    gpg_hardcopy__stage_dir="$(mktemp --tmpdir --directory gpg-hardcopy.XXXXXXXX)" || return $?
    trap 'rm -fr -- "$gpg_hardcopy__stage_dir"' EXIT

    # All temporary files will now be relative to this staging directory.
    mkdir -p "$gpg_hardcopy__stage_dir/tmp" || return $?
    export TMPDIR="$gpg_hardcopy__stage_dir/tmp"

    printf 'Using temporary staging directory %q.\n' "$gpg_hardcopy__stage_dir"
  fi
}

# Print the name of the staging directory to standard output.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
gpg_hardcopy::stage_dir() {
  if [[ -n "${gpg_hardcopy__stage_dir-}" ]]; then
    printf '%s\n' "$gpg_hardcopy__stage_dir"
  else
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  Temporary staging directory not set up! Did you forget to call
  gpg_hardcopy::stage_dir::set_up?
EOT
    return 2
  fi
}

# Print the name of a file relative to the staging directory.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The name of the file.
gpg_hardcopy::stage_dir::relative_path() {
  local stage_dir
  stage_dir="$(gpg_hardcopy::stage_dir)" || return $?

  realpath --relative-to="$stage_dir" "$1" || return $?
}
