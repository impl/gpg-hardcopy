# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Compute the CRC24 checksum of a given input and write the packed binary output
# to standard output.
#
# See https://www.rfc-editor.org/rfc/rfc4880#section-6.1 for the algorithm used
# here.
_gpg_hardcopy::armor::crc24() {
  local crc24='0xb704ce' char char_ord
  while LANG=C IFS= read -r -n 1 -d '' char; do
    char_ord=$(printf '%d' "'$char")
    ((crc24 ^= char_ord << 16))
    local i
    for ((i = 0; i < 8; i++)); do
      ((crc24 <<= 1))
      if ((crc24 & 0x1000000)); then
        ((crc24 ^= 0x1864cfb))
      fi
    done
  done
  ((crc24 &= 0xffffff))

  local packed_crc24
  printf -v packed_crc24 '\\x%02x\\x%02x\\x%02x' $((crc24 >> 16)) $((crc24 >> 8 & 0xff)) $((crc24 & 0xff))
  printf '%b' "$packed_crc24"
}

# Convert standard input to standard output using the PEM-like OpenPGP ASCII
# armor encoding. The input should be a PGP packet.
#
# Parameters:
# - $1: The PEM-style label, defaulting to "PGP MESSAGE".
#
# shellcheck disable=SC2120
gpg_hardcopy::armor::encode() {
  local label="${1:-PGP MESSAGE}"

  local stdout_fd
  exec {stdout_fd}>&1

  printf -- '-----BEGIN %s-----\n\n' "$label"

  local checksum
  checksum="$(
    tee >(base64 --wrap=64 >&"$stdout_fd") \
      | _gpg_hardcopy::armor::crc24 \
      | base64 --wrap=64
  )" || return $?
  printf '=%s\n' "$checksum"

  printf -- '-----END %s-----\n' "$label"
  exec {stdout_fd}>&-
}
