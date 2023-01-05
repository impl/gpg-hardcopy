# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/armor.bash"

test::case::armor::encode() {
  local encoded
  encoded="$(printf 'fo\x00o\n' | test::assert::success 'encode string' gpg_hardcopy::armor::encode)"

  local expected=$'-----BEGIN PGP MESSAGE-----\n\nZm8Abwo=\n=WTdd\n-----END PGP MESSAGE-----'
  test::assert::if 'encodes identically to gpg --enarmor' == "$expected" "$encoded"
}

test::case::armor::encode::with_key() {
  test::helper::set_up_gpg

  local key
  key="$(test::helper::generate_key)"

  local expected
  expected="$(gpg --armor --batch --pinentry-mode loopback --passphrase-fd 0 --export-secret-keys -- "$key" <<<'test')"

  local encoded
  encoded="$(test::assert::success 'encode string' gpg_hardcopy::armor::encode 'PGP PRIVATE KEY BLOCK' < <(gpg --dearmor <<<"$expected"))"

  test::assert::if 'encodes identically to gpg --armor' == "$expected" "$encoded"
}
