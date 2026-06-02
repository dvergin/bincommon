#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';

my @boxes = qw/raspi xps8700/;

for my $box (@boxes) {
   say "Checking git repo on $box";
   my $response = `ssh $box "cd bincommon; git fetch; git status"`;
   say $response;
   say '--------------------------------------------------------'
}
