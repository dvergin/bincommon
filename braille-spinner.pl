#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state, switch

use Data::Dumper;    #print Dumper($var_ref)

$| = 1;

my @onedotspinner = qw|⠈ ⠐ ⠠ ⢀ ⡀ ⠄ ⠂ ⠁|;   # Single Dot Spinner
my @twodotspinner = qw|⠘ ⠰ ⢠ ⣀ ⡄ ⠆ ⠃ ⠉|;   # Two Dot Spinner

for my $j (0 .. 5) {
   for my $i (0 .. 7) {
      print "\r$onedotspinner[$i]    $twodotspinner[$i]    ";
      select undef, undef, undef, 0.2;  # sleep part of a second
   }
}
