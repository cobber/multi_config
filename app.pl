#!/usr/local/bin/perl

use strict;
use warnings;
use FindBin qw( $RealBin $Script );
use lib "$RealBin/lib";
use YAML;

use UseCase::Config;

my $config_usecase = UseCase::Config->new();

$config_usecase->run();

exit( 0 );
