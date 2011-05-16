package Multi::Config::Getopt;

use strict;
use warnings;
use YAML;
use GetOpt::Long;
use Multi::Config;

## @fn      new( %param )
#  @brief   create a new GetOpt::Long configuration loader
#  @detail  this method just creates a new loader object - use load() to
#           actually parse the command line
#  @param   {throwErrors}   configure GetOpt::Long to throw an exception
#                           whenever an error is encountered.
#                           This is 'on' by default, but should be turned off
#                           if there is a difference between preliminary /
#                           startup options and 'command' options
#  @param   {getOptSpec}    an array of options to be captured by GetOpt::Long
#  @return  <none>
sub new {
    my $class = shift;
    my $param = { @_ };

    my $self  = bless {}, $class;

    $self->{getOptSpec}    = $param->{getOptSpec}
                            || [
                                # TODO: Riehm [2011-05-16] merge with options provided by the caller
                                'showconfiguration',
                                'debug',
                                'help',
                                'verbose',
                                'version',
                                ];
    $self->{throwErrors}   = $param{throwErrors};
    $self->{parsedOptions} = {};

    return( $self );
    }

## @fn      load( %param )
#  @brief   load the configuration settings for this layer
#  @param   {GetOptSpec}    GetOpt::Long option specification
#  @return  <none>
sub load {
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
