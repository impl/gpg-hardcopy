# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/export_revocation_cert.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/keyring.bash"

test::case::export_revocation_cert::generate_cert() {
  test::helper::set_up_gpg

  local key
  key="$(test::helper::generate_key)"

  test::assert::success 'generate revocation certificate' gpg_hardcopy::export_revocation_cert::generate_cert "$key" 'test' \
    | test::assert::success 'import revocation certificate' gpg --import

  local key_info
  key_info="$(test::assert::success 'read key information' gpg_hardcopy::keyring::key::read "$key")"
  test::assert::success 'key is revoked' gpg_hardcopy::keyring::key::is_revoked "$key_info"
}
