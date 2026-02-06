#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
#use Data::Dumper;    #print Dumper($var_ref)

use lib '/home/dvergin/bincommon/perlmodules';
use dv_openai;
use dv_util;

my $currentmodel = dv_util->new->slurp("/home/dvergin/bincommon/perlmodules/CurrentOpenAIModel.txt");
my $modellist = dv_openai->new->get_model_list();

say "\nCurrent OpenAI Model on this system is: $currentmodel";
say "Available models are:";
say "   $_" for @$modellist;
print "\n";
