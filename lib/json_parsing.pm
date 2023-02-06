#!/usr/bin/perl

package json_parsing;

use strict;
use warnings;
use v5.14;
use JSON;
use DBI;
use Hash::Merge;
use Exporter; # Gain export capabilities 

# Exported variables & functions.
our (@EXPORT, @ISA);    # Global variables 

our $threadsFile = 'threadreaderapp_index.json';

@ISA    = qw(Exporter); # Take advantage of Exporter's capabilities
@EXPORT = qw(
	$threadsFile
);                      # Exported variables.

sub json_from_file {
    my $file = shift;
    if (-f $file) {
        my $json;
        eval {
            open my $in, '<:utf8', $file;
            while (<$in>) {
                $json .= $_;
            }
            close $in;
            $json = decode_json($json) or die $!;
        };
        if ($@) {
            {
                local $/;
                open (my $fh, $file) or die $!;
                $json = <$fh>;
                close $fh;
            }
            eval {
                $json = decode_json($json);
            };
            if ($@) {
                die "failed parsing json : " . @!;
            }
        }
        return $json;
    } else {
        return {};
    }
}

1;