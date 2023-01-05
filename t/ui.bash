# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/framework.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/../src/ui.bash"

test::case::ui::menu::select_default() {
  gpg_hardcopy::ui::set_up <<<$'\n' >/dev/null

  local selected
  selected="$(
    test::assert::status 'responds to enter key' -eq 0 \
      gpg_hardcopy::ui::menu '{"a": "b", "c": "d"}'
  )"
  test::assert::if 'selected item is "a"' == a "$selected"
}

test::case::ui::menu::move_down() {
  gpg_hardcopy::ui::set_up <<<$'\e[A\e[B\e\B\e[B\n' >/dev/null

  local selected
  selected="$(
    test::assert::status 'responds to enter key' -eq 0 \
      gpg_hardcopy::ui::menu '{"a": "b", "c": "d"}'
  )"
  test::assert::if 'selected item is "c"' == c "$selected"
}
