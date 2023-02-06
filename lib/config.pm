#!/usr/bin/perl

package config;

use strict;
use warnings;
use v5.14;
use JSON;
use DBI;
use Hash::Merge;
use Exporter; # Gain export capabilities 

our $configFile = "threadreadermirror.conf";
our %config     = load_config();

# Exported variables & functions.
our (@EXPORT, @ISA);    # Global variables 

@ISA    = qw(Exporter); # Take advantage of Exporter's capabilities
@EXPORT = qw(
    $configFile
    %config
);                      # Exported variables.

sub load_config {
    unless (-f $configFile) {
        $configFile = "../../threadreadermirror.conf";
        die unless -f $configFile;
    }
    my $config = do("./$configFile");
    return %$config;
}

1;