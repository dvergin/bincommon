#!/usr/bin/env perl

use strict;
use warnings;
use ExtUtils::Installed;

my $inst = ExtUtils::Installed->new();

for my $dist ($inst->modules) {
    my $where = "???";

    eval {
        my @files = $inst->files($dist);
        if (@files) {
            my ($f) = sort @files;
            $f =~ s{/auto/.*}{};
            $f =~ s{/[^/]+$}{};
            $where = $f;
        }
        1;
    };

    print "$where -- $dist\n";
}

print "\n";
print "\@INC contains:\n";
print "$_\n" for @INC;

