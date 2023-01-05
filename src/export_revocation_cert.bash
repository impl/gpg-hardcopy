# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/armor.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/ui.bash"

# Interact with the GnuPG process to generate a revocation certificate.
_gpg_hardcopy::export_revocation_cert::interactive_generate_cert() {
  local ident req rest
  while read -r ident req rest; do
    if [[ "$ident" != '[GNUPG:]' ]]; then
      printf 'Unexpected GnuPG interaction: %s\n' "$ident" >&2
      return 1
    fi

    case "$req" in
      GOT_IT|INQUIRE_MAXLEN|KEY_CONSIDERED|NEED_PASSPHRASE|PINENTRY_LAUNCHED|USERID_HINT)
        ;;
      GET_BOOL)
        case "$rest" in
          gen_revoke.okay|ask_revocation_reason.okay)
            printf 'Y\n'
            ;;
          *)
            printf 'Unexpected GnuPG GET_BOOL request: %s\n' "$rest" >&2
            return 1
            ;;
        esac
        ;;
      GET_HIDDEN)
        case "$rest" in
          passphrase.enter)
            gpg_hardcopy::ui::hidden 'Enter passphrase' || return $?
            ;;
          *)
            printf 'Unexpected GnuPG GET_HIDDEN request: %s\n' "$rest" >&2
            return 1
            ;;
        esac
        ;;
      GET_LINE)
        case "$rest" in
          ask_revocation_reason.code)
            printf '1\n'
            ;;
          ask_revocation_reason.text)
            printf '\n'
            ;;
          *)
            printf 'Unexpected GnuPG GET_LINE request: %s\n' "$rest" >&2
            return 1
            ;;
        esac
        ;;
      *)
        printf 'Unexpected GnuPG request: %s\n' "$req" >&2
        return 1
        ;;
    esac
  done || return $?
}

# Generate a revocation certificate for the given key and return it on standard
# output.
#
# Parameters:
# - $1: The fingerprint of a valid secret key.
# - $2: An optional passphrase for the key, if operating in a non-interactive
#   mode. If the key is not protected by a passphrase, you may pass the empty
#   string.
_gpg_hardcopy::export_revocation_cert::generate_cert_batch() (
  local -a gpg_args_extra=()
  if [[ -n ${2+defined} ]]; then
    local passphrase
    exec {passphrase}< <(printf '%s\n' "$2")
    gpg_args_extra+=(
      --pinentry-mode=loopback
      --passphrase-fd="$passphrase"
    )
  fi
  coproc _gpg_hardcopy::export_revocation_cert::interactive_generate_cert
  local ret=0 pid=$COPROC_PID stdout=${COPROC[0]} stdin=${COPROC[1]}
  { gpg --no-tty --status-fd=5 --command-fd=6 "${gpg_args_extra[@]}" --gen-revoke -- "$1" 5<&0 6>&1 <&3 >&4 || ret=$?; } 3<&0 4>&1 <&"$stdin" >&"$stdout"
  exec {stdin}>&-
  wait "$pid" || return $?
  return $ret
)

# Generate an ASCII-armored revocation certificate for a secret key.
#
# Parameters:
# - $1: The fingerprint of a valid secret key.
# - $2: An optional passphrase for the key, if operating in a non-interactive
#   mode. If the key is not protected by a passphrase, you may pass the empty
#   string.
gpg_hardcopy::export_revocation_cert::generate_cert() {
  _gpg_hardcopy::export_revocation_cert::generate_cert_batch "$@" \
    | gpg --dearmor \
    | gpg_hardcopy::armor::encode 'PGP PUBLIC KEY BLOCK' \
    || return $?
}
