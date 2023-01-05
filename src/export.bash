# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/cli.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/document.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/export_revocation_cert.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/export_secret.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/keyring.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/stage_dir.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/ui.bash"
. "$(dirname -- "${BASH_SOURCE[0]}")/verify.bash"

# Create a temporary keyring in the staging directory.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
gpg_hardcopy::export::set_up_keyring() {
  # Copy agent configuration if present to benefit from pinentry settings, etc.
  local gpg_agent_conf="${GNUPGHOME:-$HOME/.gnupg}/gpg-agent.conf"

  GNUPGHOME="$(gpg_hardcopy::stage_dir)/.gnupg" || return $?
  export GNUPGHOME

  if [[ -f "$gpg_agent_conf" ]]; then
    mkdir -p "$GNUPGHOME" || return $?
    cp -- "$gpg_agent_conf" "$GNUPGHOME" || return $?
    printf 'Using existing GPG agent configuration from %s.\n' "$gpg_agent_conf"
  fi
}

# Interactively select a key to export.
#
# Parameters:
# - $1: The parsed CLI arguments in JSON format.
gpg_hardcopy::export::interactive_select_key() {
  local lister='public'
  if gpg_hardcopy::cli::needs_secret_key "$1"; then
    lister='secret'
  fi

  local keys
  keys="$(gpg_hardcopy::keyring::list::$lister)" || return $?

  if jq -e 'length == 0' <<<"$keys" >/dev/null; then
    printf 'No %s keys found.\n' "$lister" >&2
    return 1
  fi

  gpg_hardcopy::ui::printlnf 'Select a key to export:'
  gpg_hardcopy::ui::menu "$keys" || return $?
}

# Build the pages of the PDF document that represent the public key.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The filename of the document to append pages to.
# - $2: A filename to append the public key data to for later verification.
# - $3: The fingerprint of the validated public key to export.
gpg_hardcopy::export::make_public_key() {
  local doc_rst="$1" doc_verify="$2"
  shift 2

  printf 'Exporting public key material.\n'

  gpg_hardcopy::document::reset_page_numbering >>"$doc_rst" || return $?

  cat >>"$doc_rst" <<EOT
.. raw:: latex

   \begin{sloppypar}

This document contains the public key of the PGP key pair with fingerprint
**$1** as seen on the system $(uname -n) on :raw-latex:\`\today\`.

.. raw:: latex

   \end{sloppypar}

To rehydrate the key, save the contents of each of the QR codes (or text
snippets) below, in order, to a single file. The right-hand side of each line
of text is the CRC-32 of that line.

.. raw:: latex

   \vfill

EOT

  gpg --export --armor -- "$1" \
    | tee -a "$doc_verify" \
    | gpg_hardcopy::document::write_data >>"$doc_rst" || return $?
}

# Build the pages of the PDF document for a revocation certificate.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The filename of the document to append pages to.
# - $2: A filename to append the revocation certificate data to for later
#   verification.
# - $3: The fingerprint of the validated secret key to export.
# - $4: An optional key passphrase to pass to the revocation certificate
#   generator.
gpg_hardcopy::export::make_revocation_cert() {
  local doc_rst="$1" doc_verify="$2"
  shift 2

  if [[ $# -gt 1 ]]; then
    printf 'Generating revocation certificate.\n'
  else
    printf 'Generating revocation certificate. Enter your passphrase when prompted.\n'
  fi

  gpg_hardcopy::document::reset_page_numbering >>"$doc_rst" || return $?

  cat >>"$doc_rst" <<EOT
.. raw:: latex

   \begin{sloppypar}

This document contains a revocation certificate for the PGP key pair with
fingerprint **$1**.

.. raw:: latex

   \end{sloppypar}

To rehydrate the certificate, save the contents of each of the QR codes (or
text snippets) below, in order, to a single file. The right-hand side of each
line of text is the CRC-32 of that line.

.. raw:: latex

   \vfill

EOT

  gpg_hardcopy::export_revocation_cert::generate_cert "$@" \
    | tee -a "$doc_verify" \
    | gpg_hardcopy::document::write_data >>"$doc_rst" || return $?
}

# Interactively prompt a user to make sure they understand what they're doing
# when exporting a secret key.
_gpg_hardcopy::export::interactive_secret_key_prompt() {
  gpg_hardcopy::ui::printlnf
  gpg_hardcopy::ui::header 'Exporting secret key packets'
  gpg_hardcopy::ui::prints <<EOT
We are going to export the secret keys from your PGP key pair. Pay close
attention to this section. It contains important information about rehydrating
your key from a physical copy.

PGP keys are stored as a sequence of packets. Public keys contain, for example,
the public key data, signatures, user IDs, user attributes, and several public
subkeys. Secret keys are identical to public keys, except that the public key
material is augmented with secret key material. Therefore, there is a lot of
overlap between the two types of keys physically.

Your public key changes over time. As you add and revoke user IDs, update
expirations, etc., it will take different forms. However, the secret key
packets do not change unless you rotate your subkeys.

For this reason, THIS PROGRAM ONLY EXPORTS THE SECRET KEY AND SECRET SUBKEY
PACKETS. Once you export your secret keys once, you do not need to export them
again. Keep them stored somewhere safe in the event you need to rehydrate your
key.

To rehydrate your full secret key from a physical copy, you will need to:

1. Acquire a copy of your public key. This can be from a physical copy you
   export, but for convenience, you can also simply download it from a
   keyserver.
2. Parse the public key into its constituent packets using a program like
   gpgsplit(1).
3. Replace the public key packets with the corresponding secret key packets
   from your physical copy.
4. Concatenate the packets back together, in order, to produce a valid secret
   key file.

These instructions will be presented in detail on the physical copy of your
secret key should you need them in the future.
EOT
  gpg_hardcopy::ui::printlnf
  gpg_hardcopy::ui::yesno 'Do you understand this information?' || return $?
  gpg_hardcopy::ui::printlnf
}

# Build the pages of the PDF document that represent the secret key.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The filename of the document to append pages to.
# - $2: A filename to append the secret key data to for later verification.
# - $3: The fingerprint of the validated secret key to export.
gpg_hardcopy::export::make_secret_key() {
  local doc_rst="$1" doc_verify="$2"
  shift 2

  if [[ $# -gt 1 ]]; then
    printf 'Exporting secret key material.\n'
  else
    printf 'Exporting secret key material. Enter your passphrase when prompted.\n'
  fi

  gpg_hardcopy::document::reset_page_numbering >>"$doc_rst" || return $?

  cat >>"$doc_rst" <<EOT
.. raw:: latex

   \begin{sloppypar}

This document contains the secret key packets of the PGP key pair with
fingerprint **$1**.

.. raw:: latex

   \end{sloppypar}

Each of the packets below is set off by the packet metadata as GnuPG understood
it at the time of export. To rehydrate the key, you will need to save each
packet to its own file by concatenating the contents of the respective QR codes
(or text snippets) together. The right-hand side of each line of text is the
CRC-32 of that line.

Next, you will need a copy of the public key. Split the public key into its
constituent packets using a program like :code:\`gpgsplit(1)\`. Then replace
the public key and public subkey packets with the corresponding secret key and
secret subkey packets, respectively.

Finally, concatenate all of the packets back together, in order, to produce an
importable secret key.

Here is a Bash program that can perform these steps for you when given a list
of packet files on standard input (one per line)::

  gpg --export -- $(printf '%q' "$1") \\
    | gpgsplit --prefix rehydrate.
  while IFS= read -r packet_file; do
    public_key_hash="\$(
      gpgsplit --no-split --secret-to-public "\$packet_file" \\
        | sha256sum
    )"
    for candidate in rehydrate.*; do
      candidate_hash="\$(sha256sum <"\$candidate")"
      if [[ "\$public_key_hash" == "\$candidate_hash" ]]; then
        mv "\$packet_file" "\$candidate"
        break
      fi
    done
  done
  cat rehydrate.* | gpg --import

.. raw:: latex

   \clearpage

EOT

  local packet_file
  while IFS= read -r -d $'\0' packet_file; do
    gpg_hardcopy::armor::encode <"$packet_file" \
      | tee -a "$doc_verify" \
      | gpg_hardcopy::export_secret::write_packet_to_document >>"$doc_rst" || return $?
  done < <(gpg_hardcopy::export_secret::split_packets "$@")
  wait $! || return $?
}

# Export a key to a file.
#
# Parameters:
# - $1: The parsed CLI arguments in JSON format.
gpg_hardcopy::export::main() {
  local output_file output_fd=
  output_file="$(gpg_hardcopy::cli::get_output_file "$1")" || return $?

  if [[ "$output_file" == '-' ]]; then
    exec {output_fd}>&1

    # Redirect UI IO directly to the TTY, or disable altogether if no TTY is
    # available.
    if ( exec >/dev/tty ) 2>/dev/null; then
      exec >/dev/tty
    else
      exec >/dev/null
    fi
  fi

  if gpg_hardcopy::cli::is_interactive "$1"; then
    gpg_hardcopy::ui::set_up || return $?
    gpg_hardcopy::ui::header 'Loading key'
  fi

  # Create a staging directory.
  gpg_hardcopy::stage_dir::set_up || return $?

  local stage_dir
  stage_dir="$(gpg_hardcopy::stage_dir)" || return $?
  local doc_rst="$stage_dir/export.rst" doc_pdf="$stage_dir/export.pdf" doc_verify="$stage_dir/verify"

  # Select a key if one was not specified. Otherwise, ensure we can access the
  # key.
  local key
  if key="$(gpg_hardcopy::cli::get_key "$1")"; then
    if [[ -f "$key" ]]; then
      printf 'Key is on disk. Importing into a temporary keyring...\n'
      gpg_hardcopy::export::set_up_keyring || return $?
      key="$(gpg_hardcopy::keyring::import_from_file "$key")" || return $?
    fi
  else
    # Guarded by batch check in the CLI parser.
    key="$(gpg_hardcopy::export::interactive_select_key "$1")" || return $?
  fi

  # Quickly verify that the key exists and, if necessary, has all secret
  # material.
  local key_info
  key_info="$(gpg_hardcopy::keyring::key::read "$key")" || return $?
  key="$(gpg_hardcopy::keyring::key::get_fingerprint "$key_info")" || return $?
  printf 'Using key with fingerprint 0x%s.\n' "$key"

  if gpg_hardcopy::cli::needs_secret_key "$1" && ! gpg_hardcopy::keyring::key::has_secret "$key_info"; then
    cat >&2 <<EOT
Key 0x${key} does not have secret key
material available, but we need it to produce the required output. Either
select a different key or a different combination of --export options.
EOT
    return 1
  fi

  # Start building the document.
  gpg_hardcopy::document::get_prelude >"$doc_rst" || return $?

  if gpg_hardcopy::cli::should_export "$1" 'public-key'; then
    if gpg_hardcopy::cli::is_interactive "$1"; then
      gpg_hardcopy::ui::printlnf
      gpg_hardcopy::ui::header 'Exporting public key'
    fi

    gpg_hardcopy::export::make_public_key "$doc_rst" "$doc_verify" "$key" || return $?
  fi

  if gpg_hardcopy::cli::should_export "$1" 'revocation-cert'; then
    local -a make_revocation_cert_args=("$doc_rst" "$doc_verify" "$key")
    local passphrase
    if passphrase="$(gpg_hardcopy::cli::get_passphrase "$1")"; then
      make_revocation_cert_args+=("$passphrase")
    fi

    if gpg_hardcopy::cli::is_interactive "$1"; then
      gpg_hardcopy::ui::printlnf
      gpg_hardcopy::ui::header 'Generating and exporting revocation certificate'
    fi

    gpg_hardcopy::export::make_revocation_cert "${make_revocation_cert_args[@]}" || return $?
  elif gpg_hardcopy::cli::should_export "$1" 'secret-key' && gpg_hardcopy::cli::is_interactive "$1"; then
    gpg_hardcopy::ui::printlnf
    gpg_hardcopy::ui::header 'A note on revocation certificates'
    gpg_hardcopy::ui::prints <<EOT
You are exporting your secret key material but not generating a revocation
certificate. If your key is lost or stolen, you will not be able to prevent a
malicious entity from using it to impersonate you.

If you do not already have one, you should seriously consider generating a
revocation certificate and storing it somewhere safe.

Use GnuPG to generate a file:

  gpg --gen-revoke ${key}

Or make a physical copy and print it:

  $0 \\
    --key=${key} \\
    --export=revocation-cert output.pdf
EOT
  fi

  if gpg_hardcopy::cli::should_export "$1" 'secret-key'; then
    if gpg_hardcopy::cli::is_interactive "$1"; then
      _gpg_hardcopy::export::interactive_secret_key_prompt || return $?
    fi

    local -a make_secret_key_args=("$doc_rst" "$doc_verify" "$key")
    local passphrase
    if passphrase="$(gpg_hardcopy::cli::get_passphrase "$1")"; then
      make_secret_key_args+=("$passphrase")
    fi

    gpg_hardcopy::export::make_secret_key "${make_secret_key_args[@]}" || return $?
  fi

  # Output a PDF file using pandoc.
  if gpg_hardcopy::cli::is_interactive "$1"; then
    gpg_hardcopy::ui::printlnf
    gpg_hardcopy::ui::header 'Creating PDF'
  fi
  (
    cd "$(gpg_hardcopy::stage_dir)" || return $?
    pandoc -f rst \
      -o "$doc_pdf" \
      --pdf-engine=xelatex \
      -V documentclass=extarticle \
      -V monofont:NotoSansMono-Regular.ttf \
      -V fontsize=9pt \
      --embed-resources \
      --standalone \
      "$doc_rst" || return $?
  ) || return $?

  printf 'Wrote PDF file %s in staging directory.\n' "$(basename "$doc_pdf")"

  if gpg_hardcopy::cli::is_interactive "$1"; then
    gpg_hardcopy::ui::printlnf
    gpg_hardcopy::ui::header 'Verifying QR codes'
  fi

  if gpg_hardcopy::verify::from_pdf "$doc_pdf" "$doc_verify"; then
    printf 'Verification succeeded. PDF file content matches input data.\n'
  else
    printf 'Verification failed. Is your version of qrencode(1) out of date?\n' >&2
    return 1
  fi

  if gpg_hardcopy::cli::is_interactive "$1"; then
    gpg_hardcopy::ui::printlnf
    gpg_hardcopy::ui::header 'Finalizing'
  fi

  if [[ -z "$output_fd" ]]; then
    printf 'Copying PDF file to %s.\n' "$output_file"
    exec {output_fd}>"$output_file" || return $?
  else
    printf 'Copying PDF data to output stream.\n'
  fi

  cat "$doc_pdf" >&"$output_fd" || return $?
}
