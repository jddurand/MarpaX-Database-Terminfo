#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 6;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
tgetent('nsterm-16color');
is(ref(tigetstr('fsl')), 'SCALAR', "tigetstr('fsl') returns a reference to a SCALAR");
is(${tigetstr('fsl')}, '^G', "tigetstr('fsl') - string value");
is(tigetstr('wsl'), -1, "tigetstr('zsl') - not a string capability");
is(tigetstr('absentcap'), 0, "tigetstr('absentcap') - absent capability ");
is(tigetstr('bw'), 0, "tigetflag('bw') - cancelled capability");
