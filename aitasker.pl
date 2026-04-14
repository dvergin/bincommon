#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use FindBin qw($Bin);
use File::Spec;
use JSON::PP qw(encode_json decode_json);
use HTTP::Tiny;

my $api_key = $ENV{OPENAI_API_KEY}
  or die "OPENAI_API_KEY is not set\n";

my $model = $ENV{OPENAI_MODEL} // 'gpt-4.1-mini';

my $tasks_file  = File::Spec->catfile($Bin, 'aitasks.md');
my $output_file = File::Spec->catfile($Bin, 'aitaskresult.JSON');

open my $in, '<:raw', $tasks_file
  or die "Cannot open $tasks_file: $!\n";
local $/;
my $tasks = <$in>;
close $in;

defined $tasks && length $tasks
  or die "$tasks_file is empty\n";

my $payload = {
  model => $model,
  response_format => { type => 'json_object' },
  messages => [
    {
      role    => 'system',
      content => 'Return only a single valid JSON object. Do not include markdown fences or any text outside the JSON.'
    },
    {
      role    => 'user',
      content => $tasks
    },
  ],
};

my $http = HTTP::Tiny->new(
  agent      => "tasks-cron/1.0",
  timeout    => 120,
  verify_SSL => 1,
  default_headers => {
    'Authorization' => "Bearer $api_key",
    'Content-Type'  => 'application/json',
  },
);

my $res = $http->post(
  'https://api.openai.com/v1/chat/completions',
  { content => encode_json($payload) }
);

$res->{success}
  or die "OpenAI API request failed: $res->{status} $res->{reason}\n$res->{content}\n";

my $decoded = eval { decode_json($res->{content}) };
die "Failed to decode API response JSON: $@\n" if $@;

my $json_text = $decoded->{choices}[0]{message}{content};
defined $json_text && length $json_text
  or die "API returned no message content\n";

eval { decode_json($json_text) };
die "Model output is not valid JSON: $@\n" if $@;

open my $out, '>:raw', $output_file
  or die "Cannot open $output_file for writing: $!\n";
print {$out} $json_text;
close $out or die "Cannot close $output_file: $!\n";

