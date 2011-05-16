#!/usr/local/bin/perl

use strict;
use warnings;
use FindBin qw( $RealBin $Script );
use lib "$RealBin/../lib";
use YAML;

use UseCase::Config;
use Multi::Config;

my $config_usecase = UseCase::Config->new();

$config_usecase->run();

my $config = Multi::Config->sharedConfig();

$config->setValueOf( foo => 'bar' );

printf "Configuration:\n%s\n", $config->dump( includeLocations => 1 );

exit( 0 );
