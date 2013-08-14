use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Interface;
use MarpaX::Database::Terminfo::Constants qw/:all/;
use File::ShareDir qw/:ALL/;
use Carp qw/carp croak/;
use Storable qw/fd_retrieve/;
use base 'Class::Singleton';
use Exporter 'import';
use Storable qw/dclone/;
use Scalar::Util qw/refaddr/;
use Log::Any qw/$log/;

our @EXPORT_FUNCTIONS  = qw/tgetent tgetflag tgetnum tgetstr/;
our @EXPORT_INTERNALS = qw/_terminfo_db _terminfo_current _terminfo_init/;

our @EXPORT_OK = (@EXPORT_FUNCTIONS, @EXPORT_INTERNALS);
our %EXPORT_TAGS = ('all'       => \@EXPORT_OK,
		    'functions' => \@EXPORT_FUNCTIONS,
		    'internal'  => \@EXPORT_INTERNALS);

# ABSTRACT: Terminfo interface

# VERSION

=head1 DESCRIPTION

This modules implements a terminfo X/open-compliant interface.

=head1 SYNOPSIS

    use MarpaX::Database::Terminfo::Interface qw/:all/;
    use Log::Log4perl qw/:easy/;
    use Log::Any::Adapter;
    use Log::Any qw/$log/;
    use Data::Dumper;
    #
    # Init log
    #
    our $defaultLog4perlConf = '
    log4perl.rootLogger              = WARN, Screen
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
    ';
    Log::Log4perl::init(\$defaultLog4perlConf);
    Log::Any::Adapter->set('Log4perl');

    tgetent('ansi');

=head1 SUBROUTINES/METHODS

=head2 _new_instance($class, $opts)

Instance a singleton object. Any implementation lie tgetent(), tgetflag(), etc... is using this singleton. An optional $opt hash, with corresponding environment variables, can control how the object is created:

=over

=item file or $ENV{MARPAX_DATABASE_TERMINFO_FILE}

a file path to the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the txt key/value.

=item txt or $ENV{MARPAX_DATABASE_TERMINFO_TXT}

a text version of the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the bin key/value.

=item bin or $ENV{MARPAX_DATABASE_TERMINFO_BIN}

a path to a binary version of the terminfo database, created using Storable module. This module is distributed with such a binary file, which contains the GNU ncurses definitions. The default behaviour is to use this file.

=item caps or $ENV{MARPAX_DATABASE_TERMINFO_CAPS}

a path to a text version of the terminfo<->termcap translation. This module is distributed with GNU ncurses translation files, namely: ncurses-Caps (default), ncurses-Caps.aix4 (default on AIX), ncurses-Caps.hpux11 (default on HP/UX), ncurses-Caps.keys, ncurses-Caps.osf1r5 (default on OSF1) and ncurses-Caps.uwin.

=back

Default terminal setup is done using the $ENV{TERM} environment variable, if it exist, or 'dumb'. The database used is not a compiled database as with GNU ncurses, therefore the environment variable TERMINFO is not used. Instead, a compiled database should a perl's Storable version of a text database parsed by Marpa. See $ENV{MARPAX_DATABASE_TERMINFO_BIN} upper.

=cut

sub _new_instance {
    my ($class, $opts) = @_;

    $opts //= {};

    if (ref($opts) ne 'HASH') {
	croak 'Options must be a reference to a HASH';
    }

    my $file = $opts->{file} || $ENV{MARPAX_DATABASE_TERMINFO_FILE} || '';
    my $txt  = $opts->{txt}  || $ENV{MARPAX_DATABASE_TERMINFO_TXT}  || '';
    my $bin  = $opts->{bin}  || $ENV{MARPAX_DATABASE_TERMINFO_BIN}  || dist_file('MarpaX-Database-Terminfo', 'share/ncurses-terminfo.storable');
    my $caps = $opts->{caps} || $ENV{MARPAX_DATABASE_TERMINFO_CAPS} || (
	$^O eq 'aix'     ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.aix4')   :
	$^O eq 'hpux'    ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.hpux11') :
	$^O eq 'dec_osf' ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.osf1r5') :
	dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps'));

    my $db = undef;
    if ($file) {
	my $fh;
	if ($log->is_debug) {
	    $log->debugf('Loading %s', $file);
	}
	if (! open($fh, '<', $file)) {
	    carp "Cannot open $file; $!";
	} else {
	    my $content = do {local $/; <$fh>;};
	    close($fh) || carp "Cannot close $file, $!";
	    if ($log->is_debug) {
		$log->debugf('Parsing %s', $file);
	    }
	    $db = eval {MarpaX::Database::Terminfo->new()->parse(\$content)->value()};
	}
    } elsif ($txt) {
	if ($log->is_debug) {
	    $log->debugf('Parsing txt');
	}
	$db = eval {MarpaX::Database::Terminfo->new()->parse(\$txt)->value()};
    } else {
	my $fh;
	if ($log->is_debug) {
	    $log->debugf('Loading %s', $bin);
	}
	if (! open($fh, '<', $bin)) {
	    carp "Cannot open $bin; $!";
	} else {
	    $db = eval {fd_retrieve($fh)};
	    close($fh) || carp "Cannot close $bin, $!";
	}
    }
    my %t2other = ();
    my %c2other = ();
    my %capalias = ();
    my %infoalias = ();
    {
	if ($log->is_debug) {
	    $log->debugf('Loading %s', $caps);
	}
	my $fh;
	if (! open($fh, '<', $caps)) {
	    carp "Cannot open $caps; $!";
	} else {
	    #
	    # Get translations
	    #
	    my $line = 0;
	    while (defined($_ = <$fh>)) {
		++$line;
		if (/^\s*#/) {
		    next;
		}
		s/\s*$//;
		if (/^\s*capalias\b/) {
		    my ($capalias, $alias, $name, $set, $description) = split(/\s+/, $_, 5);
		    $capalias{$alias} = {name => $name, set => $set, description => $description};
		} elsif (/^\s*infoalias\b/) {
		    my ($infoalias, $alias, $name, $set, $description) = split(/\s+/, $_, 5);
		    $infoalias{$alias} = {name => $name, set => $set, description => $description};
		} else {
		    my ($variable, $feature, $type, $termcap, $keyname, $keyvalue, $translation, $description) = split(/\s+/, $_, 8);
		    if ($type eq 'bool') {
			$type = TERMINFO_BOOLEAN;
		    } elsif ($type eq 'num') {
			$type = TERMINFO_NUMERIC;
		    } elsif ($type eq 'str') {
			$type = TERMINFO_STRING;
		    } else {
			$log->warnf('%s(%d): wrong type \'%s\'', $caps, $line, $type); exit;
			next;
		    }
		    $t2other{$feature} = {type => $type, termcap => $termcap, variable => $variable};
		    $c2other{$termcap} = {type => $type, feature => $feature, variable => $variable};
		}
	    }
	    close($fh) || carp "Cannot close $caps, $!";
	}
    }

    my $self = {
	_terminfo_db => $db,
	_terminfo_current => undef,
	_t2other => \%t2other,
	_c2other => \%c2other,
	_capalias => \%capalias,
	_infoalias => \%infoalias
    };

    bless($self, $class);

    return $self;
}

=head2 _terminfo_db()

Internal function. Returns the raw database, in the form of an array of hashes.

=cut

sub _terminfo_db {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_terminfo_db})) {
	$log->warnf('Undefined database');
    }
    return $self->{_terminfo_db};
}

=head2 _terminfo_current()

Internal function. Returns the current terminfo entry.

=cut

sub _terminfo_current {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_terminfo_current})) {
	$log->warnf('Undefined current terminfo entry');
    }
    return $self->{_terminfo_current};
}

=head2 _t2other()

Internal function. Returns the terminfo->termcap translation hash.

=cut

sub _t2other {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_t2other})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_t2other};
}

=head2 _c2other()

Internal function. Returns the terminfo->termcap translation hash.

=cut

sub _c2other {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_c2other})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_c2other};
}

=head2 _capalias()

Internal function. Returns the termcap aliases.

=cut

sub _capalias {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_capalias})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_capalias};
}

=head2 _infoalias()

Internal function. Returns the termcap aliases.

=cut

sub _infoalias {
    my ($self) = __PACKAGE__->instance();
    if ($log->is_warn && ! defined($self->{_infoalias})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_infoalias};
}

=head2 _terminfo_init()

Internal function. Initialize if needed and if possible the current terminfo. Returns a pointer to the current terminfo entry.

=cut

sub _terminfo_init {
    my ($self) = __PACKAGE__->instance();
    if (! defined($self->{_terminfo_current})) {
	tgetent($ENV{TERM} || 'dumb');
    }
    return defined($self->_terminfo_current);
}

=head2 tgetent($name)

Loads the entry for $name. Returns 1 on success, 0 if no entry, -1 if the terminfo database could not be found. This function will warn if the database has a problem. $name must be an alias in the terminfo database. If multiple entries have the same alias, the first that matches is taken.

=cut

sub _find {
    my ($self, $name) = @_;

    my $rc = undef;

    my $terminfo_db = _terminfo_db();
    if (defined($terminfo_db)) {
	foreach (@{$terminfo_db}) {
	    my $terminfo = $_;

	    if (grep {$_ eq $name} @{$terminfo->{alias}}) {
		if ($log->is_debug) {
		    $log->debugf('Found alias \'%s\' in terminfo with aliases %s longname \'%s\'', $name, $terminfo->{alias}, $terminfo->{longname});
		}
		$rc = $terminfo;
		last;
	    }
	}
    }
    return $rc;
}

sub tgetent {
    my ($self, $name) = (__PACKAGE__->instance(), @_);

    if (! defined(_terminfo_db())) {
	return -1;
    }
    my $found = $self->_find($name);
    if (! defined($found)) {
	return 0;
    }
    #
    # Process cancellations and use=
    #
    {
	my %cancelled = ();
	my %featured = ();
	my $i = 0;
	while ($i <= $#{$found->{feature}}) {
	    my $feature = $found->{feature}->[$i];
	    if ($feature->{type} == TERMINFO_BOOLEAN && substr($feature->{name}, -1, 1) eq '@') {
		my $cancelled = $feature->{name};
		substr($cancelled, -1, 1, '');
		$cancelled{$cancelled} = 1;
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] New cancellation %s', $name, $cancelled);
		}
		++$i;
	    } elsif ($feature->{type} == TERMINFO_STRING && $feature->{name} eq 'use') {
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] use=\'%s\' with cancellations %s', $name, $feature->{value}, [ keys %cancelled ]);
		}
		my $insert = $self->_find($feature->{value});
		if (! defined($insert)) {
		    return 0;
		}
		my @keep = ();
		foreach (@{$insert->{feature}}) {
		    if (exists($cancelled{$_->{name}})) {
			if ($log->is_trace) {
			    $log->tracef('[Loading %s] Skipping cancelled feature \'%s\' from terminfo with aliases %s longname \'%s\'', $name, $_->{name}, $insert->{alias}, $insert->{longname});
			}
			next;
		    }
		    if (exists($featured{$_->{name}})) {
			if ($log->is_trace) {
			    $log->tracef('[Loading %s] Skipping overwriting feature \'%s\' from terminfo with aliases %s longname \'%s\'', $name, $_->{name}, $insert->{alias}, $insert->{longname});
			}
			next;
		    }
		    if ($log->is_trace) {
			$log->tracef('[Loading %s] Pushing feature %s from terminfo with aliases %s longname \'%s\'', $name, $_, $insert->{alias}, $insert->{longname});
		    }
		    push(@keep, $_);
		}
		splice(@{$found->{feature}}, $i, 1, @keep);
	    } else {
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] New feature %s', $name, $feature);
		}
		$featured{$feature->{name}} = 1;
		++$i;
	    }
	}
    }
    #
    # Drop needless cancellations
    #
    {
	my $i = $#{$found->{feature}};
	foreach (reverse @{$found->{feature}}) {
	    if ($_->{type} == TERMINFO_BOOLEAN && substr($_->{name}, -1, 1) eq '@') {
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] Dropping cancellation \'%s\' from terminfo', $name, $found->{feature}->[$i]->{name});
		}
		splice(@{$found->{feature}}, $i, 1);
	    }
	    --$i;
	}
    }
    #
    # Drop commented features
    #
    {
	my $i = $#{$found->{feature}};
	foreach (reverse @{$found->{feature}}) {
	    if (substr($_->{name}, 0, 1) eq '.') {
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] Dropping commented \'%s\' from terminfo', $name, $found->{feature}->[$i]->{name});
		}
		splice(@{$found->{feature}}, $i, 1);
	    }
	    --$i;
	}
    }
    #
    # Fill variables and termcap correspondances
    #
    {
	my @termcap = ();
	my @variable = ();
	foreach (@{$found->{feature}}) {
	    my $feature = $_;
	    if (! exists($self->_t2other->{$feature->{name}})) {
		if ($log->is_warn) {
		    $log->warnf('[Loading %s] Untranslated feature \'%s\'', $name, $feature->{name});
		}
		next;
	    }
	    #
	    # Check consistency
	    #
	    my $type = $self->_t2other->{$feature->{name}}->{type};
	    if ($feature->{type} != $type) {
		if ($log->is_warn) {
		    $log->warnf('[Loading %s] Wrong type when translating feature \'%s\': %d instead of %d', $name, $feature->{name}, $type, $feature->{type});
		}
		next;
	    }
	    #
	    # Convert to termcap
	    #
	    my $termcap  = $self->_t2other->{$feature->{name}}->{termcap};
	    if (! defined($termcap)) {
		if ($log->is_warn) {
		    $log->warnf('[Loading %s] Feature \'%s\' has no termcap equivalent', $name, $feature->{name});
		}
	    } else {
		if ($log->is_debug) {
		    $log->debugf('[Loading %s] Pushing termcap feature \'%s\'', $name, $termcap);
		}
		push(@termcap, {name => $termcap, type => $type, value => $feature->{value}});
	    }
	    $found->{termcap} = \@termcap;
	    #
	    # Convert to variable
	    #
	    my $variable = $self->_t2other->{$feature->{name}}->{variable};
	    if ($log->is_debug) {
		$log->debugf('[Loading %s] Pushing variable feature \'%s\'', $name, $variable);
	    }
	    push(@variable, {name => $variable, type => $type, value => $feature->{value}});
	    $found->{variable} = \@variable;
	}
    }

    $self->{_terminfo_current} = $found;

    return 1;
}

#
# tget is a termcap-like thing: only termcap entries are checked, and they are per def two chars max in {termcap} hash
#
sub _tget {
    my ($self, $default, $type, $id, $areap) = (__PACKAGE__->instance(), @_);

    my $rc = $default;

    if (_terminfo_init()) {
	my $found = 0;
	foreach (@{$self->_terminfo_current->{termcap}}) {
	    my $name = $_->{name};
	    if ($_->{type} == $type && $name eq $id) {
		if ($log->is_debug) {
		    $log->debugf('Found termcap feature %s', $_);
		}
		$rc = $_->{value};
		$found = 1;
		last;
	    }
	}
	if (! $found && $log->is_debug) {
	    $log->debugf('No termcap feature with name \'%s\'', $id);
	}
    }

    if (defined($areap)) {
	${$areap} = $rc;
    }

    return $rc;
}

=head2 tgetflag($id)

Gets the boolean entry for $id, or 0 if not available. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetflag {
    return _tget(0, TERMINFO_BOOLEAN, @_);
}

=head2 tgetnum($id)

Gets the numeric entry for $id, or -1 if not available. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetnum {
    return _tget(-1, TERMINFO_NUMERIC, @_);
}

=head2 tgetstr($id, $areap)

Gets the string entry for $id, or 0 if not available. If $areap is defined, the buffer it is pointing to is updated with the $id value. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetstr {
    return _tget(0, TERMINFO_STRING, @_);
}

=head2 tputs($str, $affcnt, $putc)

Applies padding information to the string $str and outputs it. The $str must be a terminfo string variable or the return value from tparm(), tgetstr(), or tgoto(). $affcnt is the number of lines affected, or 1 if not applicable. $putc is a putchar-like routine to which the characters are passed, one at a time.

=cut

sub tputs {
    return _tget(0, TERMINFO_STRING, @_);
}

=head1 EXPORTS

This module is exporting on demand the following tags:

=over

=item functions

The functions tgetent(), tgetflag(), tgetnum(), tgetstr().

=item internal

The internal functions _terminfo_db(), _terminfo_current(), _terminfo_init(), _t2other(), _c2other(), _capalias() and _infoalias().

=item all

All of the above.

=back

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

L<Marpa::R2|http://metacpan.org/release/Marpa-R2>

=cut

1;
