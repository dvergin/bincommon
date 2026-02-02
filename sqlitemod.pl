#!/usr/bin/env perl
# Author: ChatGPT, OpenAI (Date: 2024-11-04)
# This script is used to modify SQLite databases by adding or deleting fields.

use strict;
use warnings;
use DBI;

my $command = shift @ARGV || 'usage';

if ($command eq 'fields') {
    if (@ARGV != 2) {
        print_usage();
        exit;
    }
    list_fields($ARGV[0], $ARGV[1]);
}
elsif ($command eq 'add' || $command eq 'delete') {
    if (@ARGV != 3) {
        print_usage();
        exit;
    }
    my ($dbfilename, $tablename, $fieldname) = @ARGV;
    if ($command eq 'add') {
        add_field($dbfilename, $tablename, $fieldname);
    }
elsif ($command eq 'delete') {
        delete_field($dbfilename, $tablename, $fieldname);
    }
}
elsif ($command eq 'schema') {
    if (@ARGV != 1) {
        print_usage();
        exit;
    }
    list_schema($ARGV[0]);
}
else {
    print_usage();
}

sub print_usage {
    print <<~'END_USAGE';
    Usage: sqlitemod.pl <command> [arguments]

    Commands:
        sqlitemod.pl fields <dbfilename> <tablename>             List all fields in the specified table
        sqlitemod.pl schema <dbfilename>                         List all fields in every table
        sqlitemod.pl add <dbfilename> <tablename> <fieldname>    Add a field to the specified table
        sqlitemod.pl delete <dbfilename> <tablename> <fieldname> Delete a field from the specified table
    END_USAGE
}

sub list_fields {
    my ($dbfilename, $tablename) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfilename", "", "", { RaiseError => 1 })
        or die $DBI::errstr;

    my $sth = $dbh->prepare("PRAGMA table_info($tablename)");
    $sth->execute();
    print "Table: $tablename\n";
    while (my $row = $sth->fetchrow_hashref) {
        print "    Field: $row->{name}\n";
    }

    $dbh->disconnect;
}

sub add_field {
    my ($dbfilename, $tablename, $fieldname) = @_;
    make_backup($dbfilename);
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfilename", "", "", { RaiseError => 1 })
        or die $DBI::errstr;

    # Add a column to the specified table
    my $alter_stmt = "ALTER TABLE $tablename ADD COLUMN $fieldname TEXT";
    eval {
        $dbh->do($alter_stmt);
        print "Field '$fieldname' added to table '$tablename'.\n";
    };
    if ($@) {
        warn "Error adding field '$fieldname': $@\n";
    }

    $dbh->disconnect;
}

sub delete_field {
    my ($dbfilename, $tablename, $fieldname) = @_;
    make_backup($dbfilename);
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfilename", "", "", { RaiseError => 1 })
        or die $DBI::errstr;

    # Get column information for the specified table
    my $sth = $dbh->prepare("PRAGMA table_info($tablename)");
    $sth->execute();
    my @columns;
    my $field_exists = 0;
    while (my $row = $sth->fetchrow_hashref) {
        if ($row->{name} eq $fieldname) {
            $field_exists = 1;
            next;
        }
        push @columns, $row->{name};
    }

    if (!$field_exists) {
        print "Field '$fieldname' does not exist in table '$tablename'.\n";
        $dbh->disconnect;
        return;
    }

    # Create a new table without the specified field
    my $columns_str = join(", ", @columns);
    my $new_table_name = "${tablename}_new";
    my $create_stmt = "CREATE TABLE $new_table_name AS SELECT $columns_str FROM $tablename";
    eval {
        $dbh->do($create_stmt);
        print "Table '$new_table_name' created without field '$fieldname'.\n";
    };
    if ($@) {
        warn "Error creating new table without field '$fieldname': $@\n";
        $dbh->disconnect;
        return;
    }

    # Drop the old table and rename the new one
    eval {
        $dbh->do("DROP TABLE $tablename");
        $dbh->do("ALTER TABLE $new_table_name RENAME TO $tablename");
        print "Field '$fieldname' deleted from table '$tablename'.\n";
    };
    if ($@) {
        warn "Error finalizing table modification: $@\n";
    }

    $dbh->disconnect;
}

sub make_backup {
    my ($dbfilename) = @_;
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;
    my $timestamp = sprintf("%04d-%02d-%02d_%02d-%02d-%02d", $year, $mon, $mday, $hour, $min, $sec);
    my $backup_filename = "$dbfilename-$timestamp.sqlite";
    eval {
        require File::Copy;
        File::Copy::copy($dbfilename, $backup_filename) or die "Backup failed: $!";
        print "Backup created: $backup_filename\n";
    };
    if ($@) {
        warn "Error creating backup: $@\n";
    }
}

sub list_schema {
    my ($dbfilename) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfilename", "", "", { RaiseError => 1 })
        or die $DBI::errstr;

    my $tables_sth = $dbh->prepare("SELECT name FROM sqlite_master WHERE type='table'");
    $tables_sth->execute();
    while (my $table = $tables_sth->fetchrow_arrayref) {
        my $table_name = $table->[0];
        print "Table: $table_name
";
        my $sth = $dbh->prepare("PRAGMA table_info($table_name)");
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref) {
            print "    Field: $row->{name}
";
        }
    }

    $dbh->disconnect;
}

__END__

