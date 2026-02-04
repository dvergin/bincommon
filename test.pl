#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state, switch
use Data::Dumper;    #print Dumper($var_ref)
use feature qw/say class/;
no warnings 'experimental::smartmatch', 'experimental::class';

say 'yes sir!';

class Example {
   field $x = 3;

   method sayit {
      say $x;
   }
}

my $s = Example->new();

$s->sayit();

