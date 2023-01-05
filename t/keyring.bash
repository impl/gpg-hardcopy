# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/keyring.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/stage_dir.bash"

test::case::keyring::list::secret() {
  test::helper::set_up_gpg

  local keys
  keys="$(test::assert::success 'secrets in an empty keyring' gpg_hardcopy::keyring::list::secret)"
  test::assert::jq_filter 'no secrets' 'length == 0' <<<"$keys"

  local key
  key="$(test::helper::generate_key)"

  keys="$(test::assert::success 'secret key is available' gpg_hardcopy::keyring::list::secret)"
  test::assert::jq_filter 'one secret' 'length == 1' <<<"$keys"
  test::assert::jq_filter 'secret key has the correct fingerprint' --arg key "$key" '.[$key]' <<<"$keys"
  test::assert::jq_filter 'secret key contains the generated user ID' '.[] | select(contains("Test User"))' <<<"$keys"
}

test::case::keyring::key() {
  test::helper::set_up_gpg

  local key
  key="$(test::helper::generate_key)"

  local key_info
  key_info="$(test::assert::success 'read key information' gpg_hardcopy::keyring::key::read "$key")"

  test::assert::success 'key has secret' gpg_hardcopy::keyring::key::has_secret "$key_info"
  test::assert::status 'key is not revoked' -eq 1 gpg_hardcopy::keyring::key::is_revoked "$key_info"

  local fingerprint
  fingerprint="$(test::assert::success 'get fingerprint' gpg_hardcopy::keyring::key::get_fingerprint "$key_info")"
  test::assert::if 'fingerprint is correct' == "$key" "$fingerprint"
}
