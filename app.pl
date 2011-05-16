#!/usr/local/bin/perl

use strict;
use warnings;
use FindBin qw( $RealBin $Script );
use lib "$RealBin/lib";
use YAML;

use UseCase::Config;
use Multi::Config;

my $config_usecase = UseCase::Config->new();

$config_usecase->run();

printf "Configuration:\n%s\n", Multi::Config->sharedConfig()->dump( includeLocations => 1 );

exit( 0 );
