use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::String::Grammar::Actions;
use MarpaX::Database::Terminfo::Constants qw/:chars/;
use Carp qw/carp/;
use Log::Any qw/$log/;

# ABSTRACT: Terminfo grammar actions

# VERSION

=head1 DESCRIPTION

This modules give the actions associated to terminfo grammar. The value will be an anonymous stub that will accept $self, a reference to static_vars array, and a reference to dynamic_vars array in input, and tparm() arguments. The output will be the parameterized string.

=cut

=head2 new($class)

Instance a new object.

=cut

sub new {
    my $class = shift;
    my $self = {_level => 0};
    bless($self, $class);
    return $self;
}

sub _doPushLevel {
    my ($self) = @_;

    $self->{_level}++;
    return "my \$rc = '';";
}

sub _doEndLevel {
    my ($self) = @_;

    $self->{_level}--;
    return "\$rc;";
}

=head2 addEscapedCharacterToRc($self, $c)

Generates code that appends escaped character $c to the output of generated code.

=cut

sub addEscapedCharacterToRc {
    my ($self, $c) = @_;

    if ($log->is_trace) {
	$log->tracef('addEscapedCharacterToRc(c="%s")', $c);
    }

    my $rc = '';

    if ($c eq '\\E' || $c eq '\\e') {
	$rc = TERMINFO_ESC;
    } elsif ($c eq '\\n') {
	$rc = TERMINFO_NL;
    } elsif ($c eq '\\l') {
	$rc = TERMINFO_LF;
    } elsif ($c eq '\\r') {
	$rc = TERMINFO_CR;
    } elsif ($c eq '\\b') {
	$rc = TERMINFO_TAB;
    } elsif ($c eq '\\b') {
	$rc = TERMINFO_BS;
    } elsif ($c eq '\\f') {
	$rc = TERMINFO_FF;
    } elsif ($c eq '\\s') {
	$rc = TERMINFO_SP;
    } elsif (substr($c, 0, 1) eq '^') {
	#
	# In perl, control-X is \cX, we support the ASCII C0 set + DEL.
	# Here the terminfo string really know exactly what it wants -;
	#
	my $this = $c;
	substr($this, 0, 1, '');
	my $rc;
	if ($this eq '@') {
	    $rc = "\c@";
	} elsif ($this eq 'A') {
	    $rc = "\cA";
	} elsif ($this eq 'B') {
	    $rc = "\cB";
	} elsif ($this eq 'C') {
	    $rc = "\cC";
	} elsif ($this eq 'D') {
	    $rc = "\cD";
	} elsif ($this eq 'E') {
	    $rc = "\cE";
	} elsif ($this eq 'F') {
	    $rc = "\cF";
	} elsif ($this eq 'G') {
	    $rc = "\cG";
	} elsif ($this eq 'H') {
	    $rc = "\cH";
	} elsif ($this eq 'I') {
	    $rc = "\cI";
	} elsif ($this eq 'J') {
	    $rc = "\cJ";
	} elsif ($this eq 'K') {
	    $rc = "\cK";
	} elsif ($this eq 'L') {
	    $rc = "\cL";
	} elsif ($this eq 'M') {
	    $rc = "\cM";
	} elsif ($this eq 'N') {
	    $rc = "\cN";
	} elsif ($this eq 'O') {
	    $rc = "\cO";
	} elsif ($this eq 'P') {
	    $rc = "\cP";
	} elsif ($this eq 'Q') {
	    $rc = "\cQ";
	} elsif ($this eq 'R') {
	    $rc = "\cR";
	} elsif ($this eq 'S') {
	    $rc = "\cS";
	} elsif ($this eq 'T') {
	    $rc = "\cT";
	} elsif ($this eq 'U') {
	    $rc = "\cU";
	} elsif ($this eq 'V') {
	    $rc = "\cV";
	} elsif ($this eq 'W') {
	    $rc = "\cW";
	} elsif ($this eq 'X') {
	    $rc = "\cX";
	} elsif ($this eq 'Y') {
	    $rc = "\cY";
	} elsif ($this eq 'Z') {
	    $rc = "\cZ";
	} elsif ($this eq '[') {
	    $rc = "\c[";
	} elsif ($this eq '\\') {
	    #
	    # Shall I use \c\X or chr(28) ? Even if it seems an overhead \c\X seems more portable
	    #
 	    $rc = "\c\X";
	    substr($rc, -1, 1, '');
	} elsif ($this eq ']') {
	    $rc = "\c]";
	} elsif ($this eq '^') {
	    $rc = "\c^";
	} elsif ($this eq '_') {
	    $rc = "\c_";
	} elsif ($this eq 'Z') {
	    $rc = TERMINFO_SP;
	} elsif ($this eq '?') {
	    $rc = "\c?";
	} else {
	    carp "Unsupported control character '$c'\n";
	}

    } elsif (substr($c, 0, 1) eq '\\') {
	#
	# Spec says this must be octal digits
	#
	my $oct = $c;
	substr($oct, 0, 1, '');
	$rc = chr(oct($oct) || oct(200));
    } else {
	carp "Unhandled escape sequence $c\n";
    }

    my $ord = ord($rc);
    return "\$rc .= chr($ord); # $c";
}

=head2 addCharacterToRc($self, $c)

Generates code that appends character $c to the output of generated code.

=cut

sub addCharacterToRc {
    my ($self, $c) = @_;

    if ($log->is_trace) {
	$log->tracef('addCharacterToRc(c="%s")', $c);
    }

    my $ord = ord($c);
    return "\$rc .= chr($ord); # $c";
}

=head2 addPercentToRc($self, $c)

Generates code that appends character '%' to the output of generated code.

=cut

sub addPercentToRc {
    my ($self, $c) = @_;

    if ($log->is_trace) {
	$log->tracef('addPercentToRc(c="%s")', $c);
    }

    return "\$rc .= '%';";
}

=head2 addPrintPopToRc($self, $c)

Generates code that appends a print of pop() like %c in printf().

=cut

sub addPrintPopToRc {
    my ($self, $c) = @_;

    if ($log->is_trace) {
	$log->tracef('addPrintPopToRc(c="%s")', $c);
    }

    return "\$rc .= sprintf('%c', pop(\@iparam)); # $c";
}

=head2 addPrintToRc($self, $format)

Generates code that appends a print of pop() using the $format string in the terminfo database.

=cut

sub addPrintToRc {
    my ($self, $format) = @_;

    if ($log->is_trace) {
	$log->tracef('addPrintToRc(format="%s")', $format);
    }

    #
    # print has the following format:
    # %[[:]flags][width[.precision]][doxXs]
    # => we remove the eventual ':' after the '%'
    # the rest is totally functional within perl
    #
    $format =~ s/^%:/%/;

    return "\$rc .= sprintf('$format', pop(\@iparam)); # $format";
}

=head2 addPushToRc($self, $push)

Generates code that appends a push().

=cut

sub addPushToRc {
    my ($self, $push) = @_;
    # %p[1-9]

    if ($log->is_trace) {
	$log->tracef('addpushToRc(push="%s")', $push);
    }

    my $indice = ord(substr($push, -1, 1)) - ord('0') - 1;
    return "push(\@iparam, \$param[$indice]); # $push";
}

=head2 addDynPop($self, $dynpop)

Generates code that appends a pop() into a dynamic variable.

=cut

sub addDynPop {
    my ($self, $dynpop) = @_;
    # %P[a-z]

    if ($log->is_trace) {
	$log->tracef('addDynPop(dynpop="%s")', $dynpop);
    }

    my $indice = ord(substr($dynpop, -1, 1)) - ord('a');
    return "\$dynamicp->[$indice] = pop(\@iparam); # $dynpop";
}

=head2 addDynPush($self, $dynpush)

Generates code that appends a push() of a dynamic variable.

=cut

sub addDynPush {
    my ($self, $dynpush) = @_;
    # %g[a-z]

    if ($log->is_trace) {
	$log->tracef('addDynPush(dynpush="%s")', $dynpush);
    }

    my $indice = ord(substr($dynpush, -1, 1)) - ord('a');
    return "push(\@iparam, \$dynamicp->[$indice]); # $dynpush";
}

=head2 addStaticPop($self, $staticpop)

Generates code that appends a pop() into a static variable.

=cut

sub addStaticPop {
    my ($self, $staticpop) = @_;
    # %P[A-Z]

    if ($log->is_trace) {
	$log->tracef('addStaticPop(staticpop="%s")', $staticpop);
    }

    my $indice = ord(substr($staticpop, -1, 1)) - ord('A');
    return "\$staticp->[$indice] = pop(\@iparam); # $staticpop";
}

=head2 addStaticPush($self, $staticpush)

Generates code that appends a push() of a static variable.

=cut

sub addStaticPush {
    my ($self, $staticpush) = @_;
    # %g[A-Z]

    if ($log->is_trace) {
	$log->tracef('addStaticPush(staticpush="%s")', $staticpush);
    }

    my $indice = ord(substr($staticpush, -1, 1)) - ord('A');
    return "push(\@iparam, \$staticp->[$indice]); # $staticpush";
}

=head2 addL($self, $l)

Generates code that appends a push() of strlen(pop()).

=cut

sub addL {
    my ($self, $l) = @_;
    # %l

    if ($log->is_trace) {
	$log->tracef('addL(l="%s")', $l);
    }

    return "push(\@iparam, strlen(pop(\@iparam)); # $l";
}

=head2 addPushConst($self, $const)

Generates code that appends a push() of char constant $const.

=cut

sub addPushConst {
    my ($self, $const) = @_;
    # %'c'

    if ($log->is_trace) {
	$log->tracef('addPushConst(const="%s")', $const);
    }

    #
    # Either this is an escaped number \ddd, or anything but a quote
    #
    my $c;
    if (length($const) > 1) {
	my $oct = $const;
	substr($oct, 0, 1, '');
	$c = chr(oct($oct) || oct(200));
    } else {
	$c = $const;
    }

    my $ord = ord($c);

    return "push(\@iparam, chr($ord)); # $const";
}

=head2 addPushInt($self, $int)

Generates code that appends a push() of integer constant $const.

=cut

sub addPushInt {
    my ($self, $int) = @_;
    # %{nn}

    if ($log->is_trace) {
	$log->tracef('addPushInt(int="%s")', $int);
    }

    my $value = $int;
    substr($value, 0, 2, '');
    substr($value, -1, 1, '');

    return "push(\@iparam, $value); # $int";
}

=head2 addPlus($self, $plus)

Generates code that appends a push() of pop()+pop()

=cut

sub addPlus {
    my ($self, $plus) = @_;
    # %+

    if ($log->is_trace) {
	$log->tracef('addPlus(plus="%s")', $plus);
    }

    return "push(\@iparam, pop(\@iparam) + pop(\@iparam)); # $plus";
}

=head2 addMinus($self, $minus)

Generates code that appends a push() of second pop() - first pop()

=cut

sub addMinus {
    my ($self, $minus) = @_;
    # %+

    if ($log->is_trace) {
	$log->tracef('addMinus(minus="%s")', $minus);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$x - \$y); } # $minus";
}

=head2 addStar($self, $star)

Generates code that appends a push() of pop() * pop()

=cut

sub addStar {
    my ($self, $star) = @_;
    # %+

    if ($log->is_trace) {
	$log->tracef('addStar(star="%s")', $star);
    }

    return "push(\@iparam, pop(\@iparam) * pop(\@iparam)); # $star";
}

=head2 addDiv($self, $div)

Generates code that appends a push() of second pop() / first pop()

=cut

sub addDiv {
    my ($self, $div) = @_;
    # %+

    if ($log->is_trace) {
	$log->tracef('addDiv(div="%s")', $div);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$y ? int(\$x / \$y) : 0); } # $div";
}

=head2 addMod($self, $mod)

Generates code that appends a push() of second pop() % first pop()

=cut

sub addMod {
    my ($self, $mod) = @_;
    # %+

    if ($log->is_trace) {
	$log->tracef('addMod(mod="%s")', $mod);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$y ? int(\$x % \$y) : 0); } # $mod";
}

=head2 addBitAnd($self, $bitAnd)

Generates code that appends a push() of pop() & pop()

=cut

sub addBitAnd {
    my ($self, $bitAnd) = @_;
    # %&

    if ($log->is_trace) {
	$log->tracef('addBitAnd(bitAnd="%s")', $bitAnd);
    }

    return "push(\@iparam, pop(\@iparam) & pop(\@iparam)); # $bitAnd";
}

=head2 addBitOr($self, $bitOr)

Generates code that appends a push() of pop() | pop()

=cut

sub addBitOr {
    my ($self, $bitOr) = @_;
    # %|

    if ($log->is_trace) {
	$log->tracef('addBitOr(bitOr="%s")', $bitOr);
    }

    return "push(\@iparam, pop(\@iparam) | pop(\@iparam)); # $bitOr";
}

=head2 addBitXor($self, $bitXor)

Generates code that appends a push() of pop() ^ pop()

=cut

sub addBitXor {
    my ($self, $bitXor) = @_;
    # %^

    if ($log->is_trace) {
	$log->tracef('addBitXor(bitXor="%s")', $bitXor);
    }

    return "push(\@iparam, pop(\@iparam) ^ pop(\@iparam)); # $bitXor";
}

=head2 addEqual($self)

Generates code that appends a push() of second pop() == first pop()

=cut

sub addEqual {
    my ($self, $equal) = @_;
    # %=

    if ($log->is_trace) {
	$log->tracef('addEqual(equal="%s")', $equal);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$x == \$y); } # $equal";
}

=head2 addGreater($self)

Generates code that appends a push() of second pop() > first pop()

=cut

sub addGreater {
    my ($self, $greater) = @_;
    # %>

    if ($log->is_trace) {
	$log->tracef('addGreater(greater="%s")', $greater);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$x > \$y); } # $greater";
}

=head2 addLower($self)

Generates code that appends a push() of second pop() < first pop()

=cut

sub addLower {
    my ($self, $lower) = @_;
    # %<

    if ($log->is_trace) {
	$log->tracef('addLower(lower="%s")', $lower);
    }

    return "{ my \$y = pop(\@iparam); my \$x = pop(\@iparam); push(\@iparam, \$x < \$y); } # $lower";
}

=head2 addLogicalAnd($self, $logicalAnd)

Generates code that appends a push() of pop() && pop()

=cut

sub addLogicalAnd {
    my ($self, $logicalAnd) = @_;
    # %A

    if ($log->is_trace) {
	$log->tracef('addLogicalAnd(logicalAnd="%s")', $logicalAnd);
    }

    return "push(\@iparam, pop(\@iparam) && pop(\@iparam)); # $logicalAnd";
}

=head2 addLogicalOr($self, $logicalOr)

Generates code that appends a push() of pop() && pop()

=cut

sub addLogicalOr {
    my ($self, $logicalOr) = @_;
    # %O

    if ($log->is_trace) {
	$log->tracef('addLogicalOr(logicalOr="%s")', $logicalOr);
    }

    return "push(\@iparam, pop(\@iparam) || pop(\@iparam)); # $logicalOr";
}

=head2 addNot($self, $not)

Generates code that appends a push() of pop() && pop()

=cut

sub addNot {
    my ($self, $not) = @_;
    # %!

    if ($log->is_trace) {
	$log->tracef('addNot(not="%s")', $not);
    }

    return "push(\@iparam, ! pop(\@iparam)); # $not";
}

=head2 addComplement($self, $complement)

Generates code that appends a push() of pop() && pop()

=cut

sub addComplement {
    my ($self, $complement) = @_;
    # %!

    if ($log->is_trace) {
	$log->tracef('addComplement(complement="%s")', $complement);
    }

    return "push(\@iparam, ~ pop(\@iparam)); # $complement";
}

=head2 addOneToParams($self, $one)

Generates code that adds 1 to all parameters (in practice not more than two)

=cut

sub addOneToParams {
    my ($self, $one) = @_;
    # %i

    if ($log->is_trace) {
	$log->tracef('addOneToParams(one="%s")', $one);
    }

    return "map {\$param[\$_]++} (0..\$#param); # $one";
}

=head2 addIfThenElse($self, $if, $units1p, $then, $units2p, $elsifUnitsp, $else, $unitsp, $endif)

Generates code that adds generated if {} $elsifUnits else {}.

=cut

sub addIfThenElse {
    my ($self, $if, $units1p, $then, $units2p, $elsifUnitsp, $else, $units3p, $endif) = @_;

    if ($log->is_trace) {
	$log->tracef('addIfThenElse($if="%s", $units1p="%s", $then="%s", $units2p="%s", $elsifUnitsp="%s", $else="%s", $units3p="%s", $endif="%s")', $if, $units1p, $then, $units2p, $elsifUnitsp, $else, $units3p, $endif);
    }

    my $units1     = join("\n", @{$units1p});
    my $units2     = join("\n", @{$units2p});
    my $elsifUnits = join("\n", @{$elsifUnitsp});
    my $units3     = join("\n", @{$units3p});
    #
    # We increase indentation of units
    #
    $units1     =~ s/^/         /smg;
    $units2     =~ s/^/  /smg;
    $units3     =~ s/^/  /smg;
    #
    # $endif can be the EOF
    #
    $endif ||= 'implicit by eof';

    my $rc = "if (do { # $if
$units1
         pop(\@iparam);
       }) { # $then
$units2
}";
    if ($elsifUnits) {
	$rc .= "\n$elsifUnits";
    }
    $rc .= "
else { # $else
$units3
} # $endif";

    return $rc;
}

=head2 addIfThen($self, $if, $units1p, $then, $units2p, $elsifUnits, $endif)

Generates code that adds generated if {} $elsifUnits.

=cut

sub addIfThen {
    my ($self, $if, $units1p, $then, $units2p, $elsifUnitsp, $endif) = @_;

    if ($log->is_trace) {
	$log->tracef('addIfThen($if="%s", $units1p="%s", $then="%s", $units2p="%s", $elsifUnitsp="%s", $endif="%s")', $if, $units1p, $then, $units2p, $elsifUnitsp, $endif);
    }

    my $units1     = join("\n", @{$units1p});
    my $units2     = join("\n", @{$units2p});
    my $elsifUnits = join("\n", @{$elsifUnitsp});
    #
    # We increase indentation of units
    #
    $units1     =~ s/^/         /smg;
    $units2     =~ s/^/  /smg;
    #
    # $endif can be the EOF
    #
    $endif ||= 'implicit by eof';

    my $rc = "if (do { # $if
$units1
         pop(\@iparam);
       }) { # $then
$units2
} # $endif";
    if ($elsifUnits) {
	$rc .= "\n$elsifUnits";
    }

    return $rc;
}

=head2 elifUnit($self, $else, $units1p, $then, $units2p)

Generates code that adds generated elsif {}.

=cut

sub elifUnit {
    my ($self, $else, $units1p, $then, $units2p) = @_;

    if ($log->is_trace) {
	$log->tracef('elifUnit($else="%s", $units1p="%s", $then="%s", $units2p="%s")', $else, $units1p, $then, $units2p);
    }
    my $units1     = join("\n", @{$units1p});
    my $units2     = join("\n", @{$units2p});
    #
    # We increase indentation of units
    #
    $units1     =~ s/^/            /smg;
    $units2     =~ s/^/  /smg;

    my $rc = "elsif (do { # $else
$units1
            pop(\@iparam);
       }) { # $then
$units2
}";

    return $rc;
}

=head2 eof($self, ...)

Routine executed at EOF. It is also preventing undef to be pass through the parse tree value.

=cut

sub eof {
    my ($self, @args) = @_;

    return '';
}

=head2 ifEndif($self, ...)

Routine executed to empty IF/ENDIF. It is also preventing undef to be pass through the parse tree value.

=cut

sub ifEndif {
    my ($self, @args) = @_;

    return '# IF/ENDIF ignored';
}

1;
