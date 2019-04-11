# kindle-staff
Generates guitar staff for E-book with LaTeX and Lilypond from open database www.jellynote.com

## Dependencies
libdbd-sqlite3-perl libtk-tablematrix-perl perl-tk latex lilypond

See `deps.txt`

*LaTeX* and *Lilypond* commands are required to build PDF.

## Usage

Double click on artist, song and finally, song variant rows then wait for PDF to compile.

## Pack to standalone exe

Install `cpan -i PAR::Packer`

`pp browse.pl -o browse.exe`
