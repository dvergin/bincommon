#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';
use dv_google;

my $ggl = dv_google->new(client_secret_path => "/home/dvergin/.credentials/google_client_secret.json",
                           token_store_path   => "/home/dvergin/.credentials/google_token_store.json",
                           #folder_id          => "1Cryh79nUDRdkIy0_sYbsZwMby8kmtrkq",
                          );

my $filelistaoh = $ggl->gdrive_list_files();
print Dumper($filelistaoh);

my $idlist = $ggl->gdrive_get_ids_by_name('Backups');
print Dumper($idlist);
my $name = $ggl->gdrive_get_name_by_id($idlist->[0]);
print "$name\n";

print "TASKS\n\n";
my $tasklists = $ggl->gtask_get_tasklists();
print Dumper($tasklists);
print "\n";

my $tasks = $ggl->gtask_get_tasks('MTgzOTIxODI2MTQzMDczMzgzMDk6MDow');
print Dumper ($tasks);
