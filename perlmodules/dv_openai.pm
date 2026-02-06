#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Tiny;
use JSON ();

use lib '/home/dvergin/bin';
use dv_util;

#######################################################################
package dv_openai;
#######################################################################

#use ojo;
#use Data::Dumper;

=head1 NAME

   dv_openai

=head1 SYNOPSIS

   use FindBin qw( $RealBin );
   use lib $RealBin;
   use dv_openai;
   my $ai = dv_openai->new();

=head1 DESCRIPTION

   Access to OpenAI

=head1 METHODS

=cut

######################################################################
sub new {
######################################################################

=head2 new()

   my $ai = dv_openai->new();
   my $ai = dv_openai->new({version => 'GPT-3'});  # the current default

=cut

   my $class   = shift;
   my $opts    = shift;
   my $version = $opts->{version} || 'GPT-3';

   my $self = bless { version => $version,
                    }, $class;
   return $self;
}

#######################################################################
sub get_model_list {
#######################################################################
   my $apikey = $ENV{'OPENAI_API_KEY'};
   my $apiurl = 'https://api.openai.com/v1/models';
   my $response = HTTP::Tiny->new->get( $apiurl, { headers => {'Authorization' => "Bearer $apikey" }, });
   my $content = $response->{'content'};
   my @modellist = grep { ! /codex|latest|mini|nano|o$|preview|search|transcribe|turbo|2024|2025/ }
                   grep { /^gpt-[45]|chatgpt/ }
                   $content =~ /"id": "([^"]+)"/g;
   return \@modellist;
}

#######################################################################
sub query {
#######################################################################

=head2 query()

   my $response = $ai->query($prompt_string, [$length]); $default length is 50

=cut

   my $self   = shift;
   my $opts   = shift;
   my $prompt = $opts->{'prompt'};
   my $length = $opts->{'length'} || 50;
   my $apikey = $ENV{'OPENAI_API_KEY'};
   my $model  = dv_util->new->slurp('/home/dvergin/bincommon/perlmodules/CurrentOpenAIModel.txt');
   chomp($model);
   my $apiurl = 'https://api.openai.com/v1/chat/completions';

   my $reqcontentjson = qq|{"model": "$model", |
                      . qq| "max_completion_tokens": $length, |
                      . qq| "messages": [ |
                      . qq|              {"role": "system", "content": "You are a helpful assistant."}, |
                      . qq|              {"role": "user",   "content": "$prompt"} |
                      . qq|             ] |
                      . qq|}|;

   #print $reqcontentjson . "\n";
   my $response = HTTP::Tiny->new->post( $apiurl, { headers => {'Content-Type'  => 'application/json',
                                                                'Authorization' => "Bearer $apikey" },
                                                    content => $reqcontentjson
                                                  }
                                       );
   my $content = $response->{content};
   my $json = JSON->new->decode($content);
   #print $json->{choices}[0]{message}{content};
   my $answer = $json->{choices}[0]{message}{content};
   return $answer;
}

#######################################################################
#######################################################################
1;

