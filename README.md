<!--
SPDX-FileCopyrightText: 2023 Noah Fontes

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->

# gpg-hardcopy

gpg-hardcopy is a program to export your PGP key pairs to a nicely formatted printable PDF file. It supports three types of exports:

* Public keys
* Revocation certificates
* Secret keys

## Installation

The Nix flake in this repository provides a package for the program.

## Running

The supported way to run gpg-hardcopy outside of NixOS is using the [`nix run` command](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-run.html):

```
nix run github:impl/gpg-hardcopy -- --help
```

To interactively export each available component of a key pair to the file `export.pdf`:

```
nix run github:impl/gpg-hardcopy -- --export=public-key,revocation-cert,secret-key export.pdf
```
