#!/usr/bin/env perl -T
use strict;
use warnings;
use Data::Dumper;

#######################################################################
package dv_dropbox; 
#######################################################################

use IO::File;
use IO::String;
use WebService::Dropbox;
# https://metacpan.org/pod/WebService::Dropbox
use Data::Dumper;

#use FindBin qw( $RealBin );
#use lib $RealBin;
use lib '/home/dvergin/bincommon/perlmodules';
use dv_util;
my $util = dv_util->new();

=head1 NAME

   dv_dropbox

=head1 SYNOPSIS

   use FindBin qw( $RealBin );
   use lib $RealBin;
   use dv_dropbox;
   my $dbx = dv_dropbox->new();

=head1 DESCRIPTION

   Various Dropbox tools

=head1 METHODS

=cut

######################################################################
sub new {
######################################################################

=head2 new()

   my $dbx = dv_dropbox->new();
   my $dbx = dv_dropbox->new({param_file => '/file/path'});

=cut

   my $class = shift;
   my $opts  = shift;
   my $param_file = $opts->{param_file} || '~/.dropbox';
   #die $opts->{param_file};
   #die Dumper($opts);
   $param_file = glob($param_file);  # Glob unwinds ~ to actual dir

   my %dbx_params;
   # glob() is needed to expand '~' (home directory) if present
   open my $dbx_param_file, '<', glob($param_file)
      or die "Cannot open dropbox parameter file ($param_file): $!\n";
   while (<$dbx_param_file>) {
      next unless /\S/;
      next if /^#/;
      chomp;
      my ($key, $val) = split(/\s+/, $_);
      $dbx_params{$key} = $val;
   }
   close $dbx_param_file;
   my $dropbox = WebService::Dropbox->new( 
                      { access_token => $dbx_params{access_token} });
   my $since_last = time() - $dbx_params{epoch};
   my $dir_tracking = $since_last < 3600 ? 1 : 0;
   my $self = bless { dropbox      => $dropbox,
                      access_token => $dbx_params{access_token},
                      directory    => $dbx_params{directory},
                      param_file   => $param_file,
                    }, $class;
   if ($dir_tracking) {
      update_dropbox_param_file($self);
   }
   return $self;
}

#######################################################################
sub delete {
#######################################################################

=head2 delete()

   $dbx->delete($fullpath);

=cut

   my $self     = shift;
   my $fullpath = shift;
   my $dropbox  = $self->{dropbox};
   my $metadata = $dropbox->delete($fullpath)
      or die $dropbox->error;
}

#######################################################################
sub get_dir {
#######################################################################

=head2 get_dir()

   my $dir_href = $dbx->get_dir({path    => '/dropbox/path', 
                                 [filter => 'a_regex']});
   #
   # returns: { subdir   => {'.tag' => 'folder'},
   #            ...
   #            filename => {'.tag'          => 'file',
   #                         size            => 456,
   #                         client_modified => '2018-12-30T06:12:58Z'}
   #            ...
   #          }

=cut

   my $self = shift;
   my $opts = shift;
   my $dirspec = $opts->{path};
   $dirspec = $dirspec eq '/' ? '' : $dirspec; #required by dropbox module
   my $dbox = $self->{dropbox};
   my $regex = $opts->{'filter'} || '.';
   my $dir_href = {};
   my $dir_result = $dbox->list_folder($dirspec)
               or die $dbox->error;
   my $have_dat = 1;
   while ($have_dat) {
      for my $entry (@{$dir_result->{entries}}) {
         next if $entry->{'.tag'} eq 'file' && $entry->{name} !~ /$regex/;
         $dir_href->{$entry->{name}} = $entry;
      }
      if ($dir_result->{has_more}) {
         $dir_result = $dbox->list_folder_continue($dir_result->{cursor});
      } else {
         $have_dat = 0;
      }
   }
   return $dir_href;
}

#######################################################################
sub get_file {
#######################################################################

=head2 get_file()

   my $filecontent = $dbx->get_file({sourcepath => '/some/path',
                                     get_as     => 'string'});
   $dbx->get_file({sourcepath => '/dropbox/path',
                   get_as     => 'file',
                   destination => '/local/path'});

=cut

   my $self    = shift;
   my $opts    = shift;
   my $dropbox = $self->{dropbox};
   my $desthandle;
   my $return_val;
   my $local_handle;

   if ($opts->{get_as} eq 'string') {
      $local_handle = IO::String->new($return_val);
   } 
   elsif ($opts->{get_as} eq 'file') {
      my $destination = $opts->{destination};
      if (not $destination) {
         ($destination) = $opts->{sourcepath} =~ m#([^/]*)$#;
      }
      $local_handle = IO::File->new($destination, '>');
   } 
   else {
      die "Bad or missing 'get_as' param in get_file\n";
   }
   $dropbox->download($opts->{sourcepath}, $local_handle) 
      or die $dropbox->error;
   $local_handle->close;

   return $return_val;
}

#######################################################################
sub get_meta_data {
#######################################################################

=head2 get_meta_data()

   my $metadata = $dbx->get_meta_data();

=cut

   my $self    = shift;
   my $path    = shift;
   my $dropbox = $self->{dropbox};
   my $metadata = $dropbox->get_metadata($path);
   return $metadata;
}

#######################################################################
sub make_dir {
#######################################################################

=head2 make_dir()

   my $metadata = $dbx->make_dir('dir/path');

=cut

   my $self    = shift;
   my $dirspec = shift;
   my $dropbox = $self->{dropbox};
   my $metadata = $dropbox->create_folder($dirspec)
                     or die $dropbox->error;
   return $metadata;
}

#######################################################################
sub put_file {
#######################################################################

=head2 put_file()

   $dbx->put_file({sourcetype  => 'string',
                   source      => $content,
                   destination => '/dropbox/path'});
   $dbx->put_file({sourcetype  => 'file',
                   source      => 'file/path',
                   destination => '/dropbox/path});

=cut

   my $self    = shift;
   my $opts    = shift;
   my $dropbox = $self->{dropbox};
   my $source_handle;
   if ( $opts->{sourcetype} eq 'string' ) {
      $source_handle = IO::String->new( $opts->{source} );
   } 
   elsif ( $opts->{sourcetype} eq 'file' ) {
      $source_handle = IO::File->new( $opts->{source} );
   }
   $dropbox->upload($opts->{destination}, 
                    $source_handle,
                    {mode => 'overwrite'},
                   )
      or die $dropbox->error;
   $source_handle->close;
}

#######################################################################
sub update_dropbox_param_file {
#######################################################################
   my $self = shift;
   my $epoch = time();
   $util->spew($self->{param_file}, 
               "access_token $self->{access_token}\n"
             . "directory    $self->{directory}\n"
             . "epoch        $epoch\n");
}

#######################################################################
#######################################################################
1;

