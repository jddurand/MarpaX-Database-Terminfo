use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Interface;
use MarpaX::Database::Terminfo;
use File::ShareDir qw/:ALL/;
use Carp qw/croak/;
use Storable qw/fd_retrieve/;

# ABSTRACT: Terminfo interface

# VERSION

=head1 DESCRIPTION

This modules implements a terminfo X/open-compliant interface.

=head1 SYNOPSIS

    use MarpaX::Database::Terminfo::Interface;

    my $t = MarpaX::Database::Terminfo::Interface->new();
    $t->tgetent('ansi');

=head1 SUBROUTINES/METHODS

=head2 new($class, $opts)

Instance a new object. An optional $opt hash can contain the following key/value:

=over

=item file

a file path to the terminfo database. This module will then parse it using Marpa. If setted to any true value, this setting has precedence over the txt key/value.

=item txt

a text version of the terminfo database. This module will then parse it using Marpa. If setted to any true value, this setting has precedence over the bin key/value.

=item bin

a path to a binary version of the terminfo database, created using Storable module. This module is distributed with such a binary file, which contains the GNU ncurses definitions. The default behaviour is to use this file.

=back

=cut

sub new {
    my ($class, $opts) = @_;

    $opts //= {};

    if (ref($opts) ne 'HASH') {
	croak 'Options must be a reference to a HASH';
    }

    my $file = $opts->{file} || '';
    my $txt  = $opts->{txt}  || '';
    my $bin  = $opts->{bin}  || module_file('MarpaX::Database::Terminfo', 'share/ncurses-terminfo.storable');

    my $db;
    if ($file) {
	open(FILE, '<', $file) || croak "Cannot open $file; $!";
	my $content = do {local $/; <FILE>;};
	close(FILE) || warn "Cannot close $file, $!";
	$db = MarpaX::Database::Terminfo->new()->parse(\$content)->value();
    } elsif ($txt) {
	$db = MarpaX::Database::Terminfo->new()->parse(\$txt)->value();
    } else {
	open(BIN, '<', $bin) || croak "Cannot open $bin; $!";
	$db = fd_retrieve(\*BIN);
	close(BIN) || warn "Cannot close $bin, $!";
    }

    my $self = {_db => $db};

    bless($self, $class);

    return $self;
}

=head2 db($self)

Returns the raw database, in the form of an array of hashes.

=cut

sub db {
    my ($self) = @_;
    return $self->{_db};
}

=head2 tgetent($self, $name)

Loads the entry for $name. Returns a true value on success, 0 if no entry. This function will warn if the database has a problem. $name can be an alias or the "longname". If multiple entries have the same alias, the first that matches is taken.

=cut

sub tgetent {
    my ($self, $name) = @_;

    #
    # Search for the alias or the longname
    #
    my $entry = undef;
    foreach (@{$self->db}) {
	if ((grep {$_ eq $name} @{$_->{alias}}) ||
	    ($_ eq $_->{longname})) {
	    $entry = $_;
	    last;
	}
    }

    return $entry;
}

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

L<Marpa::R2>

=cut

1;
