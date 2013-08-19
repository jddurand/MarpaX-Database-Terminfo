#!env perl
use strict;
use diagnostics;
use Data::Dumper;
use Storable qw/store_fd/;
use POSIX qw/EXIT_SUCCESS/;
    use Log::Log4perl qw/:easy/;
    use Log::Any::Adapter;
    use Log::Any qw/$log/;
    #
    # Init log
    #
    our $defaultLog4perlConf = '
    log4perl.rootLogger              = DEBUG, Screen
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
    ';
    Log::Log4perl::init(\$defaultLog4perlConf);
    Log::Any::Adapter->set('Log4perl');

BEGIN {
    use File::Spec;
    unshift(@INC, 'lib');
}
use MarpaX::Database::Terminfo::Interface qw/:all/;
$ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
$ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
$ENV{MARPAX_DATABASE_TERMINFO_STUBS_TXT} = '';
$ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN} = '';

my $t = MarpaX::Database::Terminfo::Interface->new();
#
# Generate all stubs by loading all the aliases, as in t/tgetent.t
#
print STDERR "Generating all stubs - be patient\n";
my %alias = ();
foreach (@{$t->_terminfo_db}) {
    foreach (@{$_->{alias}}) {
	++$alias{$_};
    }
}
foreach (sort keys %alias) {
    $t->tgetent($_);
}
{
    my $outfile = File::Spec->catfile('share', 'ncurses-terminfo-stubs.storable');
    open(OUTFILE, '>', $outfile) || die "Cannot open $outfile; $!";
    print STDERR "Writing ncurses stubs (as text) with Storable into $outfile\n";
    store_fd $t->{_cached_stubs_as_txt}, \*OUTFILE;
    close(OUTFILE) || warn "Cannot close $outfile, $!\n";
}
{
    local $Data::Dumper::Purity = 1;
    my $outfile = File::Spec->catfile('share', 'ncurses-terminfo-stubs.txt');
    open(OUTFILE, '>', $outfile) || die "Cannot open $outfile; $!";
    print STDERR "Writing ncurses stubs (as text) with Data::Dumper into $outfile\n";
    print OUTFILE Dumper($t->{_cached_stubs_as_txt});
    close(OUTFILE) || warn "Cannot close $outfile, $!\n";
}
exit(EXIT_SUCCESS);
