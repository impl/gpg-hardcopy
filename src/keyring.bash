# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Append a given fingerprint and user ID to a key list and print the output.
#
# Parameters:
# - $1: The key list in JSON format.
# - $2: The fingerprint.
# - $3: The user ID.
_gpg_hardcopy::keyring::list::append_entry() {
  jq \
    --arg fingerprint "$2" \
    --arg uid "$3" \
    '
      . + {
        ($fingerprint): "0x\($fingerprint): \($uid)",
      }
    ' \
    <<<"$1"
}

# Read the list of exportable public keys and print them as a JSON object where
# keys are fingerprints and values are descriptive information.
gpg_hardcopy::keyring::list::public() {
  local keys='{}' current_fingerprint=''
  local -a line
  while IFS=':' read -r -a line; do
    case "${line[0]}" in
      pub)
        current_fingerprint=
        current_uid=
        ;;
      fpr)
        if [[ -z "$current_fingerprint" ]]; then
          current_fingerprint="${line[9]}"
        fi
        ;;
      uid)
        if [[ -n "$current_fingerprint" ]]; then
          keys="$(_gpg_hardcopy::keyring::list::append_entry "$keys" "$current_fingerprint" "${line[9]}")" || return $?
          current_fingerprint=
        fi
        ;;
    esac
  done < <(gpg --batch --with-colons --list-keys)
  wait $! || return $?
  printf '%s\n' "$keys"
}

# Read the list of exportable secret keys and print them as a JSON object where
# keys are fingerprints and values are descriptive information.
gpg_hardcopy::keyring::list::secret() {
  local keys='{}' skip='' current_fingerprint='' current_uid=''
  local -a line
  while IFS=':' read -r -a line; do
    case "${line[0]}" in
      sec)
        if [[ -z "$skip" && -n "$current_fingerprint" && -n "$current_uid" ]]; then
          keys="$(_gpg_hardcopy::keyring::list::append_entry "$keys" "$current_fingerprint" "$current_uid")" || return $?
        fi
        skip=
        current_fingerprint=
        current_uid=
        ;&
      ssb)
        if [[ "${line[14]}" != "+" ]]; then
          skip=1
        fi
        ;;
      fpr)
        if [[ -z "$current_fingerprint" ]]; then
          current_fingerprint="${line[9]}"
        fi
        ;;
      uid)
        if [[ -z "$current_uid" && "${line[1]}" != 'r' ]]; then
          current_uid="${line[9]}"
        fi
        ;;
    esac
  done < <(gpg --batch --with-colons --list-secret-keys)
  wait $! || return $?
  if [[ -z "$skip" && -n "$current_fingerprint" && -n "$current_uid" ]]; then
    keys="$(_gpg_hardcopy::keyring::list::append_entry "$keys" "$current_fingerprint" "$current_uid")" || return $?
  fi
  printf '%s\n' "$keys"
}

# Import a key into the keyring. Prints the fingerprint of the imported key to
# standard output.
#
# Parameters:
# - $1: The path to the key to import.
gpg_hardcopy::keyring::import_from_file() {
  gpg --batch --import "$1" >/dev/null || return $?

  local -a line
  while IFS=':' read -r -a line; do
    case "${line[0]}" in
      fpr)
        printf '%s\n' "${line[9]}"
        break
        ;;
    esac
  done < <(gpg --batch --with-colons --fingerprint --import-options=show-only --import -- "$1")
  wait $! || return $?
}

# Run a command with status and command interaction connected to a given
# function.
#
# Parameters:
# - $1: The name of the function to start.
# - ...: The arguments to the command.
gpg_hardcopy::keyring::interact() {
  local func="$1"
  shift

  coproc "$func"
  local ret=0 pid=$COPROC_PID stdout=${COPROC[0]} stdin=${COPROC[1]}
  { gpg --status-fd=5 --command-fd=6 "$@" 5<&0 6>&1 <&3 >&4 || ret=$?; } 3<&0 4>&1 <&"$stdin" >&"$stdout"
  exec {stdin}>&-
  wait "$pid" || return $?
  return $ret
}

# Read key information from the keyring and print it as a JSON object.
#
# Parameters:
# - $1: The user ID or fingerprint of the key.
gpg_hardcopy::keyring::key::read() {
  local fingerprint='' has_secret=1 is_revoked=''
  local -a line
  while IFS=':' read -r -a line; do
    case "${line[0]}" in
      pub|sub)
        if [[ "${line[1]}" == 'r'* ]]; then
          is_revoked=1
        fi
        if [[ "${line[14]}" != "+" ]]; then
          has_secret=
        fi
        ;;
      fpr)
        if [[ -z "$fingerprint" ]]; then
          fingerprint="${line[9]}"
        fi
        ;;
    esac
  done < <(gpg --batch --with-colons --with-secret --fingerprint --list-keys "$1")
  wait $! || return $?
  jq -n \
    --arg fingerprint "$fingerprint" \
    --arg has_secret "$has_secret" \
    --arg is_revoked "$is_revoked" \
    '
      {
        fingerprint: $fingerprint,
        has_secret: ($has_secret == "1"),
        is_revoked: ($is_revoked == "1"),
      }
    ' || return $?
}

# Print the fingerprint of the given key to standard output.
#
# Parameters:
# - $1: The JSON object returned by gpg_hardcopy::keyring::key::read.
gpg_hardcopy::keyring::key::get_fingerprint() {
  jq -r '.fingerprint' <<<"$1"
}

# Return 0 if we have the secret material for a given key, 1 if not.
#
# Parameters:
# - $1: The JSON object returned by gpg_hardcopy::keyring::key::read.
gpg_hardcopy::keyring::key::has_secret() {
  jq -e '.has_secret' >/dev/null <<<"$1" || false
}

# Return 0 if the key is revoked, 1 if not.
#
# Parameters:
# - $1: The JSON object returned by gpg_hardcopy::keyring::key::read.
gpg_hardcopy::keyring::key::is_revoked() {
  jq -e '.is_revoked' >/dev/null <<<"$1" || false
}
