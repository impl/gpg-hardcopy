# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/armor.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/keyring.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/stage_dir.bash"

# Print the secret key directory to standard output.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
gpg_hardcopy::export_secret::secret_key_dir() {
  local secret_key_dir
  secret_key_dir="$(gpg_hardcopy::stage_dir)/secret-key"

  mkdir -p "$secret_key_dir" || return $?
  printf '%s\n' "$secret_key_dir" || return $?
}

# Interact with the GnuPG process to provide a passphrase for secret export.
_gpg_hardcopy::export_secret::interactive_export() {
  local ident req rest
  while read -r ident req rest; do
    if [[ "$ident" != '[GNUPG:]' ]]; then
      printf 'Unexpected GnuPG interaction: %s\n' "$ident" >&2
      return 1
    fi

    case "$req" in
      EXPORT_RES|EXPORTED|GOT_IT|INQUIRE_MAXLEN|KEY_CONSIDERED|NEED_PASSPHRASE|PINENTRY_LAUNCHED|USERID_HINT)
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
      *)
        printf 'Unexpected GnuPG request: %s\n' "$req" >&2
        return 1
        ;;
    esac
  done || return $?
}

# Export the secret key from a keyring to standard output.
#
# Parameters:
# - $1: The fingerprint of the key to export.
# - $2: An optional passphrase to use to unlock the key.
gpg_hardcopy::export_secret::export() (
  local -a gpg_args_extra=()
  if [[ -n ${2+defined} ]]; then
    local passphrase
    exec {passphrase}< <(printf '%s\n' "$2")
    gpg_args_extra+=(
      --pinentry-mode=loopback
      --passphrase-fd="$passphrase"
    )
  fi

  gpg_hardcopy::keyring::interact _gpg_hardcopy::export_secret::interactive_export \
    --batch "${gpg_args_extra[@]}" --export-secret-keys -- "$1" || return $?
)

# Export a secret key to the staging directory and split it into packets. Prints
# the list of relevant packet filenames to standard output, NUL-byte separated.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The fingerprint of the validated secret key to export.
# - $2: An optional key passphrase to pass to the key exporter.
gpg_hardcopy::export_secret::split_packets() {
  local packets_dir
  packets_dir="$(gpg_hardcopy::export_secret::secret_key_dir)/packets" || return $?

  mkdir -p "$packets_dir" || return $?

  gpg_hardcopy::export_secret::export "$@" \
    | (cd "$packets_dir"; gpgsplit) || return $?

  find "$packets_dir" -type f -name '*-00[57].*' -print0 | sort -z || return $?
}

# Render an ASCII-armored packet from standard input to document pages on
# standard output.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
gpg_hardcopy::export_secret::write_packet_to_document() {
  local encoded_packet
  encoded_packet="$(cat)" || return $?

  # Verify we can decode the packet.
  gpg --dearmor <<<"$encoded_packet" >/dev/null || return $?

  # Export packet metadata.
  local packet_metadata
  packet_metadata="$(mktemp --tmpdir="$(gpg_hardcopy::export_secret::secret_key_dir)" metadata.XXXXXXXX)" || return $?
  gpg --list-packets <<<"$encoded_packet" >"$packet_metadata" || return $?

  cat <<EOT
.. include:: $(gpg_hardcopy::stage_dir::relative_path "$packet_metadata")
   :code:

.. raw:: latex

   \vfill

EOT

  gpg_hardcopy::document::write_data <<<"$encoded_packet" || return $?
}
