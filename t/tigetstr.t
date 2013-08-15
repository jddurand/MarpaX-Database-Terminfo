#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 5;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
tgetent('nsterm-16color');
is(tigetstr('fsl'), '^G', "tigetstr('fsl') - string value");
is(tigetstr('wsl'), undef, "tigetstr('zsl') - not a string capability");
is(tigetstr('absentcap'), undef, "tigetstr('absentcap') - absent capability ");
is(tigetstr('bw'), undef, "tigetflag('bw') - cancelled capability");
