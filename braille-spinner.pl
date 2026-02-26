#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state, switch

use Data::Dumper;    #print Dumper($var_ref)

$| = 1;

my @onedotspinner = qw|⠈ ⠐ ⠠ ⢀ ⡀ ⠄ ⠂ ⠁|;   # Single Dot Spinner
my @twodotspinner = qw|⠘ ⠰ ⢠ ⣀ ⡄ ⠆ ⠃ ⠉|;   # Two Dot Spinner
my @twobytwospin  = (' ⠘',' ⠰',' ⢠',' ⣀','⢀⡀','⣀ ','⡄ ','⠆ ','⠃ ','⠉ ','⠈⠁',' ⠉');   # Two char wide two dot spinner

say '';
say "One character wide: 1 dot and two dots:";
for my $j (0 .. 4) {
   for my $i (0 .. 7) {
      print "\r|$onedotspinner[$i]|    |$twodotspinner[$i]|    ";
      select undef, undef, undef, 0.2;  # sleep part of a second
   }
}
say "\n\n";
say "Two characters wide -- easier to see";
for my $j (1 .. 4) {
   for my $i (0 .. 11) {
      print "\r  |$twobytwospin[$i]|    ";
      select undef, undef, undef, 0.2;  # sleep part of a second
   }
}
say "\n";
