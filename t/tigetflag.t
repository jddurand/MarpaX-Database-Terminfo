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
is(tigetflag('am'), 1, "tigetflag('am') - boolean value");
is(tigetflag('cols'), -1, "tigetflag('cols') - not a boolean capability");
is(tigetflag('absentcap'), 0, "tigetflag('absentcap') - absent capability ");
is(tigetflag('bw'), 0, "tigetflag('bw') - cancelled capability");
