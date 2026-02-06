#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;   # enables: say, signatures, state, switch
use Data::Dumper;    #print Dumper($var_ref)
use feature qw/say class/;
no warnings 'experimental::smartmatch', 'experimental::class';

use OpenAPI::Client::OpenAI;
# The OPENAI_API_KEY environment variable must be set
# See https://platform.openai.com/api-keys and ENVIRONMENT VARIABLES below

say "\nAsking about the capital of France...\n";
my $client = OpenAPI::Client::OpenAI->new();

my $tx = $client->createCompletion(
   {
       body => {
           model       => 'gpt-3.5-turbo-instruct',
           prompt      => 'What is the capital of France?',
           temperature => 0, # optional, between 0 and 1, with 0 being the least random
           max_tokens  => 100, # optional, the maximum number of tokens to generate
       }
   }
);
my $response_data = $tx->res->json;
print Dumper($response_data);
