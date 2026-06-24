#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Email::Sender::Transport::SMTP;
use Email::Stuffer;

email(from => 'dvergin@gmail.com',
      to   => 'dvergin@fastmail.net',
      subject => 'Test # 1 今日',
      message => 'This is a test. 今日はDavid');

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

   my %opts  = @_;

   my $transport = Email::Sender::Transport::SMTP->new({
     host => 'smtp.fastmail.com',
     ssl  => 'starttls',
     sasl_username => $ENV{'FASTMAIL_USERNAME'},
     sasl_password => $ENV{'FASTMAIL_PASSWORD'},
   });

   #Email::Stuffer can take any of the following paramaters
   #   transport   to from cc bcc reply_to   subject    text_body html_body

   my $properties = {};
   $properties->{from} = $opts{from} || 'David Vergin <dvergin@fastmail.net';
   $properties->{to}   = $opts{to}   || 'David Vergin <dvergin@fastmail.net';
   $properties->{cc}   = $opts{cc}  if exists $opts{cc};
   $properties->{bcc}  = $opts{bcc} if exists $opts{bcc};
   Email::Stuffer->new($properties)
      ->transport($transport)
      ->subject($opts{subject},   (charset      => 'UTF-8',
                                   encoding     => 'quoted-printable',
                                   content_type => 'text/plain'))
      ->text_body($opts{message}, (charset      => 'UTF-8',
                                   encoding     => 'quoted-printable',
                                   content_type => 'text/plain'))
      ->send;
}

