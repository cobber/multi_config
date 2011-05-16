package UseCase::Config;

use strict;
use warnings;
use YAML;

use File::Spec;
use Multi::Config;
use Multi::Config::Getopts;
# use Multi::Config::File::Yaml;
# use Multi::Config::File::Ini;

sub new
    {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    return( $self );
    }

sub run
    {
    my $self = shift;

    $self->{config} = Multi::Config->sharedConfig();

    $self->{config}->pushLayer(
        layerName => 'CLI',
        loader    => Multi::Config::Getopts->new(),
        );

#     $self->{config}->pushLayer(
#         layerName => 'User Config',
#         loader    => Multi::Config::File::Yaml->new(
#             filename => catfile( $HOME, '.config_app', 'config.yaml' ),
#             ),
#         );
#
#     $self->{config}->pushLayer(
#         layerName => 'Factory Defaults',
#         loader  => Multi::Config::File::Ini->new(
#             filename => catfile( $RealBin, 'config', 'defaults.ini' ),
#             ),
#         );

    $self->{config}->setCurrentLayer( layerName => 'runtime' );
    }

1;
