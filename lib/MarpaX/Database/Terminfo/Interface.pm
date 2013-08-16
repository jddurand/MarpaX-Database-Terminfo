use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Interface;
use MarpaX::Database::Terminfo::Constants qw/:all/;
use File::ShareDir qw/:ALL/;
use Carp qw/carp croak/;
use Storable qw/fd_retrieve/;
use Storable qw/dclone/;
use Scalar::Util qw/refaddr/;
use Log::Any qw/$log/;
our $HAVE_POSIX = eval "use POSIX; 1;" || 0;

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

=head2 new($class, $opts)

Instance an object. An optional $opt is a reference to a hash:

=over

=item $opts->{file} or $ENV{MARPAX_DATABASE_TERMINFO_FILE}

a file path to the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the txt key/value.

=item $opts->{txt} or $ENV{MARPAX_DATABASE_TERMINFO_TXT}

a text version of the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the bin key/value.

=item $opts->{bin} or $ENV{MARPAX_DATABASE_TERMINFO_BIN}

a path to a binary version of the terminfo database, created using Storable module. This module is distributed with such a binary file, which contains the GNU ncurses definitions. The default behaviour is to use this file.

=item $opts->{caps} or $ENV{MARPAX_DATABASE_TERMINFO_CAPS}

a path to a text version of the terminfo<->termcap translation. This module is distributed with GNU ncurses translation files, namely: ncurses-Caps (default), ncurses-Caps.aix4 (default on AIX), ncurses-Caps.hpux11 (default on HP/UX), ncurses-Caps.keys, ncurses-Caps.osf1r5 (default on OSF1) and ncurses-Caps.uwin.

=back

Default terminal setup is done using the $ENV{TERM} environment variable, if it exist, or 'unknown'. The database used is not a compiled database as with GNU ncurses, therefore the environment variable TERMINFO is not used. Instead, a compiled database should a perl's Storable version of a text database parsed by Marpa. See $ENV{MARPAX_DATABASE_TERMINFO_BIN} upper.

=cut

sub new {
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
	_infoalias => \%infoalias,
	_static_vars => [],
	_dynamic_vars => [],
    };

    bless($self, $class);

    return $self;
}

=head2 _terminfo_db($self)

Internal function. Returns the raw database, in the form of an array of hashes.

=cut

sub _terminfo_db {
    my ($self) = (@_);
    if ($log->is_warn && ! defined($self->{_terminfo_db})) {
	$log->warnf('Undefined database');
    }
    return $self->{_terminfo_db};
}

=head2 _terminfo_current($self)

Internal function. Returns the current terminfo entry.

=cut

sub _terminfo_current {
    my $self = shift;
    if (@_) {
	$self->{_terminfo_current} = shift;
    }
    if ($log->is_warn && ! defined($self->{_terminfo_current})) {
	$log->warnf('Undefined current terminfo entry');
    }
    return $self->{_terminfo_current};
}

=head2 _t2other($self)

Internal function. Returns the terminfo->termcap translation hash.

=cut

sub _t2other {
    my ($self) = (@_);
    if ($log->is_warn && ! defined($self->{_t2other})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_t2other};
}

=head2 _c2other($self)

Internal function. Returns the terminfo->termcap translation hash.

=cut

sub _c2other {
    my ($self) = (@_);
    if ($log->is_warn && ! defined($self->{_c2other})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_c2other};
}

=head2 _capalias($self)

Internal function. Returns the termcap aliases.

=cut

sub _capalias {
    my ($self) = (@_);
    if ($log->is_warn && ! defined($self->{_capalias})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_capalias};
}

=head2 _infoalias($self)

Internal function. Returns the termcap aliases.

=cut

sub _infoalias {
    my ($self) = (@_);
    if ($log->is_warn && ! defined($self->{_infoalias})) {
	$log->warnf('Undefined terminfo->termcap translation hash');
    }
    return $self->{_infoalias};
}

=head2 _terminfo_init()

Internal function. Initialize if needed and if possible the current terminfo. Returns a pointer to the current terminfo entry.

=cut

sub _terminfo_init {
    my ($self) = (@_);
    if (! defined($self->{_terminfo_current})) {
	$self->tgetent($ENV{TERM} || 'unknown');
    }
    return defined($self->_terminfo_current);
}

=head2 tgetent($name[, $fh])

Loads the entry for $name. Returns 1 on success, 0 if no entry, -1 if the terminfo database could not be found. This function will warn if the database has a problem. $name must be an alias in the terminfo database. If multiple entries have the same alias, the first that matches is taken. The variables PC, UP and BC are set by tgetent to the terminfo entry's data for pad_char, cursor_up and backspace_if_not_bs, respectively. The variable ospeed is set in a system-specific coding to reflect the terminal speed, and is $ENV{TERMINFO_OSPEED} if defined, otherwise we attempt to get the value using POSIX interface, or 0. ospeed should be a value between 0 and 15, or 4097 and 4105, or 4107 and 4111. The variable baudrate can be $ENV{TERMINFO_BAUDRATE} (unchecked, i.e. at your own risk) or is derived from ospeed, or 0. $fh is an optional opened filehandle, used to guess about baudrate and ospeed. Defaults to fileno(\*STDIN) or 0. When loading a terminfo, termcap and variable entries are automatically derived using the caps parameter as documented in _new_instance().

=cut

sub _find {
    my ($self, $name) = @_;

    my $rc = undef;

    my $terminfo_db = $self->_terminfo_db;
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
    my ($self, $name, $fh) = (@_);

    if (! defined($self->_terminfo_db)) {
	return -1;
    }
    my $found = $self->_find($name);
    if (! defined($found)) {
	return 0;
    }
    #
    # Process cancellations and use=
    #
    my %cancelled = ();
    {
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
    # Remember cancelled things
    #
    $found->{cancelled} = \%cancelled;
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
    my $pad_char = 0;
    my $cursor_up = 0;
    my $backspace_if_not_bs = 0;
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
	    #
	    # Convert to variable
	    #
	    my $variable = $self->_t2other->{$feature->{name}}->{variable};
	    if ($log->is_debug) {
		$log->debugf('[Loading %s] Pushing variable feature \'%s\'', $name, $variable);
	    }
	    push(@variable, {name => $variable, type => $type, value => $feature->{value}});
	    if ($type == TERMINFO_STRING) {
		if ($variable eq 'pad_char') {
		    $pad_char = $feature->{value};
		    if ($log->is_debug) {
			$log->debugf('[Loading %s] pad_char is \'%s\'', $name, $feature->{value});
		    }
		} elsif ($variable eq 'cursor_up') {
		    $cursor_up = $feature->{value};
		    if ($log->is_debug) {
			$log->debugf('[Loading %s] cursor_up is \'%s\'', $name, $feature->{value});
		    }
		} elsif ($variable eq 'backspace_if_not_bs') {
		    $backspace_if_not_bs = $feature->{value};
		    if ($log->is_debug) {
			$log->debugf('[Loading %s] backspace_if_not_bs is \'%s\'', $name, $feature->{value});
		    }
		}
	    }
	}

	# The variables PC, UP and BC are set by tgetent to the terminfo entry's data for pad_char, cursor_up and backspace_if_not_bs, respectively.
	#
	# PC is used in the tdelay_output function.
	#
	my $PC = {name => 'PC', type => TERMINFO_STRING, value => $pad_char};
	if ($log->is_debug) {
	    $log->debugf('[Loading %s] Initialized PC to \'%s\'', $name, $PC->{value});
	}
	push(@variable, $PC);
	#
	# UP is not used by ncurses.
	#
	my $UP = {name => 'UP', type => TERMINFO_STRING, value => $cursor_up};
	if ($log->is_debug) {
	    $log->debugf('[Loading %s] Initialized UP to \'%s\'', $name, $UP->{value});
	}
	push(@variable, $UP);
	#
	# BC is used in the tgoto emulation.
	#
	my $BC = {name => 'BC', type => TERMINFO_STRING, value => $backspace_if_not_bs};
	if ($log->is_debug) {
	    $log->debugf('[Loading %s] Initialized BC to \'%s\'', $name, $BC->{value});
	}
	push(@variable, $BC);
	#
	# The variable ospeed is set in a system-specific coding to reflect the terminal speed.
	#
	my ($baudrate, $ospeed) = $self->_get_ospeed_and_baudrate($fh);
	my $OSPEED = {name => 'ospeed', type => TERMINFO_STRING, value => $ospeed};
	if ($log->is_debug) {
	    $log->debugf('[Loading %s] Initialized ospeed to \'%s\'', $name, $OSPEED->{value});
	}
	push(@variable, $OSPEED);
	my $BAUDRATE = {name => 'baudrate', type => TERMINFO_STRING, value => $baudrate};
	if ($log->is_debug) {
	    $log->debugf('[Loading %s] Initialized baudrate to \'%s\'', $name, $BAUDRATE->{value});
	}
	push(@variable, $BAUDRATE);

	$found->{termcap} = \@termcap;
	$found->{variable} = \@variable;
    }

    #
    # Alias terminfo space to feature
    #
    $found->{terminfo} = $found->{feature};

    $self->_terminfo_current($found);

    return 1;
}
#
# _get_ospeed_and_baudrate calculates baudrate and ospeed
#
# POSIX module does not contain all the constants. Here they are.
#
our %OSPEED_TO_BAUDRATE = (
    0    => 0,
    1    => 50,
    2    => 75,
    3    => 110,
    4    => 134,
    5    => 150,
    6    => 200,
    7    => 300,
    8    => 600,
    9    => 1200,
    10   => 1800,
    11   => 2400,
    12   => 4800,
    13   => 9600,
    14   => 19200,
    15   => 38400,
    4097 => 57600,
    4098 => 115200,
    4099 => 230400,
    4100 => 460800,
    4101 => 500000,
    4102 => 576000,
    4103 => 921600,
    4104 => 1000000,
    4105 => 1152000,
    4107 => 2000000,
    4108 => 2500000,
    4109 => 3000000,
    4110 => 3500000,
    4111 => 4000000,
    );

sub _get_ospeed_and_baudrate {
    my ($self, $fh) = (@_);

    my $baudrate = 0;
    my $ospeed = 0;

    if (defined($ENV{TERMINFO_OSPEED})) {
	$ospeed = $ENV{TERMINFO_OSPEED};
    } else {
	my $termios = undef;
	if ($HAVE_POSIX) {
	    $termios = eval { POSIX::Termios->new() };
	    if (! defined($termios)) {
		if ($log->is_debug) {
		    $log->debugf('POSIX::Termios->new() failure, %s', $@);
		}
	    } else {
		my $fileno = fileno(\*STDIN) || 0;
		if (defined($fh)) {
		    my $reffh = ref($fh);
		    if ($reffh ne 'GLOB') {
			if ($log->is_warn) {
			    $log->warnf('filehandle should be a reference to GLOB instead of %s', $reffh || '<nothing>');
			}
		    } else {
			$fileno = fileno($fh);
		    }
		}
		if ($log->is_debug) {
		    $log->debugf('Trying to get attributes on fileno %d', $fileno);
		}
		eval {$termios->getattr($fileno)};
		if ($@) {
		    if ($log->is_debug) {
			$log->debugf('POSIX::Termios::getattr(%d) failure, %s', $fileno, $@);
		    }
		    $termios = undef;
		}
	    }
	}
	if (defined($termios)) {
	    my $this = eval { $termios->getospeed() };
	    if (! defined($ospeed)) {
		if ($log->is_debug) {
		    $log->debugf('getospeed() failure, %s', $@);
		}
	    } else {
		$ospeed = $this;
		if ($log->is_debug) {
		    $log->debugf('getospeed() returned %d', $ospeed);
		}
	    }
	}
    }

    if (! exists($OSPEED_TO_BAUDRATE{$ospeed})) {
	if ($log->is_warn) {
	    $log->warnf('ospeed %d is an unknown value. baudrate will be zero.', $ospeed);
	}
    }

    $baudrate = $ENV{TERMINFO_BAUDRATE} || $OSPEED_TO_BAUDRATE{$ospeed} || 0;

    return ($baudrate, $ospeed);
}

#
# space refers to termcap, feature (i.e. terminfo) or variable
#
sub _tget {
    my ($self, $space, $default, $default_if_cancelled, $default_if_wrong_type, $type, $id, $areap) = (@_);

    my $rc = $default;
    my $found = 0;

    if ($self->_terminfo_init()) {
	if (defined($default_if_cancelled) && exists($self->_terminfo_current->{cancelled}->{$id})) {
	    if ($log->is_debug) {
		$log->debugf('Cancelled %s feature %s', $space, $id);
	    }
	    $rc = $default_if_cancelled;
	} else {
	    $found = 0;
	    foreach (@{$self->_terminfo_current->{$space}}) {
		my $name = $_->{name};
		if ($name eq $id) {
		    if ($_->{type} == $type) {
			if ($log->is_debug) {
			    $log->debugf('Found %s feature %s', $space, $_);
			}
			if ($type == TERMINFO_STRING) {
			    $rc = \$_->{value};
			} else {
			    $rc = $_->{value};
			}
			$found = 1;
			last;
		    } elsif (defined($default_if_wrong_type)) {
			if ($log->is_debug) {
			    $log->debugf('Found %s feature %s with type %d != %d', $space, $_, $_->{type}, $type);
			}
			$rc = $default_if_wrong_type;
			last;
		    }
		}
	    }
	    if (! $found && $log->is_debug) {
		$log->debugf('No %s feature with name \'%s\'', $space, $id);
	    }
	}
    }

    if ($found && defined($areap)) {
	if (! defined(${$areap})) {
	    ${$areap} = '';
	}
	my $pos = pos(${$areap}) || 0;
	my $this = ref($rc) ? ${$rc} : $rc;
	substr(${$areap}, $pos, 0, $this);
	pos(${$areap}) = $pos + length($this);
    }

    return $rc;
}

=head2 tgetflag($id)

Gets the boolean value for termcap entry $id, or 0 if not available. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetflag {
    my $self = shift;
    return $self->_tget('termcap', 0, undef, undef, TERMINFO_BOOLEAN, @_);
}

=head2 tigetflag($id)

Gets the boolean value for terminfo entry $id. Returns the value -1 if $id is not a boolean capability, or 0 if it is canceled or absent from the terminal description.

=cut

sub tigetflag {
    my $self = shift;
    return $self->_tget('terminfo', 0, 0, -1, TERMINFO_BOOLEAN, @_);
}

=head2 tgetnum($id)

Gets the numeric value for termcap entry $id, or -1 if not available. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetnum {
    my $self = shift;
    return $self->_tget('termcap', -1, undef, undef, TERMINFO_NUMERIC, @_);
}

=head2 tigetnum($id)

Gets the numeric value for terminfo entry $id. Returns the value -2 if $id is not a numeric capability, or -1 if it is canceled or absent from the terminal description.

=cut

sub tigetnum {
    my $self = shift;
    return $self->_tget('terminfo', -1, -1, -2, TERMINFO_NUMERIC, @_);
}

=head2 tgetstr($id, $areap)

Returns a reference to termcap string entry for $id, or zero if it is not available. If $areap is defined, the pos()isition in the buffer is updated with the $id value, and its pos()isition is updated. Only the first two characters of the id parameter are compared in lookups.

=cut

sub tgetstr {
    my $self = shift;
    return $self->_tget('termcap', 0, undef, undef, TERMINFO_STRING, @_);
}

=head2 tigetstr($id)

Returns a reference to terminfo string entry for $id, or -1 if $id is not a string capabilitty, or 0 it is canceled or absent from terminal description.

=cut

sub tigetstr {
    my $self = shift;
    return $self->_tget('terminfo', 0, 0, -1, TERMINFO_STRING, @_);
}

=head2 tputs($str, $affcnt, $putc)

Applies padding information to the string $str and outputs it. The $str must be a terminfo string variable or the return value from tparm(), tgetstr(), or tgoto(). $affcnt is the number of lines affected, or 1 if not applicable. $putc is a putchar-like routine to which the characters are passed, one at a time.

=cut

sub tputs {
    my $self = shift;
    return $self->_tget(0, TERMINFO_STRING, @_);
}

#
# The following is a perl version of ncurses/lib_tparm.c.
#
# 	char *
# 	tparm(string, ...)
#
# 	Substitute the given parameters into the given string by the following
# 	rules (taken from terminfo(5)):
#
# 	     Cursor addressing and other strings  requiring  parame-
# 	ters in the terminal are described by a parameterized string
# 	capability, with like escapes %x in  it.   For  example,  to
# 	address  the  cursor, the cup capability is given, using two
# 	parameters: the row and column to  address  to.   (Rows  and
# 	columns  are  numbered  from  zero and refer to the physical
# 	screen visible to the user, not to any  unseen  memory.)  If
# 	the terminal has memory relative cursor addressing, that can
# 	be indicated by
#
# 	     The parameter mechanism uses  a  stack  and  special  %
# 	codes  to manipulate it.  Typically a sequence will push one
# 	of the parameters onto the stack and then print it  in  some
# 	format.  Often more complex operations are necessary.
#
# 	     The % encodings have the following meanings:
#
# 	     %%        outputs `%'
# 	     %c        print pop() like %c in printf()
# 	     %s        print pop() like %s in printf()
#            %[[:]flags][width[.precision]][doxXs]
#                      as in printf, flags are [-+#] and space
#                      The ':' is used to avoid making %+ or %-
#                      patterns (see below).
#
# 	     %p[1-9]   push ith parm
# 	     %P[a-z]   set dynamic variable [a-z] to pop()
# 	     %g[a-z]   get dynamic variable [a-z] and push it
# 	     %P[A-Z]   set static variable [A-Z] to pop()
# 	     %g[A-Z]   get static variable [A-Z] and push it
# 	     %l        push strlen(pop)
# 	     %'c'      push char constant c
# 	     %{nn}     push integer constant nn
#
# 	     %+ %- %* %/ %m
# 	               arithmetic (%m is mod): push(pop() op pop())
# 	     %& %| %^  bit operations: push(pop() op pop())
# 	     %= %> %<  logical operations: push(pop() op pop())
# 	     %A %O     logical and & or operations for conditionals
# 	     %! %~     unary operations push(op pop())
# 	     %i        add 1 to first two parms (for ANSI terminals)
#
# 	     %? expr %t thenpart %e elsepart %;
# 	               if-then-else, %e elsepart is optional.
# 	               else-if's are possible ala Algol 68:
# 	               %? c1 %t b1 %e c2 %t b2 %e c3 %t b3 %e c4 %t b4 %e b5 %;
#
# 	For those of the above operators which are binary and not commutative,
# 	the stack works in the usual way, with
# 			%gx %gy %m
# 	resulting in x mod y, not the reverse.
#
sub _save_char {
    my ($self, $bufp, $c) = (@_);

    if (ord($c) == 0) {
	$c = oct("200");
    }

    if ($log->is_debug) {
	$log->debugf('_save_char($c=\'%s\')', $c);
    }

    ${$bufp} .= $c;
}

sub _save_number {
    my ($self, $bufp, $fmt, $number, $len) = (@_);

    my $this = sprintf($fmt, $number);

    if ($log->is_debug) {
	$log->debugf('_save_number($fmt=\"%s\", $number=%d, $len=%d) = %d', $fmt, $number, $len, $this);
    }

    ${$bufp} .= $this;
}

sub _save_text {
    my ($self, $bufp, $fmt, $text, $len) = (@_);

    my $this = sprintf($fmt, $text);

    if ($log->is_debug) {
	$log->debugf('_save_text($fmt=\"%s\", $text=\"%s\", $len=%d) = \"%s\"', $fmt, $text, $len, $this);
    }

    ${$bufp} .= $this;
}

sub _parse_format {
    my ($self, $string, $index, $formatp, $lenp) = (@_);

    ${$lenp} = 0;
    my $done = 0;
    my $allowminus = 0;
    my $dot = 0;
    my $err = 0;
    my $my_width = 0;
    my $my_prec = 0;
    my $value = 0;

    ${$formatp} .= '%';
    my $indexmax = length($string) - 1;
    while ($index <= $indexmax && ! $done) {
	my $c = substr($string, $index, 1);
	if ($c eq 'c' || $c eq 'd' || $c eq 'o' || $c eq 'x' || $c eq 'X' || $c eq 's') {
	    ${$formatp} .= $c;
	    $done = 1;
	} elsif ($c eq '.') {
	    ${$formatp} .= $c;
	    $index++;
	    if ($dot) {
		$err = 1;
	    } else {
		$dot = 1;
		$my_width = $value;
	    }
	    $value = 0;
	} elsif ($c eq '#') {
	    ${$formatp} .= $c;
	    $index++;
	} elsif ($c eq ' ') {
	    ${$formatp} .= $c;
	    $index++;
	} elsif ($c eq ':') {
	    $index++;
	    $allowminus = 1;
	} elsif ($c eq '-') {
	    if ($allowminus) {
		${$formatp} .= $c;
		$index++;
	    } else {
		$done = 1;
	    }
	} else {
	    if ($c =~ /\d/) {
		$value = ($value * 10) + $c;
		${$formatp} .= $c;
		$index++;
	    } else {
		$done = 1;
	    }
	}
    }
    #
    # If we found an error, ignore (and remove) the flags.
    #
    if ($err) {
	$my_width = $my_prec = $value = 0;
	${$formatp} = "%" . substr($string, $index, 1);
    }
    #
    # Any value after '.' is the precision.  If we did not see '.', then
    # the value is the width.
    #
    if ($dot) {
	$my_prec = $value;
    } else {
	$my_width = $value;
    }
    #
    # return maximum string length in prin
    #
    ${$lenp} = ($my_width > $my_prec) ? $my_width : $my_prec;

    return $index;
}

sub _tparm_analyse {
    my ($self, $string, $p_is_sp, $popcountp) = (@_);

    my $lastpop = -1;
    my $number = 0;

    ${$popcountp} = 0;

    my $index = 0;
    my $indexmax = length($string) - 1;
    while ($index <= $indexmax) {
	my $c = substr($string, $index, 1);
	if ($c eq '%') {
	    $index++;
	    my $fmt_buff = '';
	    my $len;
	    $index = $self->_parse_format($string, $index, \$fmt_buff, \$len);
	    if ($index == $indexmax) {
		last;
	    }
	    $c = substr($string, $index, 1);
	    if ($c eq 'd' || $c eq 'o' || $c eq 'x' || $c eq 'X' || $c eq 'c') {
		if ($lastpop <= 0) {
		    $number++;
		}
		$lastpop = -1;
	    } elsif ($c eq 'l' || $c eq 's') {
		if ($lastpop > 0) {
		    $p_is_sp->[$lastpop - 1] = 1;
		}
		++$number;
	    } elsif ($c eq 'p') {
		$index++;
		my $i = substr($string, $index, 1);
		if ($i >= 0) {
		    $lastpop = $i;
		    if ($lastpop > ${$popcountp}) {
			${$popcountp} = $lastpop;
		    }
		}
	    } elsif ($c eq 'P') {
		++$number;
		++$index;
	    } elsif ($c eq 'g') {
		++$index;
	    } elsif ($c eq '\'') {
		$index += 2;
		$lastpop = -1;
	    } elsif ($c eq '{') {
		$index++;
		while (substr($string, $index, 1) =~ /\p{Number}/) {
		    $index++;
		}
	    } elsif ($c eq '+' || $c eq '-' || $c eq '*' || $c eq '/' ||
		     $c eq 'm' || $c eq 'A' || $c eq 'O' ||
		     $c eq '&' || $c eq '|' || $c eq '^' ||
		     $c eq '=' || $c eq '<' || $c eq '>') {
		$lastpop = -1;
		$number += 2;
	    } elsif ($c eq '!' || $c eq '~') {
		$lastpop = -1;
		++$number;
	    } elsif ($c eq 'i') {
		# will add 1 to first (usually two) parameters
	    }
	}
	$index++;
    }

    return $number;
}

sub _tparam_internal {
    my ($self, $string, @param) = (@_);

    my @p_is_s = (0) x scalar(@param);
    my $popcount = 0;
    my $level;

    #
    # Find the highest parameter-number referred to in the format string.
    # Use this value to limit the number of arguments copied from the
    # variable-length argument list.
    #
    my $number = $self->_tparm_analyse($string, \@p_is_s, \$popcount);
    if ($log->is_debug) {
	$log->debugf('\\@param  = %s', \@param);
	$log->debugf('\\@p_is_s = %s', \@p_is_s);
    }
    my $num_args = $popcount > $number ? $popcount : $number;

    for (my $i = 0; $i < $num_args; $i++) {
	#
	# A few caps (such as plab_norm) have string-valued parms.
	# We'll have to assume that the caller knows the difference, since
	# a char* and an int may not be the same size on the stack.  The
	# normal prototype for this uses 9 long's, which is consistent with
	# our va_arg() usage.
	#
	if ($p_is_s[$i]) {
	    $p_is_s[$i] = $param[$i];
	    $param[$i] = undef;
	}
    }

    #
    # This is a termcap compatibility hack.  If there are no explicit pop
    # operations in the string, load the stack in such a way that
    # successive pops will grab successive parameters.  That will make
    # the expansion of (for example) \E[%d;%dH work correctly in termcap
    # style, which means tparam() will expand termcap strings OK.
    #
    my @stack = ();
    if ($popcount == 0) {
	$popcount = $number;
	for (my $i = $number - 1; $i >= 0; $i--) {
	    if ($p_is_s[$i]) {
		$self->_spush(\@stack, $p_is_s[$i]);
	    } else {
		$self->_npush(\@stack, $param[$i]);
	    }
	}
    }

    my $index = 0;
    my $indexmax = length($string) - 1;
    my $outbuf = '';
    while ($index <= $indexmax) {
	my $c = substr($string, $index, 1);
	if ($log->is_debug) {
	    $log->debugf('_tparam_internal: $string index %d returns character \'%s\'', $index, $c);
	}
	if ($c ne '%') {
	    $self->_save_char(\$outbuf, $c);
	} else {
	    $index++;
	    my $fmt_buff = '';
	    my $len;
	    $index = $self->_parse_format($string, $index, \$fmt_buff, \$len);
	    if ($log->is_debug) {
		$log->debugf('_parse_format returns index %d, format %s, len %d', $index, $fmt_buff, $len);
	    }
	    if ($index == $indexmax) {
		last;
	    }
	    $c = substr($string, $index, 1);
	    if ($log->is_debug) {
		$log->debugf('_tparam_internal: $string index %d returns character \'%s\'', $index, $c);
	    }
	    if ($c eq '%') {
		$self->_save_char(\$outbuf, $c);
	    } elsif ($c eq 'd' || $c eq 'o' || $c eq 'x' || $c eq 'X') {
		$self->_save_number(\$outbuf, $fmt_buff, $self->_npop(\@stack), $len);
	    } elsif ($c eq 'c') {
		$self->_save_char(\$outbuf, $self->_npop(\@stack));
	    } elsif ($c eq 'l') {
		$self->_npush(\@stack, length($self->_spop(\@stack)));
	    } elsif ($c eq 's') {
		$self->_save_text(\$outbuf, $self->_spop(\@stack), $len);
	    } elsif ($c eq 'p') {
		$index++;
		my $c = substr($string, $index, 1);
		my $i = $c - 1;
		if ($p_is_s[$i]) {
		    $self->_spush(\@stack, $p_is_s[$i]);
		} else {
		    $self->_npush(\@stack, $param[$i]);
		}
	    } elsif ($c eq 'P') {
		$index++;
		my $c = substr($string, $index, 1);
		if ($c =~ /\p{Uppercase_Letter}/) {
		    my $i = ord($c) - ord('A');
		    $self->{_static_vars}->[$i] = $self->_npop(\@stack);
		} elsif ($c =~ /\p{Lowercase_Letter}/) {
		    my $i = ord($c) - ord('a');
		    $self->{_dynamic_vars}->[$i] = $self->_npop(\@stack);
		}
	    } elsif ($c eq 'g') {
		$index++;
		my $c = substr($string, $index, 1);
		if ($c =~ /\p{Uppercase_Letter}/) {
		    my $i = ord($c) - ord('A');
		    $self->_npush(\@stack, $self->{_static_vars}->[$i]);
		} elsif ($c =~ /\p{Lowercase_Letter}/) {
		    my $i = ord($c) - ord('a');
		    $self->_npush(\@stack, $self->{_dynamic_vars}->[$i]);
		}
	    } elsif ($c eq '\'') {
		$index++;
		my $c = substr($string, $index, 1);
		$self->_npush(\@stack, $c);
		$index++;
	    } elsif ($c eq '{') {
		$number = 0;
		$index++;
		while (($c = substr($string, $index, 1)) =~ /\d/) {
		    if ($log->is_debug) {
			$log->debugf('_tparam_internal[\'{\' case]: $string index %d returns character \'%s\'', $index, $c);
		    }
		    $number = ($number * 10) + $c;
		    $index++;
		}
		$self->_npush(\@stack, $number);
	    } elsif ($c eq '+') {
		$self->_npush(\@stack, $self->_npop(\@stack) + $self->_npop(\@stack));
	    } elsif ($c eq '-') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $x - $y);
	    } elsif ($c eq '*') {
		$self->_npush(\@stack, $self->_npop(\@stack) * $self->_npop(\@stack));
	    } elsif ($c eq '/') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $y ? int($x / $y) : 0);
	    } elsif ($c eq 'm') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $y ? int($x % $y) : 0);
	    } elsif ($c eq 'A') {
		$self->_npush(\@stack, $self->_npop(\@stack) && $self->_npop(\@stack));
	    } elsif ($c eq 'O') {
		$self->_npush(\@stack, $self->_npop(\@stack) || $self->_npop(\@stack));
	    } elsif ($c eq '&') {
		$self->_npush(\@stack, $self->_npop(\@stack) & $self->_npop(\@stack));
	    } elsif ($c eq '|') {
		$self->_npush(\@stack, $self->_npop(\@stack) | $self->_npop(\@stack));
	    } elsif ($c eq '^') {
		$self->_npush(\@stack, $self->_npop(\@stack) ^ $self->_npop(\@stack));
	    } elsif ($c eq '=') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $x == $y);
	    } elsif ($c eq '<') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $x < $y);
	    } elsif ($c eq '>') {
		my $y = $self->_npop(\@stack);
		my $x = $self->_npop(\@stack);
		$self->_npush(\@stack, $x > $y);
	    } elsif ($c eq '!') {
		$self->_npush(\@stack, ! $self->_npop(\@stack));
	    } elsif ($c eq '~') {
		$self->_npush(\@stack, ~ $self->_npop(\@stack));
	    } elsif ($c eq 'i') {
		if ($#p_is_s >= 0 && $p_is_s[0] == 0) {
		    $param[0]++;
		}
		if ($#p_is_s >= 1 && $p_is_s[1] == 0) {
		    $param[1]++;
		}
	    } elsif ($c eq '?') {
	    } elsif ($c eq 't') {
		my $x = $self->_npop(\@stack);
		if (! $x) {
		    # scan forward for %e or %; at level zero
		    $index++;
		    $level = 0;
		    while ($index <= $indexmax) {
			$c = substr($string, $index, 1);
			if ($log->is_debug) {
			    $log->debugf('_tparam_internal[\'t\' case]: $string index %d returns character \'%s\'', $index, $c);
			}
			if ($c eq '%') {
			    $index++;
			    $c = substr($string, $index, 1);
			    if ($log->is_debug) {
				$log->debugf('_tparam_internal[\'t%\' case]: $string index %d returns character \'%s\'', $index, $c);
			    }
			    if ($c eq '?') {
				$level++;
			    } elsif ($c eq ';') {
				if ($level > 0) {
				    $level--;
				} else {
				    last;
				}
			    } elsif ($c eq 'e' && $level == 0) {
				last;
			    }
			}
		    }
		}
	    } elsif ($c eq 'e') {
		# scan forward for a %; at level zero
		$index++;
		$level = 0;
		while ($index <= $indexmax) {
		    my $c = substr($string, $index, 1);
		    if ($log->is_debug) {
			$log->debugf('_tparam_internal[\'e\' case]: $string index %d returns character \'%s\'', $index, $c);
		    }
		    if ($c eq '%') {
			$index++;
			$c = substr($string, $index, 1);
			if ($log->is_debug) {
			    $log->debugf('_tparam_internal[\'e%\' case]: $string index %d returns character \'%s\'', $index, $c);
			}
			if ($c eq '?') {
			    $level++;
			} elsif ($c eq ';') {
			    if ($level > 0) {
				$level--;
			    } else {
				last;
			    }
			}
		    }
		}
	    } elsif ($c eq ';') {
	    }
	}
	$index++;
    }

    if ($log->is_debug) {
	$log->debugf('_tparam_internal: returns "%s"', $outbuf);
    }
    return $outbuf;
}

sub _spush {
    my ($self, $stackp, $x) = @_;

    if ($log->is_debug) {
	$log->debugf('_spush($x=\"%s\")', $x);
    }

    push(@{$stackp}, {num_type => 0, str => $x});
}

sub _spop {
    my ($self, $stackp) = @_;

    my $pop = pop(@{$stackp});

    if ($log->is_debug) {
	$log->debugf('_spop() returns \"%s\"', $pop->{str});
    }

    return $pop->{str};
}

sub _npush {
    my ($self, $stackp, $x) = @_;

    if ($log->is_debug) {
	$log->debugf('_npush($x=%d)', $x);
    }

    push(@{$stackp}, {num_type => 1, num => $x});
}

sub _npop {
    my ($self, $stackp) = @_;

    my $pop = pop(@{$stackp});

    if ($log->is_debug) {
	$log->debugf('_npop() returns %d', $pop->{num});
    }

    return $pop->{num};
}

=head2 tparm($self, $string, @param)

Instantiates the string $string with parameters @param. Returns the string with the parameters applied.
=cut

sub tparm {
    my ($self, $string, @param) = (@_);

    return $self->_tparam_internal($string, @param);
}

=head2 tgoto($self, $string, $col, $row)

Instantiates  instantiates the parameters into the given capability. The output from this routine is to be passed to tputs.
=cut

sub tgoto {
    my ($self, $string, @param) = (@_);

    return $self->_tparam_internal($string, @param);
}

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

L<Marpa::R2|http://metacpan.org/release/Marpa-R2>

=cut

1;
