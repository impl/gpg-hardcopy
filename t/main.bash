# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

set -uT -o pipefail
shopt -s nullglob

. "$(dirname -- "${BASH_SOURCE[0]}")/armor.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/cli.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/export_revocation_cert.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/keyring.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/stage_dir.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/ui.bash"

test::main() (
  # Prevent potentially clobbering the user's keyring if something goes wrong.
  export GNUPGHOME='/homeless-shelter/.gnupg'

  local fn ret=0
  while read -r _ _ fn; do
    if [[ "$fn" != test::case::* ]]; then
      continue
    fi

    printf "%s: " "$fn"

    coproc {
      local test_dir
      test_dir="$(mktemp --tmpdir --directory gpg-hardcopy.test.XXXXXXXX)" || return $?
      trap 'rm -fr -- "$TMPDIR"' EXIT

      export TMPDIR="$test_dir/tmp"
      mkdir -p "$TMPDIR" || return $?
      _test::helper::set_up_assert_status_file "$test_dir" || return $?

      while read -r; do :; done || return $?
      ( "$fn" ) 2>&1 || return $?
      _test::helper::assert_status_file_is_empty "$test_dir" || return $?
    }
    local pid=$COPROC_PID stdout=${COPROC[0]} stdin=${COPROC[1]}
    exec 3<&"$stdout" {stdin}>&-

    local fn_ret=0
    wait "$pid" || fn_ret=$?

    if [[ $fn_ret == 0 ]]; then
      printf "ok\n"
    else
      ret=1
      printf "bad\n"
      cat <&3 | sed -e 's/^/  /'
    fi
  done < <(declare -F)
  return $ret
)

if ! ( return 0 2>/dev/null ); then
  test::main "$@"
fi
