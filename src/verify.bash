# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

# Check the contents of a PDF file containing a series of QR codes.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
#
# Parameters:
# - $1: The name of the PDF file to check.
# - $2: The name of the file containing the expected contents.
gpg_hardcopy::verify::from_pdf() {
  local work_dir
  work_dir="$(mktemp --tmpdir="$(gpg_hardcopy::stage_dir)" --directory verify.XXXXXXXX)" || return $?

  convert -strip -density 150 "$1" "$work_dir/verify-%04x.png" || return $?
  for img in "$work_dir/verify-"*.png; do
    zbarimg --quiet --oneshot --raw -Sdisable -Sqrcode.enable "$img" >>"$work_dir/data" || [[ $? -eq 4 ]] || return $?
  done

  diff -upbNr "$2" "$work_dir/data" >&2 || return $?
}
