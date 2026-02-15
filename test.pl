#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state, switch
use v5.38;

#-------------------------------------------------------------------------
# AVAILABLE FEATURES IN THE v5.38 BUNDLE:
#   signatures, say, state, try/catch/finally, defer, unicode_strings,fc
# EXPERIMENTAL - Requires 'use feature <feature> and 'no warnings <feature>
#   class: including field & method
#   builtin (trim, is_bool, etc.)
#-------------------------------------------------------------------------
# Enable experimental features
use builtin qw(trim)
use feature qw(class builtin);
no warnings qw(experimental::class experimental::builtin);
use Data::Dumper;    #print Dumper($var_ref)


no warnings 'experimental::smartmatch', 'experimental::class';

say 'yes sir!';

class Example {
   field $source :param;
   field $x = 3;
   ADJUST {
      $source_string = MyString->new(string => $source);
   }

   method sayit {
      say $x;
   }
}

my $s = Example->new();

$s->sayit();

