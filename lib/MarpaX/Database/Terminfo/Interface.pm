use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Interface;
use MarpaX::Database::Terminfo;
use MarpaX::Database::Terminfo::String;
use MarpaX::Database::Terminfo::Constants qw/:all/;
use File::ShareDir qw/:ALL/;
use Carp qw/carp croak/;
use Storable qw/fd_retrieve/;
use Time::HiRes;
use Log::Any qw/$log/;
use constant BAUDBYTE => 9; # From GNU Ncurses: 9 = 7 bits + 1 parity + 1 stop
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

a file path to the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the following txt key/value.

=item $opts->{txt} or $ENV{MARPAX_DATABASE_TERMINFO_TXT}

a text version of the terminfo database. This module will then parse it using Marpa. If set to any true value, this setting has precedence over the following bin key/value.

=item $opts->{bin} or $ENV{MARPAX_DATABASE_TERMINFO_BIN}

a path to a binary version of the terminfo database, created using Storable module. This module is distributed with such a binary file, which contains the GNU ncurses definitions. The default behaviour is to use this file.

=item $opts->{caps} or $ENV{MARPAX_DATABASE_TERMINFO_CAPS}

a path to a text version of the terminfo<->termcap translation. This module is distributed with GNU ncurses translation files, namely: ncurses-Caps (default), ncurses-Caps.aix4 (default on AIX), ncurses-Caps.hpux11 (default on HP/UX), ncurses-Caps.keys, ncurses-Caps.osf1r5 (default on OSF1) and ncurses-Caps.uwin.

=item $opts->{cache_stubs} or $ENV{MARPAX_DATABASE_TERMINFO_CACHE_STUBS}

a flag saying if the compiled stubs of string features value should be cached or not. Each time a terminfo entry is loaded using tgetent(), every string feature is parsed using Marpa. If this is a true value, when another terminfo is loaded, there is no need to reparse a string feature value already parsed. Default is true.

=item $opts->{cache_stubs_as_txt} or $ENV{MARPAX_DATABASE_TERMINFO_CACHE_STUBS_AS_TXT}

a flag saying if the string versions (i.e. not evaled) stubs of string features value should be cached or not. Each time a terminfo entry is loaded using tgetent(), every string feature is parsed using Marpa. If this is a true value, when another terminfo is loaded, there is no need to reparse a string feature value already parsed. Default is true.

=item $opts->{stubs_txt} or $ENV{MARPAX_DATABASE_TERMINFO_STUBS_TXT}

a path to a text version of the terminfo<->stubs translation, created using Data::Dumper. The content of this file is the text version of all stubs, that will all be evaled after loading. This option is used only if cache_stubs is on. If set to any true value, this setting has precedence over the following bin key/value. Mostly useful for debugging or readability: the created stubs are immediately comprehensive, and if there is a bug in them, this option could be used.

=item $opts->{stubs_bin} or $ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN}

a path to a binary version of the terminfo<->stubs translation, created using Storable module. The content of this file is the text version of all stubs, that will all be evaled after loading. This option is used only if cache_stubs is on. This module is distributed with such a binary file, which contains the GNU ncurses stubs definitions. The default behaviour is to use this file.

=back

Default terminal setup is done using the $ENV{TERM} environment variable, if it exist, or 'unknown'. The database used is not a compiled database as with GNU ncurses, therefore the environment variable TERMINFO is not used. Instead, a compiled database should a perl's Storable version of a text database parsed by Marpa. See $ENV{MARPAX_DATABASE_TERMINFO_BIN} upper.

=cut

sub new {
    my ($class, $optp) = @_;

    $optp //= {};

    if (ref($optp) ne 'HASH') {
	croak 'Options must be a reference to a HASH';
    }

    my $file = $optp->{file} // $ENV{MARPAX_DATABASE_TERMINFO_FILE} // '';
    my $txt  = $optp->{txt}  // $ENV{MARPAX_DATABASE_TERMINFO_TXT}  // '';
    my $bin  = $optp->{bin}  // $ENV{MARPAX_DATABASE_TERMINFO_BIN}  // dist_file('MarpaX-Database-Terminfo', 'share/ncurses-terminfo.storable');
    my $caps = $optp->{caps} // $ENV{MARPAX_DATABASE_TERMINFO_CAPS} // (
	$^O eq 'aix'     ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.aix4')   :
	$^O eq 'hpux'    ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.hpux11') :
	$^O eq 'dec_osf' ? dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps.osf1r5') :
	dist_file('MarpaX-Database-Terminfo', 'share/ncurses-Caps'));

    my $cache_stubs_as_txt = $optp->{cache_stubs_as_txt} // $ENV{MARPAX_DATABASE_TERMINFO_CACHE_STUBS_AS_TXT} // 1;
    my $cache_stubs        = $optp->{cache_stubs}        // $ENV{MARPAX_DATABASE_TERMINFO_CACHE_STUBS}        // 1;
    my $stubs_txt;
    my $stubs_bin;
    if ($cache_stubs) {
	$stubs_txt   = $optp->{stubs_txt} // $ENV{MARPAX_DATABASE_TERMINFO_STUBS_TXT} // '';
	$stubs_bin   = $optp->{stubs_bin} // $ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN} // dist_file('MarpaX-Database-Terminfo', 'share/ncurses-terminfo-stubs.storable');
    } else {
	$stubs_txt = '';
	$stubs_bin = '';
    }

    # -------------
    # Load Database
    # -------------
    my $db = undef;
    if ($file) {
	my $fh;
	if ($log->is_debug) {
	    $log->debugf('Loading %s', $file);
	}
	if (! open($fh, '<', $file)) {
	    carp "Cannot open $file, $!";
	} else {
	    my $content = do {local $/; <$fh>;};
	    close($fh) || carp "Cannot close $file, $!";
	    if ($log->is_debug) {
		$log->debugf('Parsing %s', $file);
	    }
	    $db = MarpaX::Database::Terminfo->new()->parse(\$content)->value();
	}
    } elsif ($txt) {
	if ($log->is_debug) {
	    $log->debugf('Parsing txt');
	}
	$db = MarpaX::Database::Terminfo->new()->parse(\$txt)->value();
    } else {
	my $fh;
	if ($log->is_debug) {
	    $log->debugf('Loading %s', $bin);
	}
	if (! open($fh, '<', $bin)) {
	    carp "Cannot open $bin, $!";
	} else {
	    $db = fd_retrieve($fh);
	    close($fh) || carp "Cannot close $bin, $!";
	}
    }
    # -----------------------
    # Load terminfo<->termcap
    # -----------------------
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
	    carp "Cannot open $caps, $!";
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
    # -----------------
    # Load stubs as txt
    # -----------------
    my $cached_stubs_as_txt = {};
    if ($cache_stubs) {
	if ($stubs_txt) {
	    my $fh;
	    if ($log->is_debug) {
		$log->debugf('Loading %s', $stubs_txt);
	    }
	    if (! open($fh, '<', $stubs_txt)) {
		carp "Cannot open $stubs_txt, $!";
	    } else {
		my $content = do {local $/; <$fh>;};
		close($fh) || carp "Cannot close $stubs_txt, $!";
		if ($log->is_debug) {
		    $log->debugf('Evaluating %s', $stubs_txt);
		}
		{
		    #
		    # Because Data::Dumper have $VARxxx
		    #
		    no strict;
		    #
		    # Untaint data
		    #
		    my ($untainted) = $content =~ m/(.*)/s;
		    #
		    # Same comment as in _stub();
		    # Is there any other way to pass Perl::Critic but doing twice the eval ?
		    # Perl::Critic disklike eval $stub_as_txt.
		    # But eval {$stub_as_txt} will return the string, not the evaled version...
		    #
		    $cached_stubs_as_txt = eval {eval $untainted};
		}
	    }
	} elsif ($stubs_bin) {
	    my $fh;
	    if ($log->is_debug) {
		$log->debugf('Loading %s', $stubs_bin);
	    }
	    if (! open($fh, '<', $stubs_bin)) {
		carp "Cannot open $stubs_bin, $!";
	    } else {
		$cached_stubs_as_txt = fd_retrieve($fh);
		close($fh) || carp "Cannot close $stubs_bin, $!";
	    }
	}
    }

    my $self = {
	_terminfo_db => $db,
	_terminfo_current => undef,
	_t2other => \%t2other,
	_c2other => \%c2other,
	_capalias => \%capalias,
	_infoalias => \%infoalias,
	_stubs => {},
	_cache_stubs => $cache_stubs,
	_cached_stubs => {},
	_cache_stubs_as_txt => $cache_stubs_as_txt,
	_cached_stubs_as_txt => $cached_stubs_as_txt,
	_flush => undef,
    };

    bless($self, $class);

    #
    # Initialize
    #
    $self->_terminfo_init();

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

=head2 flush($self, $cb, @args);

Defines a flush callback function $cb with optional @arguments. Such callback is used in some case like a delay. If called as $self->flush(), returns undef or a reference to an array containing [$cb, @args].

=cut

sub flush {
    my $self = shift;
    if (@_) {
	$self->{_flush} = \@_;
    }
    return $self->{_flush};
}

=head2 tgetent($name[, $fh])

Loads the entry for $name. Returns 1 on success, 0 if no entry, -1 if the terminfo database could not be found. This function will warn if the database has a problem. $name must be an alias in the terminfo database. If multiple entries have the same alias, the first that matches is taken. The variables PC, UP and BC are set by tgetent to the terminfo entry's data for pad_char, cursor_up and backspace_if_not_bs, respectively. The variable ospeed is set in a system-specific coding to reflect the terminal speed, and is $ENV{TERMINFO_OSPEED} if defined, otherwise we attempt to get the value using POSIX interface, or 0. ospeed should be a value between 0 and 15, or 4097 and 4105, or 4107 and 4111. The variable baudrate can be $ENV{TERMINFO_BAUDRATE} (unchecked, i.e. at your own risk) or is derived from ospeed, or 0. $fh is an optional opened filehandle, used to guess about baudrate and ospeed. Defaults to fileno(\*STDIN) or 0. When loading a terminfo, termcap and variable entries are automatically derived using the caps parameter as documented in _new_instance().

=cut

sub _find {
    my ($self, $name, $from) = @_;

    my $rc = undef;
    $from //= '';

    if ($log->is_debug) {
	if ($from) {
	    $log->debugf('Loading %s -> %s', $from, $name);
	} else {
	    $log->debugf('Loading %s', $name);
	}
    }

    my $terminfo_db = $self->_terminfo_db;
    if (defined($terminfo_db)) {
	foreach (@{$terminfo_db}) {
	    my $terminfo = $_;

	    if (grep {$_ eq $name} @{$terminfo->{alias}}) {
		if ($log->is_trace) {
		    $log->tracef('Found alias \'%s\' in terminfo with aliases %s longname \'%s\'', $name, $terminfo->{alias}, $terminfo->{longname});
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
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] New cancellation %s', $name, $cancelled);
		}
		++$i;
	    } elsif ($feature->{type} == TERMINFO_STRING && $feature->{name} eq 'use') {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] use=\'%s\' with cancellations %s', $name, $feature->{value}, [ keys %cancelled ]);
		}
		my $insert = $self->_find($feature->{value}, $name);
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
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] New feature %s', $name, $feature);
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
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Dropping cancellation \'%s\' from terminfo', $name, $found->{feature}->[$i]->{name});
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
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Dropping commented \'%s\' from terminfo', $name, $found->{feature}->[$i]->{name});
		}
		splice(@{$found->{feature}}, $i, 1);
	    }
	    --$i;
	}
    }
    #
    # The raw terminfo is is the features referenced array.
    # For faster lookup we fill the terminfo, termcap and variable hashes.
    # These are used in the subroutine _tget().
    #
    $found->{terminfo} = {};
    $found->{termcap} = {};
    $found->{variable} = {};
    my $pad_char = undef;
    my $cursor_up = undef;
    my $backspace_if_not_bs = undef;
    {
	foreach (@{$found->{feature}}) {
	    my $feature = $_;
	    my $key = $feature->{name};
	    #
	    # terminfo lookup
	    #
	    if (! exists($found->{terminfo}->{$key})) {
		$found->{terminfo}->{$key} = $feature;
	    } else {
		if ($log->is_warn) {
		    $log->warnf('[Loading %s] Multiple occurence of feature \'%s\'', $name, $key);
		}
	    }
	    #
	    # Translation exist ?
	    #
	    if (! exists($self->_t2other->{$key})) {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Untranslated feature \'%s\'', $name, $key);
		}
		next;
	    }
	    #
	    # Yes, check consistency
	    #
	    my $type = $self->_t2other->{$key}->{type};
	    if ($feature->{type} != $type) {
		if ($log->is_warn) {
		    $log->warnf('[Loading %s] Wrong type when translating feature \'%s\': %d instead of %d', $name, $key, $type, $feature->{type});
		}
		next;
	    }
	    #
	    # Convert to termcap
	    #
	    my $termcap  = $self->_t2other->{$key}->{termcap};
	    if (! defined($termcap)) {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Feature \'%s\' has no termcap equivalent', $name, $key);
		}
	    } else {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Pushing termcap feature \'%s\'', $name, $termcap);
		}
		if (! exists($found->{termcap}->{$termcap})) {
		    $found->{termcap}->{$termcap} = $feature;
		} else {
		    if ($log->is_warn) {
			$log->warnf('[Loading %s] Multiple occurence of termcap \'%s\'', $name, $termcap);
		    }
		}
	    }
	    #
	    # Convert to variable
	    #
	    my $variable = $self->_t2other->{$key}->{variable};
	    if (! defined($variable)) {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Feature \'%s\' has no variable equivalent', $name, $key);
		}
	    } else {
		if ($log->is_trace) {
		    $log->tracef('[Loading %s] Pushing variable feature \'%s\'', $name, $variable);
		}
		if (! exists($found->{variable}->{$key})) {
		    $found->{variable}->{$key} = $feature;
		    #
		    # Keep track of pad_char, cursor_up and backspace_if_not_bs
		    if ($type == TERMINFO_STRING) {
			if ($variable eq 'pad_char') {
			    $pad_char = $feature;
			    if ($log->is_trace) {
				$log->tracef('[Loading %s] pad_char is \'%s\'', $name, $pad_char->{value});
			    }
			} elsif ($variable eq 'cursor_up') {
			    $cursor_up = $feature;
			    if ($log->is_trace) {
				$log->tracef('[Loading %s] cursor_up is \'%s\'', $name, $cursor_up->{value});
			    }
			} elsif ($variable eq 'backspace_if_not_bs') {
			    $backspace_if_not_bs = $feature;
			    if ($log->is_trace) {
				$log->tracef('[Loading %s] backspace_if_not_bs is \'%s\'', $name, $backspace_if_not_bs->{value});
			    }
			}
		    }
		} else {
		    if ($log->is_warn) {
			$log->warnf('[Loading %s] Multiple occurence of variable \'%s\'', $name, $key);
		    }
		}
	    }
	}

	# The variables PC, UP and BC are set by tgetent to the terminfo entry's data for pad_char, cursor_up and backspace_if_not_bs, respectively.
	#
	# PC is used in the delay function.
	#
	if (defined($pad_char)) {
	    if ($log->is_trace) {
		$log->tracef('[Loading %s] Initialized PC to \'%s\'', $name, $pad_char->{value});
	    }
	    $found->{variable}->{PC} = $pad_char;
	}
	#
	# UP is not used by ncurses.
	#
	if (defined($cursor_up)) {
	    if ($log->is_trace) {
		$log->tracef('[Loading %s] Initialized UP to \'%s\'', $name, $cursor_up->{value});
	    }
	    $found->{variable}->{UP} = $cursor_up;
	}
	#
	# BC is used in the tgoto emulation.
	#
	if (defined($backspace_if_not_bs)) {
	    if ($log->is_trace) {
		$log->tracef('[Loading %s] Initialized BC to \'%s\'', $name, $backspace_if_not_bs->{value});
	    }
	    $found->{variable}->{BC} = $backspace_if_not_bs;
	}
	#
	# The variable ospeed is set in a system-specific coding to reflect the terminal speed.
	#
	my ($baudrate, $ospeed) = $self->_get_ospeed_and_baudrate($fh);
	my $OSPEED = {name => 'ospeed', type => TERMINFO_NUMERIC, value => $ospeed};
	if ($log->is_trace) {
	    $log->tracef('[Loading %s] Initialized ospeed to %d', $name, $OSPEED->{value});
	}
	$found->{variable}->{ospeed} = $OSPEED;
	#
	# The variable baudrate is used eventually in delay
	#
	my $BAUDRATE = {name => 'baudrate', type => TERMINFO_NUMERIC, value => $baudrate};
	if ($log->is_trace) {
	    $log->tracef('[Loading %s] Initialized baudrate to %d', $name, $BAUDRATE->{value});
	}
	$found->{variable}->{baudrate} = $BAUDRATE;
	#
	# ospeed and baudrate are add-ons, not in the terminfo database.
	# If you look to the terminfo<->Caps translation files, you will see that none of ospeed
	# nor baudrate variables exist. Nevertheless, we check if they these entries WOULD exist
	# and warn about it, because we would overwrite them.
	#
	if (exists($found->{terminfo}->{ospeed})) {
	    if ($log->is_warn) {
		$log->tracef('[Loading %s] Overwriting ospeed to \'%s\'', $name, $OSPEED->{value});	
	    }
	}
	$self->{terminfo}->{baudrate} = $found->{variable}->{baudrate};
	if (exists($found->{terminfo}->{baudrate})) {
	    if ($log->is_warn) {
		$log->tracef('[Loading %s] Overwriting baudrate to \'%s\'', $name, $BAUDRATE->{value});	
	    }
	}
	$self->{terminfo}->{baudrate} = $found->{variable}->{baudrate};
    }

    #
    # Remove any static/dynamic var
    #
    $found->{_static_vars} = [];
    $found->{_dynamic_vars} = [];

    $self->_terminfo_current($found);

    #
    # Create stubs for every string
    #
    $self->_stubs($name);

    return 1;
}

sub _stub {
    my ($self, $featurevalue) = @_;

    if ($self->{_cache_stubs}) {
	if (exists($self->{_cached_stubs}->{$featurevalue})) {
	    if ($log->is_trace) {
		$log->tracef('Getting \'%s\' compiled stub from cache', $featurevalue);
	    }
	    $self->{_stubs}->{$featurevalue} = $self->{_cached_stubs}->{$featurevalue};
	}
    }
    if (! exists($self->{_stubs}->{$featurevalue})) {
	my $stub_as_txt = undef;
	if ($self->{_cache_stubs_as_txt}) {
	    if (exists($self->{_cached_stubs_as_txt}->{$featurevalue})) {
		if ($log->is_trace) {
		    $log->tracef('Getting \'%s\' stub as txt from cache', $featurevalue);
		}
		$stub_as_txt = $self->{_cached_stubs_as_txt}->{$featurevalue};
	    }
	}
	if (! defined($stub_as_txt)) {
	    #
	    # Very important: we restore the ',': it is parsed as either
	    # and EOF (normal case) or an ENDIF (some entries are MISSING
	    # the '%;' ENDIF tag at the very end). I am not going to change
	    # the grammar when documentation says that a string follows
	    # the ALGOL68, which has introduced the ENDIF tag to solve the
	    # IF-THEN-ELSE-THEN ambiguity.
	    # There is no side-effect doing so, but keeping the grammar clean.
	    my $string = "$featurevalue,";
	    if ($log->is_trace) {
		$log->tracef('Parsing \'%s\'', $string);
	    }
	    my $parseTreeValue = MarpaX::Database::Terminfo::String->new()->parse(\$string)->value();
	    #
	    # Enclose the result for anonymous subroutine evaluation
	    # We reindent everything by two spaces
	    #
	    my $indent = join("\n", map {"  $_"} @{${$parseTreeValue}});
	    $stub_as_txt = "
#
# Stub version of: $featurevalue
#
sub {
  my (\$self, \$dynamicp, \$staticp, \@param) = \@_;
  # Initialized with \@param to be termcap compatible
  my \@iparam = \@param;
  my \$rc = '';

$indent

  return \$rc;
}
";
	    if ($log->is_trace) {
		$log->tracef('Parsing \'%s\' gives stub: %s', $string, $stub_as_txt);
	    }
	    if ($self->{_cache_stubs_as_txt}) {
		$self->{_cached_stubs_as_txt}->{$featurevalue} = $stub_as_txt;
	    }
	}
	if ($log->is_trace) {
	    $log->tracef('Compiling \'%s\' stub', $featurevalue);
	}
	#
	# Is there any other way to pass Perl::Critic but doing twice the eval ?
	# Perl::Critic disklike eval $stub_as_txt.
	# But eval {$stub_as_txt} will return the string, not the evaled version...
	#
	$self->{_stubs}->{$featurevalue} = eval {eval $stub_as_txt};
	if ($@) {
	    carp "Problem with $featurevalue\n$stub_as_txt\n$@\nReplaced by a stub returning empty string...";
	    $self->{_stubs}->{$featurevalue} = sub {return '';};
	}
	if ($self->{_cache_stubs}) {
	    $self->{_cached_stubs}->{$featurevalue} = $self->{_stubs}->{$featurevalue};
	}
    }

    return $self->{_stubs}->{$featurevalue};
}

sub _stubs {
    my ($self, $name) = @_;

    $self->{_stubs} = {};

    foreach (values %{$self->_terminfo_current->{terminfo}}) {
	my $feature = $_;
	if ($feature->{type} == TERMINFO_STRING) {
	    $self->_stub($feature->{value});
	}
    }
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
		if ($log->is_trace) {
		    $log->tracef('POSIX::Termios->new() failure, %s', $@);
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
		if ($log->is_trace) {
		    $log->tracef('Trying to get attributes on fileno %d', $fileno);
		}
		eval {$termios->getattr($fileno)};
		if ($@) {
		    if ($log->is_trace) {
			$log->tracef('POSIX::Termios::getattr(%d) failure, %s', $fileno, $@);
		    }
		    $termios = undef;
		}
	    }
	}
	if (defined($termios)) {
	    my $this = eval { $termios->getospeed() };
	    if (! defined($ospeed)) {
		if ($log->is_trace) {
		    $log->tracef('getospeed() failure, %s', $@);
		}
	    } else {
		$ospeed = $this;
		if ($log->is_trace) {
		    $log->tracef('getospeed() returned %d', $ospeed);
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
    my $found = undef;

    if ($self->_terminfo_init()) {
	#
	# First lookup in the hashes. If found, we will get the raw terminfo feature entry.
	#
	if (! exists($self->_terminfo_current->{$space}->{$id})) {
	    #
	    # No such entry
	    #
	    if ($log->is_trace) {
		$log->tracef('No %s entry with id \'%s\'', $space, $id);
	    }
	} else {
	    #
	    # Get the raw terminfo entry. The only entries for which it may not There is no check, it must exist by construction, c.f.
	    # routine tgetent(), even for variables ospeed and baudrate that are add-ons.
	    #
	    my $t = $self->_terminfo_current->{$space}->{$id};
	    my $feature = $self->_terminfo_current->{terminfo}->{$t->{name}};
	    if ($log->is_trace) {
		$log->tracef('%s entry with id \'%s\' maps to terminfo feature %s', $space, $id, $feature);
	    }
	    if (defined($default_if_cancelled) && exists($self->_terminfo_current->{cancelled}->{$feature->{name}})) {
		if ($log->is_trace) {
		    $log->tracef('Cancelled %s feature %s', $space, $feature->{name});
		}
		$rc = $default_if_cancelled;
	    } else {
		#
		# Check if this is the correct type
		#
		if ($feature->{type} == $type) {
		    $found = $feature;
		    if ($type == TERMINFO_STRING) {
			$rc = \$feature->{value};
		    } else {
			$rc = $feature->{value};
		    }
		} elsif (defined($default_if_wrong_type)) {
		    if ($log->is_trace) {
			$log->tracef('Found %s feature %s with type %d != %d', $space, $id, $feature->{type}, $type);
		    }
		    $rc = $default_if_wrong_type;
		}
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

=head2 delay($ms)

Do a delay of $ms milliseconds when producing the output. If the current terminfo variable no_pad_char is true, or if there is no PC variable, do a system sleep. Otherwise use the PC variable as many times as necessary followed by a flush callback. Do nothing if outside of a "producing output" context (i.e. tputs(), etc...). Please note that delay by itself in the string is not recognized as a grammar lexeme. This is tputs() that is seeing the delay.

=cut

sub delay {
    my ($self, $ms) = @_;

    #
    # $self->{_outch} is created/destroyed by tputs() and al.
    #
    my $outch = $self->{_outch};
    if (defined($outch)) {
	my $PC = $self->tvgetstr('PC');
	if ($self->tvgetflag('no_pad_char') == 1 || ref($PC) ne 'SCALAR') {
	    usleep($ms);
	} else {
	    #
	    # tparm(${$PC}) should be constant, but who knows
	    #
	    my $nullcount = ($ms * $self->tvgetnum('baudrate')) / (BAUDBYTE * 1000);
	    #
	    # We have no interface to 'tack' program, so no need to have a global for _nulls_sent
	    #
	    while ($nullcount-- > 0) {
		&$outch($self->tparm(${$PC}));
	    }
	    my $flushp = $self->flush;
	    if (defined($flushp)) {
		my ($cb, @args) = @{$flushp};
		&$cb(@args);
	    }
	}
    }
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

=head2 tvgetflag($id)

Gets the boolean value for terminfo variable $id. Returns the value -1 if $id is not a boolean capability, or 0 if it is canceled or absent from the terminal description.

=cut

sub tvgetflag {
    my $self = shift;
    return $self->_tget('variable', 0, 0, -1, TERMINFO_BOOLEAN, @_);
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

=head2 tvgetnum($id)

Gets the numeric value for terminfo variable $id. Returns the value -2 if $id is not a numeric capability, or -1 if it is canceled or absent from the terminal description.

=cut

sub tvgetnum {
    my $self = shift;
    return $self->_tget('variable', -1, -1, -2, TERMINFO_NUMERIC, @_);
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

=head2 tvgetstr($id)

Returns a reference to terminfo variable entry for $id, or -1 if $id is not a string capabilitty, or 0 it is canceled or absent from terminal description.

=cut

sub tvgetstr {
    my $self = shift;
    return $self->_tget('variable', 0, 0, -1, TERMINFO_STRING, @_);
}

=head2 tputs($str, $affcnt, $putc)

Applies padding information to the string $str and outputs it. The $str must be a terminfo string variable or the return value from tparm(), tgetstr(), or tgoto(). $affcnt is the number of lines affected, or 1 if not applicable. $putc is a putchar-like routine to which the characters are passed, one at a time.

=cut

sub tputs {
    my $self = shift;
    return $self->_tget(0, TERMINFO_STRING, @_);
}

=head2 tparm($self, $string, @param)

Instantiates the string $string with parameters @param. Returns the string with the parameters applied.
=cut

sub _tparm {
    my ($self, $string, @param) = (@_);

    my $stub = $self->_stub($string);

    return $self->$stub($self->_terminfo_current->{_dynamic_vars}, $self->_terminfo_current->{_static_vars}, @param);
}

sub tparm {
    my ($self, $string, @param) = (@_);

    return $self->_tparm($string, @param);
}

=head2 tgoto($self, $string, $col, $row)

Instantiates  instantiates the parameters into the given capability. The output from this routine is to be passed to tputs.
=cut

sub tgoto {
    my ($self, $string, @param) = (@_);

    return $self->_tparm($string, @param);
}

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

L<Marpa::R2|http://metacpan.org/release/Marpa-R2>

=cut

1;
