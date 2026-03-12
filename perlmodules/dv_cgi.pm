use strict;
use warnings;
use URI::Escape;

=head1 NAME
   dv_cgi

=head1 SYNOPSIS

   use FindBin qw( $RealBin );
   use lib $RealBin;
   or
   use rlib 'l';
   use dv_cgi;
   my $cgi = dv_cgi->new();
   
=head1 DESCRIPTION

=head1 METHODS

=cut

#######################################################################
package dv_cgi;
#######################################################################
use Digest::SHA qw(sha384_hex);
use POSIX qw(strftime);
use URI::Escape qw(uri_escape);
use Time::Local qw(timegm);

=head2 new()

   my $cgi = dv_cgi->new();

=cut

sub new {

   my $class = shift;
   my $opts  = shift;

   my $self = bless { 
                 dv_cgi => 1,
              }, $class;
   return $self;
}

#######################################################################
sub get_body_content {
#######################################################################

=head2 get_body_content()

   my $formdata = $cgi->get_form_data();   # Returns string

=cut

      my $body_content = "";
      if ( $ENV{CONTENT_LENGTH} ) {
         read( STDIN, $body_content, $ENV{CONTENT_LENGTH} ) == $ENV{CONTENT_LENGTH}
            or die;
      }
      #die $body_content;

   return $body_content;
}

#######################################################################
sub get_cookie_data {
#######################################################################

=head2 get_cookie_data()

   my $cookies = $cgi->get_cookie_data();   # Returns hashref

=cut

   my $cookies = {};
   $ENV{'HTTP_COOKIE'} ||= '';
   for my $cookie_pair ( split /;\s*/, $ENV{'HTTP_COOKIE'} ) {
      my ($key, $val) = split /=/, $cookie_pair;
      $cookies->{$key} = $val;
   }
   return $cookies;
}

#######################################################################
sub get_form_data {
#######################################################################

=head2 get_form_data()

   my $formdata = $cgi->get_form_data();   # Returns href

   NOTE: Multi-select form fields return a scalar for a single
         selection and an aref for multiple selections

=cut

   # From: CGI Programming with Perl, p. 81
   my $form_data = {};
   my $name_value;
   #my @name_value_pairs = split /&/, $ENV{QUERY_STRING};
   my @name_value_pairs = ();

   if ( $ENV{REQUEST_METHOD} eq 'POST' ) {
      my $query = "";
      read( STDIN, $query, $ENV{CONTENT_LENGTH} ) == $ENV{CONTENT_LENGTH}
         or return undef;
      #die $query;
      push @name_value_pairs, split /&/, $query;
   }

   foreach $name_value ( @name_value_pairs ) {
      my( $name, $value ) = split /=/, $name_value;

      $name =~ tr/+/ /;
      $name =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;

      $value = "" unless defined $value;
      $value =~ tr/+/ /;
      $value =~ s/%([\da-f][\da-f])/chr( hex($1) )/egi;
        
      if (exists $form_data->{$name}) {
         if ( ref($form_data->{$name}) ) {
            # If there is already a single scalar here, 
            # make this an aref and insert that prev value
            $form_data->{$name} = [ $form_data->{$name} ];
         }
         push @{$form_data->{$name}}, $name;
      } else {
         $form_data->{$name} = $value;
      }
   }
   return $form_data;
}

#######################################################################
sub get_path_info {
#######################################################################

=head2 get_path_info()

   my $pathinfo = $cgi->get_path_info();    # Returns dirs in extended path as aref

=cut

   my $pathinfo_str = defined $ENV{"PATH_INFO"} ? $ENV{"PATH_INFO"} : "";
   my @pathinfo = split /\//, $pathinfo_str;
   shift @pathinfo; # Remove undef element caused by leading '/' in pathinfo
   return \@pathinfo;
}

#######################################################################
sub get_qstr_data {
#######################################################################

=head2 get_qstr_data()

   my $qstrdat = $cgi->get_qstr_data();    # Returns href

=cut

   my $self = shift;
   my $query_str = $self->get_query_string();
   #my $query_str = defined $ENV{"QUERY_STRING"} ? $ENV{"QUERY_STRING"} : "";
   #die $query_str;
   my $qstr_data;
   for my $qstr_pair (split /&/, $query_str) {
      my ($key, $val) = split /=/, $qstr_pair;
      $qstr_data->{$key} = URI::Escape::uri_unescape($val);
   }
   return $qstr_data;
}

#######################################################################
sub get_query_string {
#######################################################################

=head2 get_query_string()

   my $query_string = $cgi->get_query_string();

=cut

   return defined $ENV{"QUERY_STRING"} ? $ENV{"QUERY_STRING"} : "";
}

#######################################################################
sub hash_password {
#######################################################################

=head2 hash_password()

   my $hashed_pwd = $cgi->hash_password();

=cut

    my ($password) = @_;
    my $salt = random_salt(16);
    my $hashed_password = sha384_hex($password . $salt);
    my $stored_string = "$hashed_password:$salt";
    return $stored_string;
}

#######################################################################
sub logged_in {
#######################################################################

=head2 logged_in()

   my $loggedin = $cgi->logged_in();    # Returns true or false
   my $loggedin = $cgi->logged_in('userinfo.sqlite');
       # User IDs and SHA hashes in database file

=cut 

   my $self = shift;
   my $cookies = $self->get_cookie_data();
   $cookies->{'dvergin-org'} ||= '<none>';  # avoid null in next 'eq' test
   return ($cookies->{'dvergin-org'} eq 'Mu-Ra-Ki-No');
}

#######################################################################
sub login_if_needed {
#######################################################################

=head2 login_if_needed()

   $cgi->login_if_needed();    # Jumps to login page unless logged in

=cut 

   my $self = shift;
   my $cookies = $self->get_cookie_data();
   #die $cookies->{'dvergin-org'};
   if ( not ($cookies->{'dvergin-org'} eq 'Mu-Ra-Ki-No') ) {
      print "Location: /cgi/login.pl\n\n";
      exit;
      ### EXIT HERE TO LOGIN PAGE ###
   }
}

#######################################################################
sub make_cookie_line {
#######################################################################

=pod

=head2 make_cookie_line

    my $header = make_cookie_line(
        name     => 'session',      # required; not encoded
        value    => 'abc123',       # required; encoded
        expires  => '7 days',       # optional; X seconds/minutes/hours/days or DD MMM YYYY
        max_age  => '1 hours',      # optional; X seconds/minutes/hours/days or DD MMM YYYY
        secure   => 1,              # optional; truthy (except literal 'false')
    );

Returns a complete C<Set-Cookie: ...> header line (no trailing newline).

=cut

    my (%args) = @_;

    sub _parse_time {
        my ($spec, $want) = @_;
        die "Invalid time spec" unless defined $spec;

        my $now = time;

        if ($want eq 'seconds') {
            return (0 + $1)             if $spec =~ /^\s*(\d+)\s*$/;
            return ($1)                 if $spec =~ /^\s*(\d+)\s*seconds?\s*$/i;
            return ($1 * 60)            if $spec =~ /^\s*(\d+)\s*minutes?\s*$/i;
            return ($1 * 3600)          if $spec =~ /^\s*(\d+)\s*hours?\s*$/i;
            return ($1 * 86400)         if $spec =~ /^\s*(\d+)\s*days?\s*$/i;

            if ($spec =~ /^\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s*$/) {
                my ($d, $m, $y) = ($1, $2, $3);
                my %mon = (
                    Jan=>0, Feb=>1, Mar=>2, Apr=>3, May=>4, Jun=>5,
                    Jul=>6, Aug=>7, Sep=>8, Oct=>9, Nov=>10, Dec=>11
                );
                die "Invalid month in time spec" unless exists $mon{$m};
                my $target = timegm(0, 59, 23, $d, $mon{$m}, $y - 1900);
                my $secs = $target - $now;
                $secs = 0 if $secs < 0;
                return int($secs);
            }

            die "Invalid time format";
        }

        if ($want eq 'http') {
            return strftime("%a, %d %b %Y 23:59:00 GMT", gmtime($now + (0 + $1)))
                if $spec =~ /^\s*(\d+)\s*$/;
            return strftime("%a, %d %b %Y 23:59:00 GMT", gmtime($now + $1))
                if $spec =~ /^\s*(\d+)\s*seconds?\s*$/i;
            return strftime("%a, %d %b %Y 23:59:00 GMT", gmtime($now + $1 * 60))
                if $spec =~ /^\s*(\d+)\s*minutes?\s*$/i;
            return strftime("%a, %d %b %Y 23:59:00 GMT", gmtime($now + $1 * 3600))
                if $spec =~ /^\s*(\d+)\s*hours?\s*$/i;
            return strftime("%a, %d %b %Y 23:59:00 GMT", gmtime($now + $1 * 86400))
                if $spec =~ /^\s*(\d+)\s*days?\s*$/i;

            if ($spec =~ /^\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s*$/) {
                my ($d, $m, $y) = ($1, $2, $3);
                my %mon = (
                    Jan=>0, Feb=>1, Mar=>2, Apr=>3, May=>4, Jun=>5,
                    Jul=>6, Aug=>7, Sep=>8, Oct=>9, Nov=>10, Dec=>11
                );
                die "Invalid month in time spec" unless exists $mon{$m};
                my $target = timegm(0, 59, 23, $d, $mon{$m}, $y - 1900);
                return strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime($target));
            }

            die "Invalid time format";
        }

        die "Invalid time output mode";
    }

    my ($name, $encoded_value) = (
        $args{name} // die "name required",
        uri_escape($args{value} // die "value required"),
    );

    my @parts = ("$name=$encoded_value");

    if (defined $args{max_age}) {
        my $secs = _parse_time($args{max_age}, 'seconds');
        push @parts, "Max-Age=$secs";
    }

    if (defined $args{expires}) {
        my $http_expires_date = _parse_time($args{expires}, 'http');
        push @parts, "Expires=$http_expires_date";
    }

    if ($args{secure} && $args{secure} ne 'false') {
        push @parts, "Secure";
    }

    return "Set-Cookie: " . join("; ", @parts);
}

#######################################################################
sub on_the_web {
#######################################################################

=head2 on_the_web()

   $cgi->on_the_web();    # Returns true if on the web, false if cli

=cut 

   return exists $ENV{'HTTP_HOST'};

}

#######################################################################
sub random_salt {
#######################################################################

=head2 random_salt()

   $cgi->random_salt($len);    # Returns a random salt string of length $len

=cut 

   my $length = shift;
   my @chars = ('A'..'Z', 'a'..'z', '0'..'9');
   return join('', map { $chars[rand @chars] } 1..$length);
}

#######################################################################
#######################################################################

1;

