#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state.
use Data::Dumper;    #print Dumper($var_ref)
use feature qw/say class/;
no warnings 'experimental::class';

# See: https://perldoc.perl.org/perlclass

say 'Perl OO Example';

class Example {
   field $x  :param = 0;  # optional param
   field $y  :param;      # required param
   field $zz :param(z);  # required param referred to when called as z and internally as $zz

   method addx($addend) {
      #my $addend = pop;
      $x += $addend;
   }

   method sayx {
      say $x;
   }

   method sayz {
      say $zz;
   }

}

my $s = Example->new(y => 5, z => 3);

$s->sayx();
$s->addx(10);
$s->sayx();
$s->sayz();

