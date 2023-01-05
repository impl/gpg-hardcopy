# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Set a status file to report assertions to.
#
# Parameters:
# - $1: The path to the test state directory.
_test::helper::set_up_assert_status_file() {
  declare -g test__assert__status_file="$1/status"
  : >"$test__assert__status_file"
}

# Determine whether the status file is empty.
#
# Parameters:
# - $1: The path to the test state directory.
_test::helper::assert_status_file_is_empty() {
  test ! -s "$1/status"
}

test::assert::if() {
  local assertion
  assertion="[[ $(printf "%q" "$3") $(printf "%q" "$2") $(printf "%q" "$4") ]]"

  printf 'Assert %s with %s: ' "$1" "$assertion" >&2
  if eval "$assertion"; then
    printf "passed.\n" >&2
  else
    if [[ -n "${test__assert__status_file-}" ]]; then
      printf '!' >"$test__assert__status_file" || return $?
    fi
    printf "failed.\n" >&2
    return 1
  fi
}

test::assert::status() {
  local message="$1" op="$2" expected="$3" ret=0
  shift 3
  "$@" || ret=$?
  test::assert::if "$message ($*)" "$op" "$expected" "$ret"
}

test::assert::success() {
  local message="$1"
  shift
  test::assert::status "$message" -eq 0 "$@"
}

test::assert::test() {
  local message="$1"
  shift
  test::assert::success "$message" test "$@"
}

test::assert::jq_filter() {
  local message="$1"
  shift
  test::assert::success "$message" jq -e "$@" >/dev/null
}

declare -a TEST__HELPER__SET_UP_GPG__GPG_CONF=(
  'pinentry-mode loopback'
)

test::helper::set_up_gpg() {
  declare -g test__gnupghome
  if [[ -z "${test__gnupghome-}" ]]; then
    test::assert::success 'staging directory set up' gpg_hardcopy::stage_dir::set_up
    test__gnupghome="$(gpg_hardcopy::stage_dir)/.gnupg"

    export GNUPGHOME="$test__gnupghome"

    (
      umask 077
      test::assert::success 'created GnuPG home directory' mkdir -p "$GNUPGHOME"
      test::assert::success 'created GnuPG configuration file' printf '%s\n' "${TEST__HELPER__SET_UP_GPG__GPG_CONF[@]}" >"$GNUPGHOME/gpg.conf"
    )
  fi
}

declare -a TEST__HELPER__GENERATE_KEY__DATA=(
  'Key-Type: RSA'
  'Key-Length: 4096'
  'Subkey-Type: RSA'
  'Subkey-Length: 3072'
  'Name-Real: Test User'
  'Expire-Date: 0'
  'Passphrase: test'
)

# Read the key fingerprint from the GnuPG status stream and print it to standard
# output.
_test::helper::generate_key::read_fingerprint() {
  local ident req p2
  while read -r ident req _ p2 _; do
    if [[ "$ident" != '[GNUPG:]' ]]; then
      printf 'Unexpected GnuPG interaction: %s\n' "$ident" >&2
      return 1
    fi

    if [[ "$req" == 'KEY_CREATED' ]]; then
      printf '%s\n' "$p2"
      break
    fi
  done || return $?
}

# Generate a key and return its fingerprint on standard output.
test::helper::generate_key() {
  test::assert::test 'GnuPG is set up' -n "${test__gnupghome-}"
  test::assert::success 'key generated' gpg --batch --status-fd 3 --generate-key \
    < <(printf '%s\n' "${TEST__HELPER__GENERATE_KEY__DATA[@]}") \
    3> >(_test::helper::generate_key::read_fingerprint)
  test::assert::success 'fingerprint read' wait $!
}
