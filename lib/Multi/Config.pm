package Multi::Config;

use strict;
use warnings;
use YAML;

my $sharedConfg = undef;

sub new
    {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    # TODO:
    #   enforce push-only for layers
    #   auto-select layer when pushed
    #   use stack depth index to track changes 'upwards' toward level 0 (runtime)

    $self->{loaderForLayer} = {};     # <source> => <loader>
    $self->{layerWithName}  = {};     # <source> => { <key> => { value => ..., location => ... } },
    $self->{layerStack}     = [];     # [ <source>, <source>, ... ]
    $self->{currentLayer}   = undef;  # ref to layerWithName
    $self->{cache}          = {};     # <key> => <source>
    $self->{observers}      = {};     # <key> => [ <observer>, ... ]

    return( $self );
    }

sub sharedConfg
    {
    my $class = shift;

    if( not $sharedConfg )
        {
        $sharedConfig = $class->new();
        }

    return $sharedConfig;
    }

sub pushLayer
    {
    my $self  = shift;
    my $param = { @_ };

    my $layerName = $param{layerName};
    my $loader    = $param{loader} || undef;

    if( exists $self->{layerWithName}{$layerName} )
        {
        # throw duplicate config layer exception
        }

    $self->{layerWithName}{$layerName}  = {};
    $self->{loaderForLayer}{$layerName} = $loader;
    push @{$self->{layerStack}}, $layerName;

    return;
    }

sub setCurrentLayer
    {
    my $self      = shift;
    my $layerName = shift;

    if( not exists $self->{layerWithName}{$layerName} )
        {
        # throw undefined layer exception
        }

    $self->{currentLayer} = $self->{layerWithName}{$layerName};

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

sub set
    {
    my $self     = shift;
    my $key      = shift;
    my $value    = shift  || undef;
    my $location = shift  || (caller(0))[3];

    $self->{currentLayer}{$key}{value}    = $value;
    $self->{currentLayer}{$key}{location} = $location;

    # TODO: detect changed value and notify observers
    }

sub valueOf
    {
    my $self = shift;
    my $key  = shift;

    return $self->{layerWithName}
    }

sub locationOf
    {
    my $self = shift;
    my $key  = shift;
    }

sub dump
    {
    my $self = shift;
    }

1;
