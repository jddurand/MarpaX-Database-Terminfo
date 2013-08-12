#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
}
is(tgetent('dumb'), 1, "tgetent('dumb')");
