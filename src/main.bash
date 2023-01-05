# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

set -uT -o pipefail
shopt -s inherit_errexit nullglob

. "$(dirname -- "${BASH_SOURCE[0]}")/cli.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/export.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/help.bash"

# Main entry point.
#
# Parameters:
# - ...: Command-line arguments.
gpg_hardcopy::main() (
  # Prevent other users from seeing any work we do.
  umask 0077

  # Parse command-line arguments to an args array.
  local args
  args="$(gpg_hardcopy::cli::parse_args "$@")" || return $?

  local mode_fn
  mode_fn="gpg_hardcopy::$(gpg_hardcopy::cli::get_mode "$args")::main" || return $?
  "$mode_fn" "$args" || return $?
)

if ! ( return 0 2>/dev/null ); then
  gpg_hardcopy::main "$@"
fi
