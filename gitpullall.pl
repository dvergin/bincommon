#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';
use dv_util;
my $util = dv_util->new();

my $sendemail = defined $ARGV[0] && $ARGV[0] eq '--email' ? 1 : 0;

my $short_report = '';
my $long_report  = '';
my %problem_details = ();
my @okay_boxes = ();
my @offline_boxes = ();

my @boxes = qw/amida chromebook laptop raspi towerplus xps8700/;
for my $box (@boxes) {
   say $box;
   my $online = 0;
   my $git_cmd = 'cd ~/bincommon; git fetch; git pull; git status';
   if ($box eq $ENV{'MACHINE'}) {
      $online = 1;
   } else {
      $git_cmd = "ssh $box " . "'$git_cmd'";
      my $status_check = system("ssh -o BatchMode=yes -o ConnectTimeout=2 -q $box exit");
      if ($status_check == 0) {
         $online = 1;
      } else {
         push(@offline_boxes, $box);
      }
   }
   if ($online) {
      my $git_status_report = `$git_cmd`;
      $long_report .= "-------------------\n$box\n$git_cmd\n$git_status_report\n------------------\n";
      my @rpt_ary = ();
      if ($git_status_report =~ /(Your branch is behind.+)/) {
         push(@rpt_ary, 'branch is behind');
      } else {
         
      }
      if ($git_status_report =~ /Untracked files/) {
         push(@rpt_ary, 'untracked files');
      }
      if ($git_status_report =~ /Changes not staged/) {
         push(@rpt_ary, '/ unstaged changes');
      }
      if ($git_status_report =~ /Changes to be committed/) {
         push(@rpt_ary, '/ changes to be committed');
      }
      if ($git_status_report =~ /Your branch is ahead/) {
         push(@rpt_ary, '/ ahead of main');
      }
      if (@rpt_ary) {
         $problem_details{$box} = \@rpt_ary;
      } else {
         push(@okay_boxes, $box);
      }
   }
}
if (@offline_boxes) {
   for my $off_box (@offline_boxes) {
      $short_report .= "Off-line: $off_box\n";
   }
}
if (@okay_boxes) {
   for my $okay_box (@okay_boxes) {
      $short_report .= "Okay: $okay_box\n";
   }
}
if (%problem_details) {
   for my $box (@boxes) {
      if ( exists $problem_details{$box} ) {
         $short_report .= "ACTION NEEDED - $box: " . join( ' ', @{ $problem_details{$box} } ) . "\n";
      }
   }
}

my $email_report = $short_report;
#$email_report .= $long_report;

if ($sendemail) {
   $util->email(to      => 'David Vergin <dvergin@fastmail.net>',
                from    => 'Git Checker <dvergin@fastmail.net>',
                subject => 'Git Pull Report',
                message => $email_report);
} else {
   say "\n";
   say $email_report;
}

