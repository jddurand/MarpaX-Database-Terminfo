#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 5;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:functions/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
    $ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN} = File::Spec->catfile('share', 'ncurses-terminfo-stubs.storable');
}
my $t = MarpaX::Database::Terminfo::Interface->new({use_env => 0});
$t->tgetent('dumb');
my $columns = undef;
is($t->tvgetnum('notexisting', \$columns), 0, "\$t->tvgetnum('notexisting', \\\$columns) returns false");
is($columns, undef, "\$columns value untouched");
is($t->tvgetnum('columns', \$columns), 1, "\$t->tvgetnum('columns', \\\$columns) returns true");
is($columns, 80, "\$columns value is 80");
