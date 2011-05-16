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
#               $config->setValueOf( <key> => <value>, <location> );
#
#       After setup has been completed, the all changes to the configuration
#       take place on the top-level only, the 'runtime' level
#

use strict;
use warnings;

use Notifications qw( debug verbose );

use Exception::Class (
    'DuplicateConfigurationLayerException',
    'MissingConfigurationLayer',
    );

my $sharedConfig = undef;

## @fn      sharedConfig()
#  @brief   returns a shared configuration object
#  @param   <none>
#  @return  a reference to the common configuration object
sub sharedConfig {
    my $class = shift;

    if( not $sharedConfig ) {
        $sharedConfig = $class->newConfig();
    }

    return $sharedConfig;
}


## @fn      newConfig()
#  @brief   create a new configuration object
#  @warning do not use this method for normal operation - use sharedConfig() instead
#  @param   <none>
#  @return  a new configuration object
sub newConfig {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    $self->{layerStack}         = [];     # [ { <key> => { value => ..., location => ... } }, ...],
    $self->{currentLayerIndex}  = 0;      # index into layerStack
    $self->{layerIndexForName}  = {};     # <source> => { <key> => { value => ..., location => ... }, ... },
    $self->{cacheIndex}         = {};     # <key> => <layerIndex>
    $self->{cacheValue}         = {};     # <key> => <value>
    $self->{observersForKey}    = {};     # <key> => [ <observer>, ... ]
    $self->{changedSettings}    = {};     # <key> => <old-value>

    $self->pushLayer( layerName => 'runtime' );

    return( $self );
}

## @fn      pushLayer( %param )
#  @brief   create a new configuration layer
#  @warning configuration layers must be created in order of precedence - ie:
#           layer 0 is by default the runtime configuration and is always
#           processed first
#  @param   {layerName} the name of the new layer - layers must have unique
#                       names to enable identification
#  @param   {loader}    an object which can be used to load the configuration
#                       layer from it's source.
#                       Typical examples include the command line (GetOpt::Long),
#                       text files (.ini, .xml, .yaml, .json etc.) or database.
#  @return  <none>
#  @throws  DuplicateConfigurationLayerException    if the layer to add already exists
sub pushLayer {
    my $self  = shift;
    my $param = { @_ };

    my $layerName = $param->{layerName};
    my $loader    = $param->{loader} || undef;

    if( exists $self->{layerIndexForName}{$layerName} ) {
        DuplicateConfigurationLayerException->throw(
            message => "Duplicate configuration layer $layerName",
        );
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

    if( $loader )
        {
        $loader->load();
        }

    return;
}

## @fn      setCurrentLayer( %param )
#  @brief   set the current layer for all configuration settings
#  @param   {layerIndex}    the index of the layer to be used when setting
#                           configuration values
#  @param   {layerName}     the name of the layer to be used when setting
#                           configuration values
#  @return  <none>
#  @throws  MissingConfigurationLayer   if the named layer has not been defined
sub setCurrentLayer {
    my $self  = shift;
    my $param = { @_ };

    my $layerIndex = $param->{layerIndex} || 0;

    if( $param->{layerName} ) {
        $layerIndex = $self->{layerIndexForName}{ $param->{layerName} };
        if( not defined $layerIndex ) {
            MissingConfigurationLayer->throw(
                message => "Missing configuration layer: $param->{layerName}",
            );
        }
    }

    $self->{currentLayerIndex} = $layerIndex;

    return;
}

## @fn      resetLayer( %param )
#  @brief   reset the contents of a configuration layer
#           This should be used by configuration loaders before loading their configuration
#  @details When a layer is rest, any values that were cached from it are reset
#           - allowing lower-priority values to "show-through"
#  @note    observers are notified of changes to values
#           if a value is no longer defined - the observers are notified,
#           however, their observation status is RETAINED!
#  @param   {layerIndex}    the index of the layer to be reset
#  @param   {layerName}     the name of the layer to be reset
#                           by default, the current layer is reset
#  @return  <none>
sub resetLayer {
    my $self  = shift;
    my $param = { @_ };

    # determine which layer to reset
    my $layerIndex = $param->{layerIndex} || $self->{currentLayerIndex};

    if( $param->{layerName} ) {
        $layerIndex = $self->{layerIndexForName}{ $param->{layerName} };
    }

    # ensure that no cached values refer to this layer any more
    foreach my $key ( keys %{$self->{layerStack}[$layerIndex]{setting}} ) {

        # values which were specified by other layers are left untouched
        next if $self->{cacheIndex}{$key} != $layerIndex;

        # remember the old value so that we don't notify observers if the value
        # doesn't actually change
        my $oldValue = $self->{cacheValue}{$key};
        my $newValue = undef;

        # look for a lower-priority definition of this key's value
        my $tmpIndex = $layerIndex;
        while( my $layer = $self->{layerStack}[++$tmpIndex] ) {

            # skip levels which don't define a value for this key
            next unless exists $layer->{setting}{$key};

            $newValue = $layer->{setting}{$key};
            $self->{cacheIndex}{$key} = $tmpIndex;
            $self->{cacheValue}{$key} = $newValue;

            # we have a new value for this key - stop looking
            last;
        }

        # no definition for this key any more? remove it from the cache
        if( not $self->{layerStack}[$tmpIndex] ) {
            delete $self->{cacheIndex}{$key};
            delete $self->{cacheValue}{$key};
        }

#         printf( "reset %s from %s to %s\n",
#                $key,
#                $oldValue // '<undef>',
#                $newValue // '<undef>',
#             );

        # skip to next key if the old and new values were both undefined
        next    if not ( defined $oldValue or defined $newValue );

        # if either of the old and new values are undefined, or they are
        # otherwise different, then announce they change in value
        if(     ( defined $oldValue xor defined $newValue )
            or  ( $oldValue ne $newValue )
            ) {
            $self->announceThatConfigurationValueDidChange(
                settingName => $key,
                oldValue    => $oldValue,
                newValue    => $newValue,
            );
        }
    }

    # we've cleaned up the cache - now kill the old values and locations from
    # this layer completely
    $self->{layerStack}[$layerIndex]{setting}  = {};
    $self->{layerStack}[$layerIndex]{location} = {};

    return;
}

## @fn      addObserverForKey( $key => $object )
#  @brief   register an object to be notified when the value of a configuration
#           paramater changes
#  @details the object's ->configurationValueDidChange( $key ) method will be
#           called with the name of the changed configuration setting whenever
#           the value of the setting has been changed
#  @param   $key        the name of a configuration parameter to be observed
#  @param   $object     a reference to an object with a
#                       configurationValueDidChange() method to be notified
#                       whenever the configuration of $key changes
sub addObserverForKey {
    my $self     = shift;
    my $key      = shift;
    my $observer = shift;

    return unless $observer;
    return unless $observer->can( 'configurationValueDidChange' );

    # TODO: Riehm 2011-05-16 use weak links?
    $self->{observersForKey}{$key}{$observer} = $observer;

    return;
}

## @fn      removeObserverForKey( $key => $observer )
#  @brief   prevent an object from being notified when a configuration value changes
#  @param   $key        the name of a configuration parameter being observed
#  @param   $object     a reference to an object which has been observing the value
#                       no action is taken if the object is not observing the value
#                       if no object is specified, then all observers of the
#                       value will be removed
#  @return  <none>
sub removeObserverForKey {
    my $self     = shift;
    my $key      = shift;
    my $observer = shift || undef;

    if( $observer ) {
        delete $self->{observersForKey}{$key}{$observer};
    }
    else {
        delete $self->{observersForKey}{$key};
    }

    return;
}

## @fn      stopNotifications()
#  @brief   temporarily stop sending notifications for changed values... useful if doing bulk updates
#  @param   <none>
#  @return  <none>
sub stopNotifications {
    my $self  = shift;

    $self->{sendNotifications} = 0;

    return;
}

## @fn      startNotifications( %param )
#  @brief   allow notifications to be sent again
#  @param   {sendBacklog}   send change notifications that would have been sent
#                           while notifications were turned off.
#                           By default, the backlog of change notifications is NOT sent
#  @return  <none>
sub startNotifications {
    my $self  = shift;
    my $param = { @_ };

    $self->{sendNotifications} = 1;

    if( $param->{sendBacklog} ) {
        foreach my $key ( sort keys %{$self->{changedSettings}} ) {
            $self->announceThatConfigurationValueDidChange(
                settingName => $key,
                oldValue    => $self->{changedSettings}{$key}{old},
                newValue    => $self->{changedSettings}{$key}{new},
            );
        }
    }

    return;
}

## @fn      announceThatConfigurationValueDidChange( %param )
#  @brief   send notifications indicating that a configuration value has changed
#  @param   {settingName}   the name of a configuration parameter that has been changed
#  @param   {oldValue}      the old value of the configuration setting
#  @param   {newValue}      the new value of the configuration setting
#  @return  <none>
sub announceThatConfigurationValueDidChange {
    my $self  = shift;
    my $param = { @_ };

    my $key = $param->{settingName};
    foreach my $observer ( values %{$self->{observersForKey}{$key}} ) {
        $observer->configurationValueDidChange(
            settingName => $key,
            oldValue    => $param->{oldValue},
            newValue    => $param->{newValue},
        );
    }

    return;
}

## @fn      setValueOf( $key => $value, $location )
#  @brief   set the value of a configuration setting in the current configuration level
#  @param   $key        the name of the configuration setting
#  @param   $value      the new value of the setting
#  @param   $location   (optional) description of where the setting came from.
#                       When set by configuration loaders, this should be the
#                       name and line number of the configuration file.
#                       Other loaders should provide a suitable location description.
sub setValueOf {
    my $self     = shift;
    my $key      = shift;
    my $newValue = shift  || undef;
    my $location = shift  || sprintf "%s line %d", (caller(0))[0,2];

    my $layerIndex = $self->{currentLayerIndex};

    $self->{layerStack}[$layerIndex]{setting}{$key}  = $newValue;
    $self->{layerStack}[$layerIndex]{location}{$key} = $location;

    # just return if the value is defined by a higher-priority layer
    return if exists  $self->{cacheIndex}{$key} and $self->{cacheIndex}{$key} < $layerIndex;

    # this layer now defines this value
    $self->{cacheIndex}{$key} = $layerIndex;

    # only send notifications to observers if the value actually changed
    my $oldValue = $self->{cacheValue}{$key};
    return if not ( defined $oldValue or defined $newValue );
    return if   defined $oldValue and defined $newValue
            and $oldValue eq $newValue;

    $self->{cacheValue}{$key} = $newValue;

    $self->announceThatConfigurationValueDidChange(
        settingName => $key,
        oldValue    => $oldValue,
        newValue    => $newValue,
    );

    return;
}

## @fn      exists( $key )
#  @brief   returns true if the key is defined by at least one layer
#  @param   $key    the name of the configuration setting to check
#  @return  1 if the named setting exists, 0 otherwise
sub exists {
    my $self = shift;
    my $key  = shift;
    return exists $self->{cacheValue}{$key};
}

## @fn      valueOf( $key )
#  @brief   returns the configuration value defined for a particular setting
#  @param   $key    the name of the setting
#  @return  the value of the setting - may be undef!
sub valueOf {
    my $self = shift;
    my $key  = shift;

    return $self->{cacheValue}{$key};
}

## @fn      layerNameOf( $key )
#  @brief   returns the name of the layer which defined the current value of a
#           configuration setting
#  @seeAlso locationOf
#  @param   $key    the name of the setting
#  @return  the name of a layer
sub layerNameOf {
    my $self = shift;
    my $key  = shift;

    my $layerIndex = $self->{cacheIndex}{$key};

    return $self->{layerStack}[$layerIndex]{name};
}

## @fn      locationOf( $key )
#  @brief   returns the location which defined the current value of a setting
#  @seeAlso layerNameOf
#  @param   $key    the name of the setting
#  @return  the location where the setting was defined (relative to its layer)
sub locationOf {
    my $self = shift;
    my $key  = shift;

    my $layerIndex = $self->{cacheIndex}{$key};

    return $self->{layerStack}[$layerIndex]{location}{$key};
}

## @fn      settingNames()
#  @brief   returns a list of known configuration settings
#  @param   <none>
#  @return  a list of configuration setting names
sub settingNames {
    my $self  = shift;

    return sort keys %{$self->{cacheValue}};
}

## @fn      dump( %param )
#  @brief   create a string describing all known configuration settings
#  @param   {includeLocations}  include location information with each value
#  @return  a string representation of all of the settings
sub dump {
    my $self  = shift;
    my $param = { @_ };

    my $includeLocations = $param->{includeLocations} // 0; # is_verbose();

    my @settingLines     = ();

    foreach my $key ( $self->settingNames() ) {
        my $lineHash = {
            key   => $key,
            value => $self->valueOf( $key ),
        };
        if( $includeLocations ) {
            $lineHash->{layerName} = $self->layerNameOf( $key );
            $lineHash->{location}  = $self->locationOf(  $key );
        }
        push( @settingLines, $lineHash );
    }

    # TODO: Riehm 2011-05-16 replace with a common table formatting routine
    # determine the width of each 'column'
    my $width = {};
    foreach my $line ( @settingLines ) {
        foreach my $key ( keys %{$line} ) {

            my $length = length $line->{$key};

            next if ( $width->{$key} // 0 ) >= $length;

            $width->{$key} = $length;
        }
    }

    # determine the order in which the columns are to be
    my @fields;
    if( $includeLocations ) {
        push @fields, 'layerName';
        push @fields, 'location';
    }
    push @fields, 'key';
    push @fields, 'value';

    # create a common format for dumping the data, so that everything appears in neat columns
    my $format = join( ' ',
        map { sprintf( "%%-%ds", $width->{$_} || 0 ) }
        @fields
    ) . "\n";

    # return a single string with the formatted data
    return(
        join( '',
            map { sprintf $format, @{$_}{@fields} }
            @settingLines
        )
    );
}

1;
