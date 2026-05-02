#!/usr/bin/env perl
use v5.38;
use strict;
use warnings;

#use FindBin qw($Bin);
#use lib $Bin =~ s{/t$}{}r;
use lib '/home/dvergin/bincommon/perlmodules';
use dv_ai;

my $ai = dv_ai->new;

my $res = $ai->llm_response({
    provider          => 'openai',   # or 'anthropic'
    model             => 'gpt-4.1-mini',
    input             => 'Reply with exactly: hello world',
    max_output_tokens => 20,
});

if (ref($res) eq 'HASH') {
    if (defined $res->{output_text}) {
        print $res->{output_text}, "\n";
    }
    else {
        for my $item (@{$res->{output} // []}) {
            next unless ref($item) eq 'HASH';
            next unless ($item->{type} // '') eq 'message';
            for my $part (@{$item->{content} // []}) {
                next unless ref($part) eq 'HASH';
                next unless ($part->{type} // '') eq 'output_text';
                print $part->{text}, "\n";
            }
        }
    }
}
else {
    print $res, "\n";  # streaming case
}

