# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/stage_dir.bash"

test::case::stage_dir() {
  (
    gpg_hardcopy::stage_dir::set_up

    stage_dir="$(gpg_hardcopy::stage_dir)"

    test::assert::test 'staging directory value is not empty' \
      -n "$stage_dir"
    test::assert::test 'staging directory exists' \
      -d "$stage_dir"
  )

  test::assert::test 'staging directory removed' \
    -n "$(find "$TMPDIR" -maxdepth 0 -type d -empty)"
}

test::case::stage_dir::not_set_up() {
  test::assert::status 'staging directory not set up' -eq 2 \
    gpg_hardcopy::stage_dir
}
