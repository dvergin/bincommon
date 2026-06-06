#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';
use dv_util;
my $util = dv_util->new();

my $sendemail = defined $ARGV[0] && $ARGV[0] eq '--email' ? 1 : 0;

my $report = '';
my @boxes = qw/amida chromebook laptop raspi towerplus xps8700/;

for my $box (@boxes) {
   $report .= "Checking git repo on $box\n";
   my $resp = $box eq $ENV{'MACHINE'}
            ? `cd ~/bincommon; git fetch; git status`
            : `ssh $box "cd ~/bincommon; git fetch; git status"`;
   $report .= "- - - -\n$resp- - - -\n";
   if ($resp =~ /(Your branch is behind.+)/) {
      my $alert = $1;
      $alert =~ s/Your branch/$box/;
      $report .= "$alert\n";
   } else {
      $report .= "$box git is up to date\n";
   }
   if ($resp =~ /Changes not staged/) {
      $report .= "$box has unstaged changes\n";
   }
   $report .= "--------------------------------------------------------\n";
}

if ($sendemail) {
   $util->email(to      => 'David Vergin <dvergin@fastmail.net>',
                from    => 'Git Checker <dvergin@fastmail.net>',
                subject => 'Git Status Report',
                message => $report);
} else {
   say $report;
}

