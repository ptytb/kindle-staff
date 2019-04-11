#!/usr/bin/perl

use Modern::Perl 2012;
use strict;
use warnings;
use utf8;

use MIME::Base64;
use IO::Uncompress::Bunzip2;
use DBI;
use Template;
use Data::Dumper;

use File::Path qw(remove_tree);
use File::Copy;

my $instruments = {
     1	 => "acoustic grand",
     2	 => "bright acoustic",
     3	 => "electric grand",
     4	 => "honky-tonk",
     5	 => "electric piano 1",
     6	 => "electric piano 2",
     7	 => "harpsichord",
     8	 => "clav",
     9	 => "celesta",
    10	 => "glockenspiel",
    11	 => "music box",
    12	 => "vibraphone",
    13	 => "marimba",
    14	 => "xylophone",
    15	 => "tubular bells",
    16	 => "dulcimer",
    17	 => "drawbar organ",
    18	 => "percussive organ",
    19	 => "rock organ",
    20	 => "church organ",
    21	 => "reed organ",
    22	 => "accordion",
    23	 => "harmonica",
    24	 => "concertina",
    25	 => "acoustic guitar (nylon)",
    26	 => "acoustic guitar (steel)",
    27	 => "electric guitar (jazz)",
    28	 => "electric guitar (clean)",
    29	 => "electric guitar (muted)",
    30	 => "overdriven guitar",
    31	 => "distorted guitar",
    32	 => "guitar harmonics",
    33	 => "acoustic bass",
    34	 => "electric bass (finger)",
    35	 => "electric bass (pick)",
    36	 => "fretless bass",
    37	 => "slap bass 1",
    38	 => "slap bass 2",
    39	 => "synth bass 1",
    40	 => "synth bass 2",
    41	 => "violin",
    42	 => "viola",
    43	 => "cello",
    44	 => "contrabass",
    45	 => "tremolo strings",
    46	 => "pizzicato strings",
    47	 => "orchestral harp",
    48	 => "timpani",
    49	 => "string ensemble 1",
    50	 => "string ensemble 2",
    51	 => "synthstrings 1",
    52	 => "synthstrings 2",
    53	 => "choir aahs",
    54	 => "voice oohs",
    55	 => "synth voice",
    56	 => "orchestra hit",
    57	 => "trumpet",
    58	 => "trombone",
    59	 => "tuba",
    60	 => "muted trumpet",
    61	 => "french horn",
    62	 => "brass section",
    63	 => "synthbrass 1",
    64	 => "synthbrass 2",
    65	 => "soprano sax",
    66	 => "alto sax",
    67	 => "tenor sax",
    68	 => "baritone sax",
    69	 => "oboe",
    70	 => "english horn",
    71	 => "bassoon",
    72	 => "clarinet",
    73	 => "piccolo",
    74	 => "flute",
    75	 => "recorder",
    76	 => "pan flute",
    77	 => "blown bottle",
    78	 => "shakuhachi",
    79	 => "whistle",
    80	 => "ocarina",
    81	 => "lead 1 (square)",
    82	 => "lead 2 (sawtooth)",
    83	 => "lead 3 (calliope)",
    84	 => "lead 4 (chiff)",
    85	 => "lead 5 (charang)",
    86	 => "lead 6 (voice)",
    87	 => "lead 7 (fifths)",
    88	 => "lead 8 (bass+lead)",
    89	 => "pad 1 (new age)",
    90	 => "pad 2 (warm)",
    91	 => "pad 3 (polysynth)",
    92	 => "pad 4 (choir)",
    93	 => "pad 5 (bowed)",
    94	 => "pad 6 (metallic)",
    95	 => "pad 7 (halo)",
    96	 => "pad 8 (sweep)",
    97	 => "fx 1 (rain)",
    98	 => "fx 2 (soundtrack)",
    99	 => "fx 3 (crystal)",
   100	 => "fx 4 (atmosphere)",
   101	 => "fx 5 (brightness)",
   102	 => "fx 6 (goblins)",
   103	 => "fx 7 (echoes)",
   104	 => "fx 8 (sci-fi)",
   105	 => "sitar",
   106	 => "banjo",
   107	 => "shamisen",
   108	 => "koto",
   109	 => "kalimba",
   110	 => "bagpipe",
   111	 => "fiddle",
   112	 => "shanai",
   113	 => "tinkle bell",
   114	 => "agogo",
   115	 => "steel drums",
   116	 => "woodblock",
   117	 => "taiko drum",
   118	 => "melodic tom",
   119	 => "synth drum",
   120	 => "reverse cymbal",
   121	 => "guitar fret noise",
   122	 => "breath noise",
   123	 => "seashore",
   124	 => "bird tweet",
   125	 => "telephone ring",
   126	 => "helicopter",
   127	 => "applause",
   128	 => "gunshot"
};

my @notes_human = ('C', 'C\#', 'D', 'D\#', 'E', 'F', 'F\#', 'G', 'G\#', 'A',
	'A\#', 'B');

my @notes = ('c', 'cis', 'd', 'dis', 'e', 'f', 'fis', 'g', 'gis', 'a', 'ais',
	'b');

sub note_relative_c_human
{
	return $notes_human[(scalar @notes + shift) % scalar @notes];
}

sub note_relative_c
{
	my $semitones = 12 + shift;
	my $octave = $semitones / scalar @notes;
	$octave -= ($octave < 0 and $octave > - scalar @notes);
	my $note = $notes[(scalar @notes + $semitones) % scalar @notes];

	return $note if $octave == 0;

	my $oct_sign = ($octave > 0 ? '\'' : ',');
	$octave = abs $octave;
	$note =~ s/(.*)$/$1 . $oct_sign x $octave/e;
	return $note;
}

my $db = DBI->connect("dbi:SQLite:dbname=db/jelly.db","","");
$db->{sqlite_unicode} = 1;

my $q_sel_track = $db->prepare(
	"SELECT MIDI_INSTRUMENT, SCORE_DATA, NAME FROM TRACK WHERE SCORE_ID = ?");

my $q_sel_song = $db->prepare(
        "SELECT ARTIST.NAME, SONG.NAME FROM SONG JOIN ARTIST ON JELLY_ARTIST_ID = ARTIST_ID WHERE SONG.ID = ?");

my $t = Template->new({
	INCLUDE_PATH => './template',
	OUTPUT_PATH => './tex',
});

sub generate
{
	my ($song_id, $score_id) = @_;

	$q_sel_song->execute($song_id);
	my @song_about = $q_sel_song->fetchrow_array();
	$q_sel_song->finish();

	$q_sel_track->execute($score_id);

	my @list;

	while (my @row = $q_sel_track->fetchrow_array())
	{
		my $score_orig = decode_song($row[1]);

		my @tuning = reverse split / /, (cut_tuning($score_orig) or "");
		my $new_lily_tuning = join(' ',
			map { note_relative_c($_); } @tuning);
		my @human_tuning =
			map { note_relative_c_human($_); } @tuning;


		my $clef = cut_clef($score_orig);
		my $score = prepare_score($score_orig);

		push(@list,
		    {
		    score => $score,
		    instrument => $instruments->{$row[0]},
		    tuning => $new_lily_tuning,
		    human_tuning => join(' ', @human_tuning),
		    clef => $clef,
		    name => $row[2],
		    midi => $row[0],
		    });
	}

	$q_sel_track->finish();
	$db->disconnect;

	$t->process('book.tex',
		    {
		    author => $song_about[0],
		    title => $song_about[1],
		    scores => \@list,
		    } , "jelly.tex");

	compile(@song_about);
}

sub decode_song
{
	my $buffer = decode_base64(shift);
	my $z = new IO::Uncompress::Bunzip2 \$buffer, {Append => 1};
	my $data;

	while (!$z->eof())
	{
		$z->read($data);
	}

	$z->close();
	return $data;
}

sub prepare_score
{
	$_ = shift;

	s/\\hammer //g;
	s/\\slide //g;
	s/\\letring //g;
	s/\\bendAfter\s+(#\w+(-\w+)*)+//g;
	s/#[[:digit:]]+\s+//gm;
	s/^\\new Staff {//;
	s/^}$//gm;
	s/\\section\s*{"(.*?)"}/\\once \\override Score\.RehearsalMark\.self-alignment-X = \#LEFT \\mark \\markup {\\tiny \\bold "$1"}/gs;
	s/\^\\markup\s*{"(.*?)"}/^\\markup {\\tiny "$1"}/gs;
	s/\\set TabStaff\.stringTunings = #'\(.*?\)//m;
	s/\\clef .*//m;
	s/\\pageBreak//mg;

	#s/\\times\s*?(\d+)\/(\d+)/\\tuplet $2\/$1 4/gm;

	#s/(\\times [[:digit:]]+\/[[:digit:]]+)\s*{(.*?)}/split_tuplet($1, <<"END");/gme;
#$2
#END

	return $_;
}

sub split_tuplet
{
	my $prefix = shift;
	$_ = shift;

	s/(\s+(?<!<)[^<>\s]+(?!>))\s+/$prefix . "{$1} "/gme;

	return $_;
}

sub cut_tuning
{
    $_ = shift;

    /\\set TabStaff\.stringTunings = #'\((.*?)\)/m;

    return $1;
}

sub cut_clef
{
    $_ = shift;

    /(\\clef\s*".*?")/m;

    return $1;
}

sub compile
{
	chdir "tex/";
	remove_tree('out/', {verbose => 0, keep_root => 1});

	system("lilypond-book --output=out --pdf jelly.tex");
    system("lilypond-book --output=out --pdf jelly.tex");

	chdir 'out/';

	system("pdflatex jelly");

	mkdir("../../pdf/$_[0]");
	copy("jelly.pdf", "../../pdf/$_[0]/$_[1].pdf");
}

#print note_relative_c (-15), "\n";

# generate(@ARGV);
