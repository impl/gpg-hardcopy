# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/cli.bash"

test::case::cli::parse_args::help() {
  local args
  args="$(test::assert::success 'help mode' gpg_hardcopy::cli::parse_args --help)"

  local mode
  mode="$(test::assert::success 'get mode from args' gpg_hardcopy::cli::get_mode "$args")"
  test::assert::if 'mode is "help"' == 'help' "$mode"
}

test::case::cli::parse_args::batch() {
  local args
  args="$(test::assert::success 'export in batch mode' gpg_hardcopy::cli::parse_args --batch --key=ABCD1234 output.pdf)"

  local mode
  mode="$(test::assert::success 'get mode from args' gpg_hardcopy::cli::get_mode "$args")"
  test::assert::if 'mode is "export"' == 'export' "$mode"

  test::assert::status 'not interactive' -eq 1 \
    gpg_hardcopy::cli::is_interactive "$args"

  local key
  key="$(test::assert::success 'get key from args' gpg_hardcopy::cli::get_key "$args")"
  test::assert::if 'key is "ABCD1234"' == 'ABCD1234' "$key"

  test::assert::status 'should export public key' -eq 0 \
    gpg_hardcopy::cli::should_export "$args" 'public-key'
  test::assert::status 'should not export secret key' -eq 1 \
    gpg_hardcopy::cli::should_export "$args" 'secret-key'
  test::assert::status 'should not export revocation certificate' -eq 1 \
    gpg_hardcopy::cli::should_export "$args" 'revocation-cert'
}

test::case::cli::get_passphrase::interactive() {
  local args
  args="$(test::assert::success 'export without passphrase' gpg_hardcopy::cli::parse_args --no-batch --key=ABCD1234 output.pdf)"
  test::assert::status 'no passphrase specified' -eq 1 gpg_hardcopy::cli::get_passphrase "$args" >/dev/null

  args="$(test::assert::success 'export with passphrase' gpg_hardcopy::cli::parse_args --no-batch --key=ABCD1234 --passphrase-fd=3 output.pdf 3<<<'test')"
  local passphrase
  passphrase="$(test::assert::success 'get passphrase from args' gpg_hardcopy::cli::get_passphrase "$args")"
  test::assert::if 'passphrase is "test"' == 'test' "$passphrase"

  args="$(test::assert::success 'export with empty passphrase' gpg_hardcopy::cli::parse_args --no-batch --key=ABCD1234 --passphrase-fd=3 output.pdf 3<<<'')"
  passphrase="$(test::assert::success 'get passphrase from args' gpg_hardcopy::cli::get_passphrase "$args")"
  test::assert::test 'passphrase is empty' -z "$passphrase"
}

test::case::cli::get_passphrase::batch() {
  local args passphrase
  args="$(test::assert::success 'export without passphrase' gpg_hardcopy::cli::parse_args --batch --key=ABCD1234 output.pdf)"
  passphrase="$(test::assert::success 'get passphrase from args' gpg_hardcopy::cli::get_passphrase "$args")"
  test::assert::test 'passphrase is empty' -z "$passphrase"

  args="$(test::assert::success 'export with passphrase' gpg_hardcopy::cli::parse_args --batch --key=ABCD1234 --passphrase-fd=3 output.pdf 3<<<'test')"
  passphrase="$(test::assert::success 'get passphrase from args' gpg_hardcopy::cli::get_passphrase "$args")"
  test::assert::if 'passphrase is "test"' == 'test' "$passphrase"

  args="$(test::assert::success 'export with empty passphrase' gpg_hardcopy::cli::parse_args --batch --key=ABCD1234 --passphrase-fd=3 output.pdf 3<<<'')"
  passphrase="$(test::assert::success 'get passphrase from args' gpg_hardcopy::cli::get_passphrase "$args")"
  test::assert::test 'passphrase is empty' -z "$passphrase"
}
