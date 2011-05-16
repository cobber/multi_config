package Multi::Config;

# Concept:
#   provide multi-level configuration by building a stack of option groups.
#   The typical stack might look like this:
#
#       0:  runtime configuration
#       1:  command line options
#       2:  user configuration (from ~/.<app>rc)
#       3:  host configuration (from /etc/<app>rc)
#       4:  Site configuration (from /Site/<app>/Configuration.xml)
#       5:  configuration from database
#       6:  Application defaults (from application installation directory)
#
#   Each layer must be handled by its own loader, which is able to refer to the
#   current configuration, and may only change values on it's own layer.
#
#   Setting Configuration Parameters:
#
#       at any point in time, there is a single, current layer.
#
#       during set-up, the current layer is set before the loader is given control
#           each loader may only set parameters by calling:
#               my $config = Multi::Config->sharedConfig();
#               $config->set( <key> => <value>, <location> );
#
#       After setup has been completed, the all changes to the configuration
#       take place on the top-level only, the 'runtime' level
#

use strict;
use warnings;
use YAML;

my $sharedConfig = undef;

sub new
    {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    $self->{layerStack}         = [];     # [ { <key> => { value => ..., location => ... } }, ...],
    $self->{layerWithName}      = {};     # <source> => { <key> => { value => ..., location => ... }, ... },
    $self->{currentLayerIndex}  = 0;      # ref to layerWithName
    $self->{cache}              = {};     # <key> => <layerIndex>
    $self->{observers}          = {};     # <key> => [ <observer>, ... ]

    $self->pushLayer( layerName => 'runtime' );

    return( $self );
    }

sub sharedConfig
    {
    my $class = shift;

    if( not $sharedConfig )
        {
        $sharedConfig = $class->new();
        }

    return $sharedConfig;
    }

sub pushLayer
    {
    my $self  = shift;
    my $param = { @_ };

    my $layerName = $param->{layerName};
    my $loader    = $param->{loader} || undef;

    if( exists $self->{layerWithName}{$layerName} )
        {
        # throw duplicate config layer exception
        }

    my $newLayer = {
        name     => $layerName,
        loader   => $loader,
        setting  => {},         # key -> value
        location => {},         # key -> location
    };

    push @{$self->{layerStack}}, $newLayer;

    my $layerIndex = $#{$self->{layerStack}};

    $self->{layerIndexForName}{$layerName}  = $layerIndex;
    $self->{currentLayerIndex}              = $layerIndex;

    return;
    }

sub setCurrentLayer
    {
    my $self  = shift;
    my $param = { @_ };

    my $layerIndex = 0;

    if( $param->{layerName} )
        {
        $layerIndex = $self->{layerIndexForName}{ $param->{layerName} };
        if( not defined $layerIndex )
            {
            # TODO: Riehm [2011-05-16] throw an undefined layer exception
            }
        }

    $self->{currentLayerIndex} = $layerIndex;

    return;
    }

sub addObserverForKey
    {
    my $self     = shift;
    my $key      = shift;
    my $observer = shift;

    return unless $observer;

    $self->{observersForKey}{$key}{$observer} = $observer;
    }

sub removeObserverForKey
    {
    my $self     = shift;
    my $key      = shift;
    my $observer = shift;

    delete $self->{observersForKey}{$key}{$observer};

    return;
    }

sub set
    {
    my $self     = shift;
    my $key      = shift;
    my $value    = shift  || undef;
    my $location = shift  || (caller(0))[3];

    my $layerIndex = $self->{currentLayerIndex};
    $self->[$layerIndex]{setting}{$key}  = $value;
    $self->[$layerIndex]{location}{$key} = $location;

    # TODO: detect changed value and notify observers
    if( $self->{cache}{$key} >= $layerIndex )
        {
        $self->notifyThatValueDidChange( $key );
        }

    return;
    }

sub exists
    {
    my $self = shift;
    my $key  = shift;
    return exists $self->{currentLayer}{setting}{$key};
    }

sub valueOf
    {
    my $self = shift;
    my $key  = shift;
    return $self->{currentLayer}{setting}{$key};
    }

sub locationOf
    {
    my $self = shift;
    my $key  = shift;

    return $self->{locationOf}{$key};
    }

sub dump
    {
    my $self = shift;

    my @return = ();

    foreach my $key ( sort keys %{$self->{cache}} )
        {
        push( @return,
                sprintf( "%-*s %-*s: %s\n",
                    $self->{locationWidth},
                    $self->locationOf( $key ),
                    $self->{keyWidth},
                    $key,
                    $self->valueOf( $key ),
                    ),
            );
        }

    return join( '', map { "$_\n" } @return );
    }

sub notifyThatValueDidChange
    {
    my $self = shift;
    my $key  = shift;

    foreach my $observer ( values %{$self->{observersForKey}{$key}} )
        {
        $observer->configurationValueDidChange( $key );
        }

    return;
    }

1;
