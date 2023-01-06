# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Read program options and arguments. The options will be printed to standard
# output in JSON format.
#
# Parameters:
# - ...: Options and arguments to parse.
gpg_hardcopy::cli::parse_args() {
  if getopt --test >/dev/null || [[ $? != 4 ]]; then
    cat >&2 <<EOT
You need a version of getopt(1) that supports long options.
EOT
    return 1
  fi

  local opts
  opts="$(getopt --options e:hk: --longoptions batch,export:,help,key:,no-batch,passphrase-fd: --name "$0" -- "$@")" || {
    cat >&2 <<EOT

You didn't provide valid command-line arguments. Try running with --help to see
available options.
EOT
    return 1
  }

  eval set -- "$opts"

  local batch='' key='' mode='export' output_file='' passphrase
  local -a exports=()

  if [[ ! -t 0 ]]; then
    batch=1
  fi

  while :; do
    case "$1" in
      --batch)
        batch=1
        shift
        ;;
      --no-batch)
        batch=
        shift
        ;;
      --export|-e)
        local -a export_opts
        IFS=', ' read -r -a export_opts <<<"$2" || return $?
        for export_opt in "${export_opts[@]}"; do
          case "$export_opt" in
            public-key|revocation-cert|secret-key)
              ;;
            *)
              cat >&2 <<EOT
$0: value $(printf "%q" "${export_opt}") of option '$1' is not acceptable

We only support the following values for this option:
  public-key
  revocation-cert
  secret-key

You may separate multiple values with a space or a comma.
EOT
              return 1
              ;;
          esac
        done
        exports+=("${export_opts[@]}")
        shift 2
        ;;
      --help|-h)
        mode=help
        shift
        break
        ;;
      --key|-k)
        key="$2"
        shift 2
        ;;
      --passphrase-fd)
        passphrase="$(cat <&"$2")" || return $?
        shift 2
        ;;
      --)
        shift
        break
        ;;
    esac
  done

  local obj
  obj="$(jq -n --arg mode "$mode" '{mode: $mode}')" || return $?

  case "$mode" in
    export)
      # If no --export options were specified, default to exporting the public key.
      if [[ ${#exports[@]} -eq 0 ]]; then
        exports+=('public-key')
      fi

      # If --batch is specified, we need a key to export.
      if [[ -n "$batch" && -z "$key" ]]; then
        cat >&2 <<EOT
$0: value required for option '--key'

You must specify a key to export when running in batch mode.
EOT
        return 1
      fi

      case "$#" in
        0)
          cat >&2 <<EOT
$0: required positional argument

You must specify the name of the file to write the PDF content to.
EOT
          return 1
          ;;
        1)
          if [[ -z "$1" ]]; then
            cat >&2 <<EOT
$0: value required for positional argument

You must specify the name of the file to write the PDF content to.
EOT
            return 1
          fi
          output_file="$1"
          ;;
        *)
          cat >&2 <<EOT
$0: unexpected positional arguments

Try running with --help to see available options.
EOT
          return 1
          ;;
      esac

      obj="$(
        jq \
          --arg batch "$batch" \
          --slurpfile exports <(printf '%s\n' "${exports[@]}" | jq -R) \
          --arg key "$key" \
          --arg output_file "$output_file" \
          --arg has_passphrase "${passphrase+1}" \
          --arg passphrase "${passphrase:-}" \
          '
            . + {
              batch: ($batch == "1"),
              exports: $exports,
              key: (if $key == "" then null else $key end),
              output_file: $output_file,
              passphrase: (if $has_passphrase == "1" then $passphrase else null end),
            }
          ' \
          <<<"$obj"
      )" || return $?
      ;;
    help)
      ;;
    *)
      cat >&2 <<EOT
In ${FUNCNAME[0]}:
  Unimplemented CLI mode: $mode.
EOT
      return 2
      ;;
  esac

  printf '%s\n' "$obj"
}

# Given the JSON output of gpg_hardcopy::cli::parse_args, print the value of the
# given option.
#
# Parameters:
# - $1: The arguments in JSON format.
# - $2: The name of the argument to print.
gpg_hardcopy::cli::get_scalar_arg() {
  jq -r --arg option "$2" '.[$option] // empty' <<<"$1"
}

# Get the mode of operation specified in the given arguments.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::get_mode() {
  gpg_hardcopy::cli::get_scalar_arg "$1" mode
}

# Returns 0 if in interactive mode, 1 if in batch mode.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::is_interactive() {
  [[ "$(gpg_hardcopy::cli::get_scalar_arg "$1" batch)" != 'true' ]]
}

# Get the key specified in the given arguments, if present. Returns 0 if the key
# is available and 1 if not.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::get_key() {
  local key
  key="$(gpg_hardcopy::cli::get_scalar_arg "$1" key)" || return $?
  if [[ -n "$key" ]]; then
    printf '%s\n' "$key"
  else
    return 1
  fi
}

# Get the output file specified in the given arguments, if present. Returns 0 if
# the key is available and 1 if not.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::get_output_file() {
  local output_file
  output_file="$(gpg_hardcopy::cli::get_scalar_arg "$1" output_file)" || return $?
  if [[ -n "$output_file" ]]; then
    printf '%s\n' "$output_file"
  else
    return 1
  fi
}

# Determine whether a particular export type has been requested. Returns 0 if
# the component should be exported, 1 if not.
#
# Parameters:
# - $1: The arguments in JSON format.
# - $2: The name of the component to check.
gpg_hardcopy::cli::should_export() {
  jq -e --arg component "$2" '.exports | index($component) | type == "number" // false' >/dev/null <<<"$1" || false
}

# Returns 0 if we need a secret key to work, 1 if not.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::needs_secret_key() {
  gpg_hardcopy::cli::should_export "$1" 'secret-key' || gpg_hardcopy::cli::should_export "$1" 'revocation-cert'
}

# Prints the passphrase for the given key to standard output if available.
#
# If not passphrase was provided and we're in batch mode, print an empty string.
# Otherwise, returns 1.
#
# Parameters:
# - $1: The arguments in JSON format.
gpg_hardcopy::cli::get_passphrase() {
  jq -e -r '.passphrase // (if .batch then "" else empty end)' <<<"$1" || false
}
