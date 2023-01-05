# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/armor.bash"
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

  gpg_hardcopy::keyring::export_secret_key "$@" \
    | (cd "$packets_dir"; gpgsplit) || return $?

  find "$packets_dir" -type f -name '*-00[57].*' -print0
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
