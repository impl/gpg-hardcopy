# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Print the full usage string to standard output.
gpg_hardcopy::help::main() {
  cat <<EOT
usage: $0 [options] <output-file>

Encodes portions of a PGP private key as a series of QR codes and nicely
formats a PDF file with them.

Arguments:

  <output-file>
    The name of the PDF file to generate. If the file name is a dash (-), the
    contents of the PDF will be written to standard output.

Options:

  --batch
  --no-batch
    Change behavior of prompting for confirmation or missing options before
    generating the PDF file. This is useful when running in a non-interactive
    environment. The batch mode will be inferred when no TTY is present; you
    can use --no-batch to override this default.

  --export COMPONENT[,COMPONENT[,...]]
    A list of components of the key to encode, separated by spaces or commas.
    This option may be specified multiple times. The default is to encode only
    public keys.

    Available components:
      public-key
        The public key of the key pair.
      revocation-cert
        A revocation certificate for the key pair.
      secret-key
        The secret key of the key pair.

  --help
    Show this help message and exit.

  --key USER-ID|FINGERPRINT|FILE
    The user ID, fingerprint, or file name of the key to export. If --export
    specifies the secret-key or revocation-cert component, the key made
    available by this option must be the secret key; otherwise, a public key
    will suffice.

    If the value is a file name, the file may either be a key in RFC 4880
    binary format or an ASCII-armored version.

  --passphrase-fd FD
    The file descriptor from which to read the passphrase for the secret key.
    If this option is not specified, the passphrase will be read using the
    configured pinentry program, or interactively on standard input if the
    pinentry mode is loopback. When run in batch mode, if this option is not
    specified, we will assume the key has an empty passphrase.

Environment variables:

  TMPDIR
    The temporary directory to use for staging the output document. For added
    security, you may want to use a directory on a ramfs filesystem.
EOT
}
