package Multi::Config::Getopt;

use strict;
use warnings;
use YAML;
use Getopt::Long;

sub new
    {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    return( $self );
    }

sub import
    {
    my $self = shift;
    }

1;
