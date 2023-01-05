# SPDX-FileCopyrightText: 2023 Noah Fontes
#
# SPDX-License-Identifier: Apache-2.0

. "$(dirname -- "${BASH_SOURCE[0]}")/stage_dir.bash"

# Generate the file header for the output document.
gpg_hardcopy::document::get_prelude() {
  cat <<'EOT'
.. role:: raw-latex(raw)
   :format: latex

.. raw:: latex

   \newlength{\ctt}
   \settowidth{\ctt}{\texttt{0}}
   \pagenumbering{arabic}

EOT
}

gpg_hardcopy::document::reset_page_numbering() {
  cat <<'EOT'
.. raw:: latex

   \setcounter{page}{1}

EOT
}

# Given printable data on standard input, produce pages of reStructrucuredText
# suitable to be converted to a PDF, including a QR code and checksums of each
# line.
#
# Preconditions:
# - gpg_hardcopy::stage_dir::set_up has been called.
gpg_hardcopy::document::write_data() {
  local work_dir
  work_dir="$(mktemp --tmpdir="$(gpg_hardcopy::stage_dir)" --directory document.XXXXXXXX)" || return $?

  # There's a bug in pandoc where evidently image filenames need to be globally
  # unique, so prepend the work directory to the image filename.
  local part_prefix
  part_prefix="part.$(basename "$work_dir")." || return $?

  split --hex-suffixes --suffix-length=4 --lines=16 - "$work_dir/$part_prefix" || return $?
  for part in "$work_dir/part."*; do
    local part_qr="$part.svg" part_checksum="$part.crc32"
    qrencode --8bit --level H --symversion 40 \
      --type SVG --output "$part_qr" \
      --read-from "$part" \
      --margin 0 || return $?
    awk \
      '
        {
          print |& "cksum";
          close("cksum", "to");
          "cksum" |& getline;
          close("cksum");
          printf("%08x\n", $1);
        }
      ' "$part" >"$part_checksum" || return $?

    cat <<EOT
.. raw:: latex

   \begin{center}

.. image:: $(gpg_hardcopy::stage_dir::relative_path "$part_qr")
   :width: 60%

.. raw:: latex

   \end{center}
   \vspace{2\baselineskip}
   \begin{minipage}[t]{\dimexpr \linewidth-8\ctt}

.. include:: $(gpg_hardcopy::stage_dir::relative_path "$part")
   :code:

.. raw:: latex

   \end{minipage}
   \begin{minipage}[t]{8\ctt}

.. include:: $(gpg_hardcopy::stage_dir::relative_path "$part_checksum")
   :code:

.. raw:: latex

   \end{minipage}
   \clearpage

EOT
  done
}
