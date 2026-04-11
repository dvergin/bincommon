#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';
use dv_google;

my $ggl = dv_google->new(client_secret_path => "/home/dvergin/.credentials/google_client_secret.json",
                           token_store_path   => "/home/dvergin/.credentials/google_token_store.json",
                          );

my $tasks = $ggl->gtask_get_tasks('MTgzOTIxODI2MTQzMDczMzgzMDk6MDow');
#print Dumper ($tasks);

for my $task (@$tasks) {
   say $task->{'title'};
}
