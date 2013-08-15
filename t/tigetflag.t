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
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('nsterm-16color');
is($t->tigetflag('am'), 1, "\$t->tigetflag('am') - boolean value");
is($t->tigetflag('cols'), -1, "\$t->tigetflag('cols') - not a boolean capability");
is($t->tigetflag('absentcap'), 0, "\$t->tigetflag('absentcap') - absent capability ");
is($t->tigetflag('bw'), 0, "\$t->tigetflag('bw') - cancelled capability");
