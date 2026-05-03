package dv_ai;

use v5.38;
use feature 'class';
no warnings 'experimental::class';

use HTTP::Tiny ();
use JSON::PP qw(encode_json decode_json);

sub _required ($hash, $key) {
    die "Missing required parameter '$key'\n" unless exists $hash->{$key};
    return $hash->{$key};
}

sub _openai_normalize_input_for_responses ($input) {
    return $input if !ref($input);
    die "Parameter 'input' must be a string or arrayref\n" unless ref($input) eq 'ARRAY';

    my @out;
    for my $item (@$input) {
        die "Each input item must be a hashref\n" unless ref($item) eq 'HASH';

        if (($item->{type} // '') eq 'function_call_output') {
            my %copy = %$item;
            if (exists $copy{output} && ref($copy{output})) {
                $copy{output} = encode_json($copy{output});
            }
            push @out, \%copy;
            next;
        }

        push @out, $item;
    }

    return \@out;
}

sub _openai_responses_payload ($args) {
    my %payload;

    for my $k (keys %{$args}) {
        next if $k eq 'provider' || $k eq 'api_key' || $k eq 'base_url' || $k eq 'timeout';
        $payload{$k} = $args->{$k};
    }

    _required(\%payload, 'model');
    die "Missing required parameter 'input'\n" unless exists $payload{input};

    $payload{input} = _openai_normalize_input_for_responses($payload{input});

    return \%payload;
}

sub _anthropic_max_tokens_from_responses ($args) {
    my $v = $args->{max_output_tokens};
    die "Parameter 'max_output_tokens' is required when using Anthropic\n" unless defined $v;
    return $v;
}

sub _normalize_anthropic_metadata ($metadata, $safety_identifier) {
    my %out;

    if (defined $metadata) {
        die "Parameter 'metadata' must be a hashref when using Anthropic\n"
            unless ref($metadata) eq 'HASH';
        for my $k (keys %{$metadata}) {
            die "Parameter 'metadata.$k' is not supported by Anthropic's native Messages API\n"
                unless $k eq 'user_id';
        }
        %out = %{$metadata};
    }

    if (defined $safety_identifier) {
        if (exists $out{user_id} && defined $out{user_id} && $out{user_id} ne $safety_identifier) {
            die "Parameters 'metadata.user_id' and 'safety_identifier' conflict for Anthropic conversion\n";
        }
        $out{user_id} = $safety_identifier;
    }

    return \%out;
}

sub _normalize_openai_text_to_anthropic_output_config ($text) {
    die "Parameter 'text' must be a hashref\n" unless ref($text) eq 'HASH';

    for my $k (keys %{$text}) {
        die "Parameter 'text.$k' is not supported by this Anthropic converter\n"
            unless $k eq 'format' || $k eq 'stop';
    }

    return undef unless exists $text->{format};

    my $fmt = $text->{format};
    die "Parameter 'text.format' must be a hashref\n" unless ref($fmt) eq 'HASH';

    my $type = $fmt->{type} // die "Parameter 'text.format.type' is required\n";

    if ($type eq 'text') {
        return undef;
    }

    if ($type eq 'json_schema') {
        my $schema = $fmt->{schema} // die "Parameter 'text.format.schema' is required for json_schema\n";
        die "Parameter 'text.format.schema' must be a hashref\n" unless ref($schema) eq 'HASH';
        return {
            format => {
                type   => 'json_schema',
                schema => $schema,
            }
        };
    }

    die "Parameter 'text.format.type' value '$type' is not supported by Anthropic's native Messages API\n";
}

sub _openai_text_stop_to_anthropic ($text) {
    return undef unless defined $text;
    die "Parameter 'text' must be a hashref\n" unless ref($text) eq 'HASH';
    return undef unless exists $text->{stop};

    my $stop = $text->{stop};
    return [$stop] if defined($stop) && !ref($stop);
    die "Parameter 'text.stop' must be a string or arrayref\n" unless ref($stop) eq 'ARRAY';
    return $stop;
}

sub _normalize_openai_responses_tools_for_anthropic ($tools) {
    return undef unless defined $tools;

    die "Parameter 'tools' must be an arrayref\n" unless ref($tools) eq 'ARRAY';

    my @out;

    for my $tool (@$tools) {
        die "Each 'tools' item must be a hashref\n" unless ref($tool) eq 'HASH';
        my $type = $tool->{type} // die "Each tool requires a 'type'\n";

        if ($type eq 'function') {
            my $name = $tool->{name} // die "Function tool requires 'name'\n";
            my $schema = $tool->{parameters} // {};
            die "Function tool 'parameters' must be a hashref\n" if ref($schema) && ref($schema) ne 'HASH';
            push @out, {
                name         => $name,
                description  => $tool->{description},
                input_schema => $schema,
            };
            next;
        }

        die "OpenAI Responses tool type '$type' is not supported by Anthropic's native Messages API\n";
    }

    return \@out;
}

sub _normalize_openai_responses_tool_choice_for_anthropic ($tool_choice, $tools, $parallel_tool_calls) {
    my $choice;

    if (defined $tool_choice) {
        if (!ref($tool_choice)) {
            return { type => 'auto' } if $tool_choice eq 'auto';
            return { type => 'any'  } if $tool_choice eq 'required';
            return { type => 'none' } if $tool_choice eq 'none';
            die "Unsupported scalar tool_choice '$tool_choice' for Anthropic conversion\n";
        }

        die "Parameter 'tool_choice' must be a hashref or scalar\n" unless ref($tool_choice) eq 'HASH';

        my $type = $tool_choice->{type} // die "Structured 'tool_choice' requires 'type'\n";

        if ($type eq 'auto') {
            $choice = { type => 'auto' };
        }
        elsif ($type eq 'required') {
            $choice = { type => 'any' };
        }
        elsif ($type eq 'none') {
            $choice = { type => 'none' };
        }
        elsif ($type eq 'function') {
            my $name = $tool_choice->{name}
                // ($tool_choice->{function} && $tool_choice->{function}{name})
                // die "Structured function tool_choice requires function name\n";
            $choice = {
                type => 'tool',
                name => $name,
            };
        }
        else {
            die "Structured tool_choice type '$type' is not supported for Anthropic conversion\n";
        }
    }

    if (defined $parallel_tool_calls && !$parallel_tool_calls) {
        if ($choice) {
            if ($choice->{type} eq 'auto' || $choice->{type} eq 'any' || $choice->{type} eq 'tool') {
                $choice->{disable_parallel_tool_use} = JSON::PP::true;
            }
        }
        elsif ($tools && @$tools) {
            $choice = {
                type => 'auto',
                disable_parallel_tool_use => JSON::PP::true,
            };
        }
    }

    return $choice;
}

sub _json_string_to_hashref ($s) {
    return {} if !defined($s) || $s eq '';
    return $s if ref($s) eq 'HASH';
    my $decoded = eval { decode_json($s) };
    die "Invalid JSON in function/tool arguments: $@\n" if $@ || ref($decoded) ne 'HASH';
    return $decoded;
}

sub _blocks_or_string ($blocks) {
    return '' unless $blocks && @$blocks;
    return $blocks->[0]{text} if @$blocks == 1 && ($blocks->[0]{type} // '') eq 'text';
    return $blocks;
}

sub _tool_result_content_from_responses ($content) {
    return '' if !defined $content;

    if (!ref($content)) {
        return $content;
    }

    if (ref($content) eq 'HASH') {
        return encode_json($content);
    }

    if (ref($content) eq 'ARRAY') {
        my @parts;
        for my $p (@$content) {
            die "Tool result content part must be a hashref\n" unless ref($p) eq 'HASH';
            my $type = $p->{type} // '';
            if ($type eq 'output_text' || $type eq 'text') {
                push @parts, { type => 'text', text => ($p->{text} // '') };
                next;
            }
            die "Unsupported tool result content part type '$type' for Anthropic conversion\n";
        }
        return \@parts;
    }

    die "Unsupported tool result content type for Anthropic conversion\n";
}

sub _openai_input_image_part_to_anthropic_block ($part) {
    if (exists $part->{image_url}) {
        my $url = $part->{image_url};
        if (ref($url) eq 'HASH') {
            $url = $url->{url};
        }
        die "input_image.image_url is required\n" unless defined $url && length $url;
        return {
            type   => 'image',
            source => {
                type => 'url',
                url  => $url,
            },
        };
    }

    if (exists $part->{file_id}) {
        die "Content part type 'input_image' using 'file_id' is not supported by Anthropic conversion\n";
    }

    die "input_image part must contain 'image_url'\n";
}

sub _responses_content_to_anthropic_blocks ($content, $role) {
    return [] if !defined $content;

    if (!ref($content)) {
        return [ { type => 'text', text => $content } ];
    }

    die "Message content must be a scalar or arrayref\n" unless ref($content) eq 'ARRAY';

    my @blocks;

    for my $part (@$content) {
        die "Content part must be a hashref\n" unless ref($part) eq 'HASH';
        my $type = $part->{type} // die "Content part missing type\n";

        if ($type eq 'input_text' || $type eq 'output_text' || $type eq 'text') {
            push @blocks, { type => 'text', text => ($part->{text} // '') };
            next;
        }

        if ($type eq 'input_image') {
            push @blocks, _openai_input_image_part_to_anthropic_block($part);
            next;
        }

        if ($type eq 'input_file') {
            die "Content part type 'input_file' is not supported by Anthropic conversion\n";
        }

        if ($type eq 'refusal') {
            die "Content part type 'refusal' is not supported by Anthropic conversion\n";
        }

        if ($type eq 'function_call') {
            my $call_id = $part->{call_id} // die "function_call part requires call_id\n";
            my $name    = $part->{name}    // die "function_call part requires name\n";
            my $args    = _json_string_to_hashref($part->{arguments});
            push @blocks, {
                type  => 'tool_use',
                id    => $call_id,
                name  => $name,
                input => $args,
            };
            next;
        }

        if ($type eq 'tool_use' || $type eq 'tool_result' || $type eq 'image' || $type eq 'document') {
            push @blocks, $part;
            next;
        }

        die "Unsupported OpenAI Responses content part type '$type' for Anthropic conversion\n";
    }

    return \@blocks;
}

sub _push_openai_message_item_to_anthropic ($messages, $system_blocks, $legacy_function_id_for, $item) {
    my $role = $item->{role} // die "Message item requires 'role'\n";

    if ($role eq 'system' || $role eq 'developer') {
        push @$system_blocks, @{ _responses_content_to_anthropic_blocks($item->{content}, $role) };
        return;
    }

    if ($role eq 'user') {
        push @$messages, {
            role    => 'user',
            content => _blocks_or_string(_responses_content_to_anthropic_blocks($item->{content}, 'user')),
        };
        return;
    }

    if ($role eq 'assistant') {
        my @blocks = @{ _responses_content_to_anthropic_blocks($item->{content}, 'assistant') };
        push @$messages, {
            role    => 'assistant',
            content => \@blocks,
        };
        return;
    }

    if ($role eq 'tool') {
        my $tool_call_id = $item->{tool_call_id}
            // $item->{call_id}
            // die "Tool-role message requires 'tool_call_id' or 'call_id'\n";

        push @$messages, {
            role    => 'user',
            content => [
                {
                    type        => 'tool_result',
                    tool_use_id => $tool_call_id,
                    content     => _tool_result_content_from_responses($item->{content}),
                }
            ],
        };
        return;
    }

    die "Unsupported message role '$role' for Anthropic conversion\n";
}

sub _responses_input_to_anthropic_messages ($input, $instructions) {
    my @system_blocks;
    if (defined $instructions) {
        push @system_blocks, { type => 'text', text => $instructions };
    }

    my @messages;
    my %legacy_function_id_for;

    if (!ref($input)) {
        push @messages, {
            role    => 'user',
            content => $input,
        };
        my $system = @system_blocks ? \@system_blocks : undef;
        return ($system, \@messages);
    }

    die "Parameter 'input' must be a string or arrayref\n" unless ref($input) eq 'ARRAY';

    for my $item (@$input) {
        die "Each input item must be a hashref\n" unless ref($item) eq 'HASH';

        my $type = $item->{type};

        if (!defined $type) {
            my $role = $item->{role} // die "Each input item must have either 'type' or 'role'\n";
            _push_openai_message_item_to_anthropic(\@messages, \@system_blocks, \%legacy_function_id_for, {
                type    => 'message',
                role    => $role,
                content => $item->{content},
            });
            next;
        }

        if ($type eq 'message') {
            _push_openai_message_item_to_anthropic(\@messages, \@system_blocks, \%legacy_function_id_for, $item);
            next;
        }

        if ($type eq 'function_call_output') {
            my $call_id = $item->{call_id} // die "Input item type 'function_call_output' requires 'call_id'\n";
            my $output  = $item->{output};

            push @messages, {
                role    => 'user',
                content => [
                    {
                        type        => 'tool_result',
                        tool_use_id => $call_id,
                        content     => _tool_result_content_from_responses($output),
                    }
                ],
            };
            next;
        }

        die "OpenAI Responses input item type '$type' is not supported by Anthropic conversion\n";
    }

    my $system = @system_blocks ? \@system_blocks : undef;
    return ($system, \@messages);
}

sub _anthropic_payload_from_openai_responses ($args) {
    _required($args, 'model');
    die "Missing required parameter 'input'\n" unless exists $args->{input};

    for my $k (qw(
        background
        conversation
        include
        max_tool_calls
        previous_response_id
        prompt
        prompt_cache_key
        prompt_cache_retention
        store
        stream_options
        top_logprobs
        truncation
    )) {
        die "Parameter '$k' is not supported by Anthropic's native Messages API\n"
            if exists $args->{$k};
    }

    if (exists $args->{service_tier}) {
        my $v = $args->{service_tier};
        die "Parameter 'service_tier' value '$v' is not supported by Anthropic's native Messages API\n"
            unless !defined($v) || $v eq 'auto';
    }

    if (exists $args->{reasoning}) {
        die "Parameter 'reasoning' is not supported by this Anthropic converter\n";
    }

    my ($system, $messages) = _responses_input_to_anthropic_messages($args->{input}, $args->{instructions});
    my $tools       = _normalize_openai_responses_tools_for_anthropic($args->{tools});
    my $tool_choice = _normalize_openai_responses_tool_choice_for_anthropic($args->{tool_choice}, $tools, $args->{parallel_tool_calls});

    my %payload = (
        model      => $args->{model},
        messages   => $messages,
        max_tokens => _anthropic_max_tokens_from_responses($args),
    );

    $payload{system}      = $system if defined $system;
    $payload{temperature} = $args->{temperature} if exists $args->{temperature};
    $payload{top_p}       = $args->{top_p} if exists $args->{top_p};
    $payload{stream}      = $args->{stream} ? JSON::PP::true : JSON::PP::false if exists $args->{stream};

    if (exists $args->{text}) {
        my $stop = _openai_text_stop_to_anthropic($args->{text});
        $payload{stop_sequences} = $stop if $stop;
    }

    $payload{tools}       = $tools if $tools && @$tools;
    $payload{tool_choice} = $tool_choice if $tool_choice;

    if (exists $args->{metadata} || exists $args->{safety_identifier}) {
        $payload{metadata} = _normalize_anthropic_metadata($args->{metadata}, $args->{safety_identifier});
    }

    if (exists $args->{text}) {
        my $output_config = _normalize_openai_text_to_anthropic_output_config($args->{text});
        $payload{output_config} = $output_config if $output_config;
    }

    return \%payload;
}

class dv_ai {
    method llm_response ($args) {
        die "llm_response() requires a hashref\n" unless ref($args) eq 'HASH';

        my $provider = lc(_required($args, 'provider'));
        die "provider must be 'openai' or 'anthropic'\n"
            unless $provider eq 'openai' || $provider eq 'anthropic';

        my %allowed_openai = map { $_ => 1 } qw(
            model
            input
            instructions
            background
            conversation
            include
            max_output_tokens
            max_tool_calls
            metadata
            parallel_tool_calls
            previous_response_id
            prompt
            prompt_cache_key
            prompt_cache_retention
            reasoning
            safety_identifier
            service_tier
            store
            stream
            stream_options
            temperature
            text
            tool_choice
            tools
            top_logprobs
            top_p
            truncation
        );

        for my $k (keys %{$args}) {
            next if $k eq 'provider' || $k eq 'api_key' || $k eq 'base_url' || $k eq 'timeout';
            die "Unknown OpenAI Responses API parameter: $k\n" unless $allowed_openai{$k};
        }

        my ($url, %headers, $payload);

        if ($provider eq 'openai') {
            my $api_key = $args->{api_key} // $ENV{OPENAI_API_KEY}
                // die "Missing OpenAI API key\n";

            $url = ($args->{base_url} // 'https://api.openai.com') . '/v1/responses';
            %headers = (
                'content-type'  => 'application/json',
                'authorization' => "Bearer $api_key",
            );
            $payload = _openai_responses_payload($args);
        }
        else {
            my $api_key = $args->{api_key} // $ENV{ANTHROPIC_API_KEY}
                // die "Missing Anthropic API key\n";

            $url = ($args->{base_url} // 'https://api.anthropic.com') . '/v1/messages';
            %headers = (
                'content-type'      => 'application/json',
                'x-api-key'         => $api_key,
                'anthropic-version' => '2023-06-01',
            );
            $payload = _anthropic_payload_from_openai_responses($args);
        }

        my $http = HTTP::Tiny->new(
            timeout         => ($args->{timeout} // 600),
            verify_SSL      => 1,
            default_headers => \%headers,
        );

        my $res = $http->post($url, { content => encode_json($payload) });

        if (!$res->{success}) {
            my $msg = "HTTP $res->{status} $res->{reason}";
            if (defined $res->{content} && length $res->{content}) {
                my $decoded = eval { decode_json($res->{content}) };
                if ($decoded) {
                    if (ref($decoded->{error}) eq 'HASH') {
                        $msg .= ": " . join(' ', grep { defined && length } $decoded->{error}{type}, $decoded->{error}{message});
                    } elsif (defined $decoded->{error}) {
                        $msg .= ": " . $decoded->{error};
                    } else {
                        $msg .= ": " . $res->{content};
                    }
                } else {
                    $msg .= ": " . $res->{content};
                }
            }
            die "$msg\n";
        }

        return ($payload->{stream} ? $res->{content} : decode_json($res->{content}));
    }
}

1;
