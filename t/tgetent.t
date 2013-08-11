#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface' ) || print "Bail out!\n";
}
my $dumb = MarpaX::Database::Terminfo::Interface->new({bin => File::Spec->catfile('share', 'ncurses-terminfo.storable')})->tgetent('dumb');
ok(defined($dumb), "tgetent('dumb')");
