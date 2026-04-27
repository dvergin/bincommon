#!/usr/bin/env perl
use strict;
use warnings;
use v5.38;

use JSON::PP qw(decode_json encode_json);
use URI::Escape qw(uri_escape);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

my $client_secret_path = "/home/dvergin/.credentials/google_client_secret.json";
my $token_store_path   = "/home/dvergin/.credentials/google_token_store.json";

open my $fh, '<', $client_secret_path or die "Cannot open $client_secret_path: $!";
local $/;
my $json = <$fh>;
close $fh;

my $cfg = decode_json($json)->{installed}
  or die "No 'installed' section in $client_secret_path\n";

my $client_id     = $cfg->{client_id};
my $client_secret = $cfg->{client_secret};
my $redirect_uri  = $cfg->{redirect_uris}[0];
my $auth_uri      = $cfg->{auth_uri};
my $token_uri     = $cfg->{token_uri};

my $scope = join ' ',
  'https://www.googleapis.com/auth/drive',
  'https://www.googleapis.com/auth/tasks';

my $auth_url =
    $auth_uri
  . '?response_type=code'
  . '&client_id='     . uri_escape($client_id)
  . '&redirect_uri='  . uri_escape($redirect_uri)
  . '&scope='         . uri_escape($scope)
  . '&access_type='   . uri_escape('offline')
  . '&prompt='        . uri_escape('consent');

say "";
say "Open this URL in your browser:";
say "";
say $auth_url;
say "";
say "After Google redirects to http://localhost/?code=..., copy the code value and paste it here.";
say "";

#print "Code: ";
#chomp(my $code = <STDIN> // '');
#die "No code entered\n" unless length $code;

$| = 1;

print "Code: ";
my $raw = <STDIN>;
die "No input received\n" unless defined $raw;

chomp($raw);
my $code = $raw;

say "Read code, length = " . length($code);
die "No code entered\n" unless length $code;

my $ua = LWP::UserAgent->new(
  timeout => 20,
);

say "Exchanging code for tokens...";

my $res = $ua->request(
  POST $token_uri,
    [
      code          => $code,
      client_id     => $client_id,
      client_secret => $client_secret,
      redirect_uri  => $redirect_uri,
      grant_type    => 'authorization_code',
    ]
);

die "Token exchange failed:\n" . $res->decoded_content . "\n"
  unless $res->is_success;

my $tok = decode_json($res->decoded_content);

open my $out, '>', $token_store_path or die "Cannot write $token_store_path: $!";
print $out encode_json($tok);
close $out;

say "";
say "Wrote new token store to $token_store_path";
say "Refresh token present: " . (exists $tok->{refresh_token} ? "yes" : "no");

