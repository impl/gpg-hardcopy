# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Open the UI subsystem by attaching unique file descriptors to standard input
# and output.
gpg_hardcopy::ui::set_up() {
  declare -g gpg_hardcopy__ui__in_fd gpg_hardcopy__ui__out_fd
  if [[ -z "${gpg_hardcopy__ui__in_fd-}" ]]; then
    exec {gpg_hardcopy__ui__in_fd}<&0 || return $?
  fi
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    exec {gpg_hardcopy__ui__out_fd}>&1 || return $?
  fi
}

# Print an aribtrary message read from standard input using the UI's output file
# descriptor.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
gpg_hardcopy::ui::prints() {
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  UI subsystem not set up! Did you forget to call gpg_hardcopy::ui::set_up?
EOT
    return 2
  fi

  cat >&"$gpg_hardcopy__ui__out_fd"
}

# Print an arbitrary message using the UI's output file descriptor.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: The message to print.
# - ...: Additional arguments to printf.
gpg_hardcopy::ui::printf() {
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  UI subsystem not set up! Did you forget to call gpg_hardcopy::ui::set_up?
EOT
    return 2
  fi

  if [[ $# -gt 0 ]]; then
    # shellcheck disable=SC2059
    printf "$@" >&"$gpg_hardcopy__ui__out_fd" || return $?
  fi
}

# Print a message using the UI's output file descriptor, followed by a newline.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: The message to print.
# - ...: Additional arguments to printf.
gpg_hardcopy::ui::printlnf() {
  gpg_hardcopy::ui::printf "$@" || return $?
  gpg_hardcopy::ui::printf '\n' || return $?
}

# Print a nice header.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: The header string.
gpg_hardcopy::ui::header() {
  gpg_hardcopy::ui::printlnf '\e[1m%s\e[0m\n' "$1" || return $?
}

# Print a menu of options and prompt the user to select one on UI input. The
# selected option key will be printed to standard output.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: A JSON object of key-value pairs for the options.
gpg_hardcopy::ui::menu() {
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  UI subsystem not set up! Did you forget to call gpg_hardcopy::ui::set_up?
EOT
    return 2
  fi

  local selected=0 count
  count="$(jq 'length' <<<"$1")" || return $?

  while :; do
    jq -r --argjson selected "$selected" \
      '
        [.[]]         # Get values of the object.
        | to_entries  # Add index.
        | map(
            if .key == $selected then
              "> \u001b[7m\(.value)\u001b[0m"
            else
              "  \(.value)"
            end
          )           # Nicely format the menu.
        | .[]         # Print each line.
      ' \
      >&"$gpg_hardcopy__ui__out_fd" <<<"$1" || return $?

    local key
    read -r -s -n 3 key <&"$gpg_hardcopy__ui__in_fd" || return $?
    case "$key" in
      $'\e[A')
        if (( selected > 0 )); then
          ((selected--)) || :
        fi
        ;;
      $'\e[B')
        if (( selected < count - 1 )); then
          ((selected++)) || :
        fi
        ;;
      '')
        break
        ;;
    esac
    printf '\e[%dA' "$count" >&"$gpg_hardcopy__ui__out_fd" || return $?
  done

  jq -r --argjson selected "$selected" \
    '
      to_entries        # Convert to an array of key-value pairs.
      | nth($selected)  # Pluck the selected entry from the array.
      | .key            # Get the key.
    ' \
    <<<"$1" || return $?
}

# Prompt a user for a hidden text string on UI input.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: The prompt to display.
gpg_hardcopy::ui::hidden() {
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  UI subsystem not set up! Did you forget to call gpg_hardcopy::ui::set_up?
EOT
    return 2
  fi

  local resp
  IFS= read -r -e -s -p "$1: " resp <&"$gpg_hardcopy__ui__in_fd" >&"$gpg_hardcopy__ui__out_fd" || return $?
  printf '%s\n' "$resp"
}

# Prompt a user with a yes/no question on UI input. The user's response
# determines the exit status of the function: 0 for yes, 1 for no.
#
# Preconditions:
# - gpg_hardcopy::ui::set_up has been called.
#
# Parameters:
# - $1: The question to ask.
gpg_hardcopy::ui::yesno() {
  if [[ -z "${gpg_hardcopy__ui__out_fd-}" ]]; then
    cat >&2 <<EOT
In ${FUNCNAME[0]}:
  UI subsystem not set up! Did you forget to call gpg_hardcopy::ui::set_up?
EOT
    return 2
  fi

  local resp
  IFS= read -r -e -p "$1 [y/N]: " resp <&"$gpg_hardcopy__ui__in_fd" >&"$gpg_hardcopy__ui__out_fd" || return $?
  case "$resp" in
    [yY][eE][sS]|[yY])
      ;;
    *)
      return 1
      ;;
  esac
}
