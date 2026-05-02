#!/usr/bin/env perl
use v5.38;
use strict;
use warnings;

use HTTP::Tiny ();
use JSON::PP qw(decode_json);
use Test2::V0;

use lib '/home/dvergin/bincommon/perlmodules';
use dv_ai;

my $OPENAI_KEY    = $ENV{OPENAI_API_KEY};
my $ANTHROPIC_KEY = $ENV{ANTHROPIC_API_KEY};

my $obj = dv_ai->new;

sub extract_text_openai ($res) {
    return undef unless ref($res) eq 'HASH';
    return $res->{output_text} if defined $res->{output_text};
    return undef unless ref($res->{output}) eq 'ARRAY';

    my @texts;
    for my $item (@{$res->{output}}) {
        next unless ref($item) eq 'HASH';

        if (($item->{type} // '') eq 'message' && ref($item->{content}) eq 'ARRAY') {
            for my $part (@{$item->{content}}) {
                next unless ref($part) eq 'HASH';
                next unless ($part->{type} // '') eq 'output_text';
                push @texts, ($part->{text} // '');
            }
            next;
        }

        if (($item->{type} // '') eq 'output_text') {
            push @texts, ($item->{text} // '');
        }
    }

    return @texts ? join('', @texts) : undef;
}

sub extract_tool_call_openai ($res) {
    return undef unless ref($res) eq 'HASH';
    return undef unless ref($res->{output}) eq 'ARRAY';

    for my $item (@{$res->{output}}) {
        next unless ref($item) eq 'HASH';

        if (($item->{type} // '') eq 'function_call') {
            return {
                call_id   => $item->{call_id},
                name      => $item->{name},
                arguments => $item->{arguments},
            };
        }

        if (($item->{type} // '') eq 'message' && ref($item->{content}) eq 'ARRAY') {
            for my $part (@{$item->{content}}) {
                next unless ref($part) eq 'HASH';
                next unless ($part->{type} // '') eq 'function_call';
                return {
                    call_id   => $part->{call_id},
                    name      => $part->{name},
                    arguments => $part->{arguments},
                };
            }
        }
    }

    return undef;
}

sub extract_text_anthropic ($res) {
    return undef unless ref($res) eq 'HASH';
    return undef unless ref($res->{content}) eq 'ARRAY';

    my @texts;
    for my $part (@{$res->{content}}) {
        next unless ref($part) eq 'HASH';
        next unless ($part->{type} // '') eq 'text';
        push @texts, ($part->{text} // '');
    }
    return @texts ? join('', @texts) : undef;
}

sub extract_tool_use_anthropic ($res) {
    return undef unless ref($res) eq 'HASH';
    return undef unless ref($res->{content}) eq 'ARRAY';

    for my $part (@{$res->{content}}) {
        next unless ref($part) eq 'HASH';
        next unless ($part->{type} // '') eq 'tool_use';
        return {
            id    => $part->{id},
            name  => $part->{name},
            input => $part->{input},
        };
    }
    return undef;
}

sub try_live ($code) {
    my ($ok, $res, $err);
    $ok = eval {
        $res = $code->();
        1;
    };
    $err = $@ unless $ok;
    return ($ok, $res, $err);
}

sub is_quota_error ($err) {
    return defined($err) && $err =~ /insufficient_quota|quota/i;
}

sub is_output_format_unsupported ($err) {
    return defined($err) && $err =~ /does not support output format|output format/i;
}

sub get_json ($url, $headers = {}) {
    my $http = HTTP::Tiny->new(
        timeout         => 30,
        verify_SSL      => 1,
        default_headers => $headers,
    );

    my $res = $http->get($url);
    return undef unless $res->{success};
    return eval { decode_json($res->{content}) };
}

sub get_openai_model () {
    return undef unless $OPENAI_KEY;

    my $json = get_json(
        'https://api.openai.com/v1/models',
        { authorization => "Bearer $OPENAI_KEY" },
    );
    return undef unless $json && ref($json->{data}) eq 'ARRAY';

    my @ids = map { $_->{id} } grep { ref($_) eq 'HASH' && defined $_->{id} } @{$json->{data}};

    for my $preferred (qw(gpt-4.1-mini gpt-4.1 gpt-4o-mini gpt-4o)) {
        return $preferred if grep { $_ eq $preferred } @ids;
    }
    for my $id (@ids) {
        return $id if $id =~ /^gpt-/;
    }
    return undef;
}

sub get_anthropic_models () {
    return () unless $ANTHROPIC_KEY;

    my $json = get_json(
        'https://api.anthropic.com/v1/models',
        {
            'x-api-key'         => $ANTHROPIC_KEY,
            'anthropic-version' => '2023-06-01',
        },
    );
    return () unless $json && ref($json->{data}) eq 'ARRAY';

    return map { $_->{id} } grep { ref($_) eq 'HASH' && defined $_->{id} } @{$json->{data}};
}

sub pick_anthropic_model ($need_output_format = 0) {
    my @ids = get_anthropic_models();
    return undef unless @ids;
    my %have = map { $_ => 1 } @ids;

    my @feature_capable = qw(
        claude-3-7-sonnet-latest
        claude-3-5-sonnet-latest
        claude-sonnet-4-0
        claude-sonnet-4-5
        claude-opus-4-0
        claude-opus-4-1
    );

    my @general = (
        @feature_capable,
        qw(
            claude-3-5-haiku-latest
            claude-3-haiku-20240307
        )
    );

    my @prefs = $need_output_format ? @feature_capable : @general;

    for my $preferred (@prefs) {
        return $preferred if $have{$preferred};
    }

    if ($need_output_format) {
        for my $id (@ids) {
            next if $id =~ /haiku-20240307/;
            return $id if $id =~ /sonnet|opus|3-5|3-7|4/;
        }
    }

    return $ids[0];
}

subtest 'configuration' => sub {
    ok($OPENAI_KEY || $ANTHROPIC_KEY, 'at least one API key is present');
    ok(!(!$OPENAI_KEY && !$ANTHROPIC_KEY), 'live tests can run');
};

if ($OPENAI_KEY) {
    my $model = get_openai_model() // die "No usable OpenAI model found\n";

    my ($probe_ok, $probe_res, $probe_err) = try_live(sub {
        $obj->llm_response({
            provider          => 'openai',
            model             => $model,
            input             => 'Reply with exactly the word alpha.',
            max_output_tokens => 16,
        });
    });

    die "OpenAI quota exhausted: $probe_err\n" if !$probe_ok && is_quota_error($probe_err);
    die "OpenAI probe failure: $probe_err\n" unless $probe_ok;

    subtest "OpenAI live full ($model)" => sub {
        ok(ref($probe_res) eq 'HASH', 'basic response is hash');
        ok(defined $probe_res->{id}, 'basic response has id');
        ok(defined $probe_res->{model}, 'basic response has model');
        like(extract_text_openai($probe_res) // '', qr/alpha/i, 'basic text ok');

        my ($json_ok, $json_res, $json_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'openai',
                model             => $model,
                input             => 'Return exactly {"answer":"bravo"} as JSON.',
                max_output_tokens => 64,
                temperature       => 0,
                text              => {
                    format => {
                        type   => 'json_schema',
                        name   => 'answer_schema',
                        schema => {
                            type                 => 'object',
                            additionalProperties => JSON::PP::false,
                            properties           => {
                                answer => { type => 'string' },
                            },
                            required => ['answer'],
                        },
                    },
                },
            });
        });

        die "OpenAI quota exhausted: $json_err\n" if !$json_ok && is_quota_error($json_err);
        ok($json_ok, 'structured output request');
        like(extract_text_openai($json_res) // '', qr/bravo/i, 'structured output text ok');

        my ($instr_ok, $instr_res, $instr_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'openai',
                model             => $model,
                instructions      => 'Answer with exactly the single word delta.',
                input             => 'What is your answer?',
                max_output_tokens => 16,
            });
        });

        die "OpenAI quota exhausted: $instr_err\n" if !$instr_ok && is_quota_error($instr_err);
        ok($instr_ok, 'instructions request');
        like(extract_text_openai($instr_res) // '', qr/delta/i, 'instructions affected output');

        my ($tool1_ok, $tool1_res, $tool1_err) = try_live(sub {
            $obj->llm_response({
                provider            => 'openai',
                model               => $model,
                input               => 'Call lookup_weather with city Kyoto. Do not answer before the tool result.',
                max_output_tokens   => 128,
                parallel_tool_calls => JSON::PP::false,
                tool_choice         => 'required',
                tools               => [
                    {
                        type        => 'function',
                        name        => 'lookup_weather',
                        description => 'Return weather for a city',
                        parameters  => {
                            type                 => 'object',
                            additionalProperties => JSON::PP::false,
                            properties           => {
                                city => { type => 'string' },
                            },
                            required => ['city'],
                        },
                    },
                ],
            });
        });

        die "OpenAI quota exhausted: $tool1_err\n" if !$tool1_ok && is_quota_error($tool1_err);
        ok($tool1_ok, 'tool call request');
        my $tool_call = $tool1_ok ? extract_tool_call_openai($tool1_res) : undef;
        ok($tool_call, 'tool call found');
        ok($tool_call && defined $tool_call->{call_id}, 'tool call has call_id');
        is($tool_call ? $tool_call->{name} : undef, 'lookup_weather', 'tool name matches');

        subtest 'tool follow-up' => sub {
            plan skip_all => 'tool call not found; likely provider response-shape change'
                unless $tool_call && defined $tool_call->{call_id};

            my ($tool2_ok, $tool2_res, $tool2_err) = try_live(sub {
                $obj->llm_response({
                    provider             => 'openai',
                    model                => $model,
                    previous_response_id => $tool1_res->{id},
                    input                => [
                        {
                            type    => 'function_call_output',
                            call_id => $tool_call->{call_id},
                            output  => { city => 'Kyoto', weather => 'sunny' },
                        },
                    ],
                    max_output_tokens    => 64,
                });
            });

            die "OpenAI quota exhausted: $tool2_err\n" if !$tool2_ok && is_quota_error($tool2_err);
            ok($tool2_ok, 'tool follow-up request');
            like(extract_text_openai($tool2_res) // '', qr/kyoto|sunny/i, 'tool follow-up text ok');
        };

        my ($stream_ok, $stream_res, $stream_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'openai',
                model             => $model,
                input             => 'Reply with exactly the word stream.',
                max_output_tokens => 16,
                stream            => JSON::PP::true,
            });
        });

        die "OpenAI quota exhausted: $stream_err\n" if !$stream_ok && is_quota_error($stream_err);
        ok($stream_ok, 'streaming request');
        ok(!ref($stream_res), 'stream response is raw text');
        ok(defined($stream_res) && length($stream_res) > 0, 'stream response is non-empty');
    };
}

if ($ANTHROPIC_KEY) {
    my $basic_model = pick_anthropic_model(0) // die "No usable Anthropic model found\n";
    my $full_model  = pick_anthropic_model(1) // $basic_model;

    my ($probe_ok, $probe_res, $probe_err) = try_live(sub {
        $obj->llm_response({
            provider          => 'anthropic',
            model             => $basic_model,
            input             => 'Reply with exactly the word beta.',
            max_output_tokens => 16,
        });
    });

    die "Anthropic quota exhausted: $probe_err\n" if !$probe_ok && is_quota_error($probe_err);
    die "Anthropic probe failure: $probe_err\n" unless $probe_ok;

    subtest "Anthropic live full ($basic_model)" => sub {
        ok(ref($probe_res) eq 'HASH', 'basic response is hash');
        like(extract_text_anthropic($probe_res) // '', qr/beta/i, 'basic text ok');

        my ($instr_ok, $instr_res, $instr_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'anthropic',
                model             => $basic_model,
                instructions      => 'Answer with exactly the single word gamma.',
                input             => 'What is your answer?',
                max_output_tokens => 16,
            });
        });

        die "Anthropic quota exhausted: $instr_err\n" if !$instr_ok && is_quota_error($instr_err);
        ok($instr_ok, 'instructions request');
        like(extract_text_anthropic($instr_res) // '', qr/gamma/i, 'instructions affected output');

        my ($tool1_ok, $tool1_res, $tool1_err) = try_live(sub {
            $obj->llm_response({
                provider            => 'anthropic',
                model               => $basic_model,
                input               => 'Call lookup_weather with city Kyoto. Do not answer before the tool result.',
                max_output_tokens   => 128,
                parallel_tool_calls => JSON::PP::false,
                tool_choice         => 'required',
                tools               => [
                    {
                        type        => 'function',
                        name        => 'lookup_weather',
                        description => 'Return weather for a city',
                        parameters  => {
                            type                 => 'object',
                            additionalProperties => JSON::PP::false,
                            properties           => {
                                city => { type => 'string' },
                            },
                            required => ['city'],
                        },
                    },
                ],
            });
        });

        die "Anthropic quota exhausted: $tool1_err\n" if !$tool1_ok && is_quota_error($tool1_err);
        ok($tool1_ok, 'tool call request');
        my $tool_use = $tool1_ok ? extract_tool_use_anthropic($tool1_res) : undef;
        ok($tool_use, 'tool use found');
        ok($tool_use && defined $tool_use->{id}, 'tool use has id');
        is($tool_use ? $tool_use->{name} : undef, 'lookup_weather', 'tool name matches');

        subtest 'tool follow-up' => sub {
            plan skip_all => 'tool use not found'
                unless $tool_use && defined $tool_use->{id};

            my ($tool2_ok, $tool2_res, $tool2_err) = try_live(sub {
                $obj->llm_response({
                    provider          => 'anthropic',
                    model             => $basic_model,
                    input             => [
                        {
                            type    => 'message',
                            role    => 'user',
                            content => [
                                {
                                    type => 'input_text',
                                    text => 'Call lookup_weather with city Kyoto. Do not answer before the tool result.',
                                },
                            ],
                        },
                        {
                            type    => 'message',
                            role    => 'assistant',
                            content => [
                                {
                                    type      => 'function_call',
                                    call_id   => $tool_use->{id},
                                    name      => $tool_use->{name},
                                    arguments => '{"city":"Kyoto"}',
                                },
                            ],
                        },
                        {
                            type    => 'function_call_output',
                            call_id => $tool_use->{id},
                            output  => { city => 'Kyoto', weather => 'sunny' },
                        },
                    ],
                    max_output_tokens => 64,
                });
            });

            die "Anthropic quota exhausted: $tool2_err\n" if !$tool2_ok && is_quota_error($tool2_err);
            ok($tool2_ok, 'tool follow-up request');
            like(extract_text_anthropic($tool2_res) // '', qr/kyoto|sunny/i, 'tool follow-up text ok');
        };

        my ($stream_ok, $stream_res, $stream_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'anthropic',
                model             => $basic_model,
                input             => 'Reply with exactly the word stream.',
                max_output_tokens => 16,
                stream            => JSON::PP::true,
            });
        });

        die "Anthropic quota exhausted: $stream_err\n" if !$stream_ok && is_quota_error($stream_err);
        ok($stream_ok, 'streaming request');
        ok(!ref($stream_res), 'stream response is raw text');
        ok(defined($stream_res) && length($stream_res) > 0, 'stream response is non-empty');

        like(
            dies {
                $obj->llm_response({
                    provider          => 'anthropic',
                    model             => $basic_model,
                    input             => 'Hello',
                    max_output_tokens => 16,
                    background        => JSON::PP::true,
                });
            },
            qr/Parameter 'background' is not supported/,
            'unsupported parameter rejected before API call',
        );

        my ($meta_ok, $meta_res, $meta_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'anthropic',
                model             => $basic_model,
                input             => 'Reply with exactly the word epsilon.',
                max_output_tokens => 16,
                metadata          => { user_id => 'dv-ai-live-test' },
                safety_identifier => 'dv-ai-live-test',
            });
        });

        die "Anthropic quota exhausted: $meta_err\n" if !$meta_ok && is_quota_error($meta_err);
        ok($meta_ok, 'metadata and safety_identifier request');
        like(extract_text_anthropic($meta_res) // '', qr/epsilon/i, 'metadata request text ok');

        like(
            dies {
                $obj->llm_response({
                    provider          => 'anthropic',
                    model             => $basic_model,
                    input             => 'Hello',
                    max_output_tokens => 16,
                    metadata          => { user_id => 'one' },
                    safety_identifier => 'two',
                });
            },
            qr/conflict/i,
            'metadata and safety_identifier conflict rejected',
        );

        my ($stop_ok, $stop_res, $stop_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'anthropic',
                model             => $basic_model,
                input             => 'Reply with exactly zeta STOP then more text.',
                max_output_tokens => 32,
                text              => {
                    stop => ['STOP'],
                },
            });
        });

        subtest 'text.stop' => sub {
            if (!$stop_ok) {
                diag("Anthropic text.stop error: $stop_err");
                fail('text.stop request');
            } else {
                pass('text.stop request');
                ok(index((extract_text_anthropic($stop_res) // ''), 'STOP') == -1, 'stop sequence not present in visible output');
            }
        };
    };

    subtest "Anthropic structured output candidate ($full_model)" => sub {
        my ($json_ok, $json_res, $json_err) = try_live(sub {
            $obj->llm_response({
                provider          => 'anthropic',
                model             => $full_model,
                input             => 'Return exactly {"answer":"charlie"} as JSON.',
                max_output_tokens => 64,
                temperature       => 0,
                text              => {
                    format => {
                        type   => 'json_schema',
                        schema => {
                            type                 => 'object',
                            additionalProperties => JSON::PP::false,
                            properties           => {
                                answer => { type => 'string' },
                            },
                            required => ['answer'],
                        },
                    },
                },
            });
        });

        die "Anthropic quota exhausted: $json_err\n" if !$json_ok && is_quota_error($json_err);

        if (!$json_ok) {
            diag("Anthropic structured-output API error: $json_err");
            if (is_output_format_unsupported($json_err)) {
                fail("selected full-feature candidate $full_model does not support output format");
            } else {
                fail('structured output request');
            }
        } else {
            pass('structured output request');
            like(extract_text_anthropic($json_res) // '', qr/charlie/i, 'structured output text ok');
        }
    };
}

done_testing;
