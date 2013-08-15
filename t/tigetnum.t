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
is(tigetnum('wsl'), 50, "tigetnum('wsl') - numeric value");
is(tigetnum('fsl'), -2, "tigetnum('fsl') - not a numeric capability");
is(tigetnum('absentcap'), -1, "tigetnum('absentcap') - absent capability ");
is(tigetnum('bw'), -1, "tigetflag('bw') - cancelled capability");
