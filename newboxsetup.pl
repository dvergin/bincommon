#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';

my ($boxname, $ip) = @ARGV;

if (not $ip) {
   say <<~'EOM';
   Usage:
      newboxsetup.pl boxname ip
   EOM
}

system("ssh $boxname 'sudo apt update; sudo apt upgrade -y'");

my @apt_pkgs = qw/git perl/;
for my $pkg (@apt_pkgs) {
   say "Installing $pkg";
   system("ssh $boxname sudo apt install $pkg");
}
say '';
if (`ssh $boxname ls` =~ /bincommon/) {
   say 'The git repo bincommon is installed';
} else {
   say 'Setting up the git repo bincommon';
   `ssh $boxname git clone git\@github.com:dvergin/bincommon.git`;
}

say "\nDone\n";
