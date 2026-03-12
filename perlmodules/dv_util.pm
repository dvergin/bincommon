#!/usr/bin/env perl
use strict;
use warnings;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::Simple::Creator;

=head1 NAME

   dv_util

=head1 SYNOPSIS

   #use rlib 'l';
   use FindBin 1.51 qw( $RealBin );
   use lib $RealBin;
   use dv_util;
   my $util = dv_util->new();

=head1 DESCRIPTION

   Various general purpose tools

=head1 METHODS

=cut

#######################################################################
package dv_util; 
#######################################################################
use Encode qw(encode);

=head2 new()

   my $util = dv_util->new();

=cut

sub new {
   my $class = shift;
   my $opts  = shift;

   my $self = bless { 
                 dv_util => 1,
              }, $class;
   return $self;
}

##################################################################
sub email {
##################################################################

=head2 email()

   # All parameters are optional
   # 'to' and 'from' can be email address only

   $util->email( from    => 'First Last <flast@somemail.com>',
                 to      => 'You Yrlast <yrlst@thatmail.com>',
                 subject => 'The Subject',
                 message => 'The message text'
                );

=cut

   my $class = shift;
   my %opts  = @_;
   my $from    = $opts{from}    || 'David Vergin <dvergin@fastmail.net';
   my $to      = $opts{to}      || 'David Vergin <dvergin@fastmail.net';
   my $subject = $opts{subject} || 'Message from David';
   my $message = $opts{message} || 'Message is in subject line';

   my $subject_bytes = encode('UTF-8', $subject);   # Needed for wide chars, e.g. Japanese
   my $message_bytes = encode('UTF-8', $message);

   #print "ID[$ENV{'FASTMAIL_USERNAME'} PWD[$ENV{'FASTMAIL_PASSWORD'}}\n";

   my $transport = Email::Sender::Transport::SMTP->new({
     # Fastmail Credentials
     host => 'smtp.fastmail.com',
     ssl  => 'starttls',
     sasl_username => $ENV{'FASTMAIL_USERNAME'},
     sasl_password => $ENV{'FASTMAIL_PASSWORD'},
     

   });

   my @header = ( To      => $to,
                  From    => $from,
                  Subject => $subject_bytes,
                );
   if ($opts{cc}) {
      push( @header, (Cc => $opts{cc}) );
   }
   my $email = Email::Simple->create(
      header => \@header,
                body => $message_bytes,
   );

   Email::Sender::Simple->send($email, { transport => $transport });
}

#######################################################################
sub get_date {
#######################################################################

=head2 get_date()

   $util->get_date( { format     => 'MYSQL'|'ISO'|'USER'|'EPOCH', 
                      user_date  => '04/18/48'
                    | mysql_date => '2005/05/18'
                    | ISO_date   => '2005-05-18'
                   #| UTCZ_date  => '2005-05-18T09:47:13[.123]Z
                    | epoch      => $seconds,
                    [ delta      => $delta_in_secs ]
                  } )

   Return value depends on 'format' parameter: 
            String for MYSQL, ISO, USER
            Number for EPOCH

=cut

   use Time::Local;
   my ($self, $opts) = @_;
   #do {my $s; for (keys %$opts) {$s .= "$_=[$opts->{$_}]  "}; die "In " , caller , " $s", $opts->{mysql_date}} if $opts->{mysql_date} eq '0000-00-00';
   #do {my $s; for (keys %$opts) {$s .= "$_=[$opts->{$_}]  "}; die "In " , caller , " $s"};
   $opts->{format} ||= 'MYSQL';
   my ($day, $mon, $year, $sec, $min, $hr, $epoch_secs) = (0, 0, 0, 0, 0, 0, 0);
   #my $this_year_2_digit = (localtime($opts->{epoch}))[5] - 100;
   my $this_year_2_digit = ( localtime() )[5] - 100;

   # FIRST: get the input time as epoch
   if ( exists $opts->{user_date} ) {
      # Note that user_date could be defined but empty -- and that's okay
      #die "userdate is [$opts->{user_date}]";
      if ( $opts->{user_date} ) {
         if ( ($mon, $day, $year) = $opts->{user_date} =~ m#(\d\d?)\D(\d\d?)\D(\d\d(\d\d)?)# ) {
            $year = $year > 1900 ? $year 
                                 : ($year > $this_year_2_digit) ? $year + 1900
                                                                : $year + 2000;
         }
         else {
            die "Bad user_date in get_date";
         }
      }
      #die "(day,month,year) is ($day,$mon,$year)"
   }
   elsif ( exists $opts->{mysql_date} ) {
      #die "Called from ", caller, ' ', $opts->{mysql_date} if $opts->{mysql_date} =~ /48/;
      #die $opts->{mysql_date};
      $opts->{mysql_date} ||= '0000-00-00';
      ($year, $mon, $day) = $opts->{mysql_date} =~ m#(\d\d\d\d)\D(\d\d)\D(\d\d)#;
      #do {my $s; for (keys %$opts) {$s .= "$_=[$opts->{$_}]  "}; die "In " , caller , " $s", $opts->{mysql_date}} if $mon==0;
   }
   elsif ( exists $opts->{today} ) {
      ($day, $mon, $year) = ( localtime() )[3,4,5];
      $mon++;
      $year += 1900;

   }
   elsif ( exists $opts->{epoch} ) {
      ($day, $mon, $year) = ( localtime( $opts->{epoch} ) )[3,4,5];
      $mon++;
      $year += 1900;
   }
   else {
      my $s; 
      for (keys %$opts) {$s .= "$_=[$opts->{$_}]  ";};
      die "No recognizable input time in LdbData.pm:get_date(). Called from ", caller, ' with keys: ', $s;
   }
   
   # Compute the delta if needed
   if ( exists($opts->{delta_weeks}) or exists($opts->{delta_days}) ) {
      #do {my $s; for (keys %$opts) {$s .= "$_=[$opts->{$_}]  "}; die "In " , caller , " $s"} if $mon==0;
      if ( $day eq '00' || $mon eq '00' || $year eq '0000' ) {
         my $s; 
         for (keys %$opts) {$s .= "$_=[$opts->{$_}]  "}; 
         die "Called from " , caller , " $s, day=$day mon=$mon year=$year"
      }
      $epoch_secs ||= Time::Local::timelocal(0, 0, 12, $day, $mon-1, $year-1900);
      if ( exists $opts->{delta_weeks} ) { 
         $epoch_secs += $opts->{delta_weeks}*60*60*24*7; 
      }
      if ( exists $opts->{delta_days} ) { 
         $epoch_secs += $opts->{delta_days }*60*60*24;
      }
      ($day, $mon, $year) = (localtime($epoch_secs))[3,4,5];
      $mon++;
      $year += 1900;
   }
      
   # LAST: Gave back according to the requested format
   my $date;
   #die "$year  $mon  $day";
   for ($opts->{format}) {
        /ISO/ && do {$date = sprintf("%04d-%02d-%02d", $year, $mon, $day);
                     $date = '' if $date eq '0000-00-00';
                     last;};
      /MYSQL/ && do {$date = sprintf("%04d/%02d/%02d", $year, $mon, $day);
                     $date = '' if $date eq '0000/00/00';
                     last;};
       /USER/ && do {$date = sprintf("%02d/%02d/%04d", $mon, $day, $year);
                     $date = '' if $date eq '00/00/0000';
                     last;};
       'else' && do {die "Bad format [$opts->{format}] in LdbData.pm:get_date()"};
   }
   #die "date is [$date]" if exists $opts->{user_date};
   #die "date is [$date]";
   return $date;
}

#######################################################################
sub looks_like_num {
#######################################################################

=head2 looks_like_num()

   my $isnum = $dv_util->looks_like_num($some_val);

=cut

   my ($self, $val) = @_;
   my $tmp = $val =~ /^-?[0-9.]+$/;
   return $val =~ /^-?[0-9.]+$/;
}

 #######################################################################
sub max_length {
#######################################################################

=head2 max_length()

   my $longestLength = $dv_util->max_length($str1, $str2, ...);

=cut

   my $self = shift;
   my $max = 0;
   for (@_) {
      $max = length($_) if length($_) > $max;
   }
   return $max;
}

#######################################################################
sub pad_left {
#######################################################################

=head2 pad_left()

   print $dv_util->pad_left('a string', $totalStringLength);

=cut

   my ($self, $str, $len) = @_;
   return ' ' x ($len - length($str)) . $str;
}

#######################################################################
sub pad_right {
#######################################################################

=head2 pad_right()

   print $dv_util->pad_right('a string', $totalStringLength);

=cut

   my ($self, $str, $len) = @_;
   return $str . ' ' x ($len - length($str));
}

#######################################################################
sub parse_ini_file {
#######################################################################

=head2 parse_ini_file()

   my $ini_href = $dv_util->parse_ini_file('/path/to/file');

=cut

   my ($self, $filepath) = @_;
   my @ini_file_lines = slurp($self, $filepath);
   my $ini_data_href;
   my $section = 'null';
   for my $line (@ini_file_lines) {
      chomp($line);
      next if $line =~ /^;/;   # Comment
      next if $line =~ /^ *$/; # Empty line
      if ($line =~ /\[([^]]+)]/) {
         $section = $1;
      } else {
         my ($key, $val) = split('=', $line, 2);
         $ini_data_href->{$section}{$key} = $val;
      }
   }
   return $ini_data_href;
}

#######################################################################
sub perlref_to_json {
#######################################################################

=head2 perlref_to_json()

   my $json_string = $dv_util->perlref_to_json($perlvalref);

=cut

   my ($self, $valref) = @_;
   my $returnjson = '';
   my $valtype = ref($valref);
   if (not $valtype) {             # It's an actual string or number
      return '' . $valref;
   } elsif ($valtype eq 'ARRAY') {
      my @jsonbits = map {ref($_) ? perlref_to_json($self, $_)
                                  : looks_like_num($self, $_) ? ''.$_
                                                              : qq/"$_"/
                     } @$valref;
      return '[' . join(', ', @jsonbits) . ']';
   } elsif ($valtype eq 'HASH') {
      my @jsonbits = map {ref($valref->{$_}) ? qq/"$_": / . perlref_to_json($self, $valref->{$_})
                                             : looks_like_num($self, $valref->{$_})
                                                    ? qq/"$_": $valref->{$_}/
                                                    : qq/"$_": "$valref->{$_}"/
                     } sort keys %$valref;
      #use Data::Dumper; print Dumper(\@jsonbits);
      return '{' . join(', ', @jsonbits) . '}';
   }
}

#######################################################################
sub slurp { 
#######################################################################

=head2 slurp()

   my $content = $dv_util->slurp($filepath);  # returns entire contents
                                              # as chunk or array depending
                                              # on string/array context

=cut

   my $self = shift;
   local( $/, @ARGV ) = ( wantarray ? $/ : undef, @_ ); 
   return <ARGV>;
}

#######################################################################
sub spew {
#######################################################################

=head2 spew()

   $dv_util->spew($filepath, $content);  # Writes $content to named file
   $dv_util->spew($filepath, @content);  # Writes @content to named file

=cut

   my $self = shift;
   my( $file_name ) = shift ;
   open( my $fh, '>', "$file_name" )  
      or die "can't use $file_name for write operation $!" ;
   print $fh @_ ;
   close($fh);
}

#######################################################################
1;
#######################################################################

