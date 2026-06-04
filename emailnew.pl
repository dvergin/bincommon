#!/usr/bin/env perl
use strict;
use warnings;
use Email::Sender::Simple;
use Email::Sender::Transport::SMTP;
use Email::Simple;
use Email::Simple::Creator;
use Email::Stuffer;
use Encode qw(encode);

email{from => 'dvergin@gmail.com',
      to   => 'dvergin@fastmail.net',
      subject => 'Test # 1',
      message => 'This is a test.'};


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

   #my @header = ( To      => $to,
   #               From    => $from,
   #               Subject => $subject_bytes,
   #             );
   #if ($opts{cc}) {
   #   push( @header, (Cc => $opts{cc}) );
   #}
   #my $email = Email::Simple->create(
   #   header => \@header,
   #             body => $message_bytes,
   #);

   #Email::Sender::Simple->send($email, { transport => $transport });
   
   Email::Stuffer->transport ($transport    )
                 ->from      ($from         )
                 ->to        ($to           )
                 ->subject   ($subject_bytes)
                 ->text_body ($message_bytes)
                 ->send;
}

