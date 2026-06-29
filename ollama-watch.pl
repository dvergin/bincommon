#!/usr/bin/env perl
use strict;
use warnings;
use HTTP::Tiny;
use HTML::Entities qw(decode_entities);

my $url  = 'https://ollama.com/library';
my $days = shift // 14;

die "Usage: $0 [days]\n" unless $days =~ /^\d+$/ && $days > 0;

my $res = HTTP::Tiny->new(
    timeout => 20,
    agent   => 'ollama-watch/1.0',
)->get("$url?sort=newest");

die "Could not fetch $url?sort=newest: $res->{status} $res->{reason}\n"
    unless $res->{success};

my $html = $res->{content};
$html =~ s/\r?\n/ /g;

my @found;
my $order = 0;

while ($html =~ m{<li\b[^>]*\bx-test-model\b[^>]*>(.*?)</li>}sig) {
    my $chunk = $1;

    my ($name) = $chunk =~ m{<div\b[^>]*\bx-test-model-title\b[^>]*\btitle=["']([^"']+)["']}i;
    next unless defined $name;
    $name = clean_text($name);

    my ($updated) = $chunk =~ m{<span\b[^>]*\bx-test-updated\b[^>]*>(.*?)</span>}is;
    next unless defined $updated;
    $updated = clean_text($updated);

    my $age = age_to_days($updated);
    next unless defined $age && $age <= $days;

    my @sizes = map { clean_text($_) }
        $chunk =~ m{<span\b[^>]*\bx-test-size\b[^>]*>(.*?)</span>}sig;

    my $size_text = @sizes ? join(', ', @sizes) : '-';
    push @found, [$name, $size_text, format_days($age), $age, $order++];
}

@found = sort { $a->[3] <=> $b->[3] || $a->[4] <=> $b->[4] } @found;

print "Ollama models newly listed/updated within $days days:\n";
print @found ? format_rows(@found) : "None found.\n";

sub clean_text {
    my ($text) = @_;
    $text = decode_entities($text // '');
    $text =~ s/<[^>]+>/ /g;
    $text =~ s/\s+/ /g;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

sub format_days {
    my ($days) = @_;
    my $label = $days == 1 ? 'day' : 'days';
    return sprintf "%2d %s", $days, $label;
}

sub age_to_days {
    my ($text) = @_;

    return 0 if $text =~ /^(?:just now|today)$/i;
    return 1 if $text =~ /^yesterday$/i;

    my ($n, $unit) =
        $text =~ /^(\d+)\s+(minute|minutes|hour|hours|day|days|week|weeks|month|months|year|years)\s+ago$/i;

    return unless defined $n;

    return 0        if $unit =~ /^minutes?$/i;
    return 0        if $unit =~ /^hours?$/i;
    return $n       if $unit =~ /^days?$/i;
    return $n * 7   if $unit =~ /^weeks?$/i;
    return $n * 30  if $unit =~ /^months?$/i;
    return $n * 365 if $unit =~ /^years?$/i;
    return;
}

sub format_rows {
    my (@rows) = @_;

    my @widths = (0, 0);
    for my $row (@rows) {
        for my $i (0, 1) {
            my $len = length $row->[$i];
            $widths[$i] = $len if $len > $widths[$i];
        }
    }

    return map {
        sprintf "%-*s  %-*s  %s\n",
            $widths[0], $_->[0],
            $widths[1], $_->[1],
            $_->[2]
    } @rows;
}
