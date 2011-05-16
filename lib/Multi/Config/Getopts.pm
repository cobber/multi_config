package Multi::Config::Getopt;

use strict;
use warnings;
use YAML;
use GetOpt::Long;
use Multi::Config;

sub new
    {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    $self->{parsedOptions} = {};
    $self->{optionSpec}     ||= [
        # TODO: Riehm [2011-05-16] merge with options provided by the caller
        'configuration',
        'debug',
        'help',
        'verbose',
        'version',
        ];

    return( $self );
    }

sub load
    {
    my $self = shift;

    GetOpt::Long::Configure qw( require_order pass_through );
    GetOptions( $self->{parsedOptions}, @{$self->{optionSpec}} );

    my $config = Config::Multi->sharedConfig();

    foreach my $key ( keys %{$self->{parsedOptions}} )
        {
        $sharedConfig->set( $key => $self->{parsedOptions}{$key}, "--$key" );
        }

    return;
    }

1;
