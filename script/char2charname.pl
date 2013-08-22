#!env perl
use strict;
use diagnostics;
use charnames qw/:full/;

foreach ( 0 .. 127 ) {
    # next unless chr =~ /\p{Space}/;
    printf qq(d=%2d x=0x%02X o=0%02o --> %s\n), $_, $_, $_, charnames::viacode($_);
}
