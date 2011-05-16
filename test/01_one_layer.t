#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use FindBin qw( $RealBin );
use lib "$RealBin/../lib";

BEGIN {
    use_ok( 'Multi::Config' );
}

my $shared_config = Multi::Config->sharedConfig();

ok( $shared_config, 'shared config should always be defined' );
isa_ok( $shared_config, 'Multi::Config', 'shared config should be an object of the right type' );

diag( $shared_config->dump() );

done_testing();
exit 0;
