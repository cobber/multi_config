#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw( $RealBin );
use lib "$RealBin/../lib";

use Test::More;
use Test::Exception;
use YAML;   # TODO: Riehm 2011-05-16 remove me

BEGIN {
    use_ok( 'Multi::Config' );
}

my $configObserver = TestConfigWatcher->new();

my $shared_config = Multi::Config->sharedConfig();

ok( $shared_config, 'shared config should always be defined' );
isa_ok( $shared_config, 'Multi::Config', 'shared config should be an object of the right type' );

is_deeply( [ $shared_config->settingNames() ], [],  'no settings should be known at first' );
ok( ! $shared_config->exists( 'hello' ),        'specific names should also not exist' );

# try watching changes to 'foo' and see what happens
$shared_config->addObserverForKey( 'answer' => $configObserver );
$shared_config->addObserverForKey( 'foo'    => $configObserver );

# see if we can set a simple configuration value
$shared_config->setValueOf( 'hello'  => 'world' );
$shared_config->setValueOf( 'answer' => 42      );

is_deeply( [ $shared_config->settingNames() ], [ qw( answer hello ) ],  'our new settings should be visible' );
ok( $shared_config->exists(      'hello' ),             '"hello" should be a known configuration setting now'  );
is( $shared_config->valueOf(     'hello' ),    'world', 'simple configuration'                                 );
is( $shared_config->layerNameOf( 'hello' ),  'runtime', 'default layer is "runtime"'                           );
ok( $shared_config->exists(      'answer' ),            '"answer" should be a known configuration setting now' );
is( $shared_config->valueOf(     'answer' ),        42, 'simple configuration'                                 );
is( $shared_config->layerNameOf( 'answer' ), 'runtime', 'default layer is "runtime"'                           );

# see if we caught a notification for the new 'answer' value
is_deeply( [ $configObserver->changedSettings() ], [ qw( answer ) ],  'should have been notified about the "answer" setting' );
is_deeply( $configObserver->notificationForChangeToSetting( 'answer'),
    {
    settingName => 'answer',
    oldValue    => undef,
    newValue    => 42,
    },
    'expected "answer" notification',
);
# reset the caught notifications so that we can see what changes next
$configObserver->reset();

# try to add a new layer
$shared_config->pushLayer( layerName => 'test' );

is_deeply( [ $shared_config->settingNames() ], [ qw( answer hello ) ], 'our old settings should not have changed' );
ok( $shared_config->exists(      'answer' ),            '"answer" should continue to exist'                   );
is( $shared_config->valueOf(     'answer' ),        42, 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'answer' ), 'runtime', 'layer of existing configuration should be unchanged' );
ok( $shared_config->exists(      'hello' ),             '"hello" should continue to exist'                    );
is( $shared_config->valueOf(     'hello' ),    'world', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'hello' ),  'runtime', 'layer of existing configuration should be unchanged' );
ok( ! $shared_config->exists( 'foo' ),                  'unknown settings should not exist - yet'             );

# now add new values - 'hello' should have no effect, but 'foo' should appear
$shared_config->setValueOf( 'hello' => 'rubbish' );
$shared_config->setValueOf( 'foo'   => 'bar'     );

is_deeply( [ $shared_config->settingNames() ], [ qw( answer foo hello ) ], 'our new setting should appear in the overall list' );
ok( $shared_config->exists(      'answer' ),                    '"answer" should continue to exist'                   );
is( $shared_config->valueOf(     'answer' ),                42, 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'answer' ),         'runtime', 'layer of existing configuration should be unchanged' );
ok( $shared_config->exists(      'hello'  ),                    '"hello" should continue to exist'                  );
is( $shared_config->valueOf(     'hello'  ),           'world', 'existing configuration should be unchanged'        );
is( $shared_config->layerNameOf( 'hello'  ),         'runtime', 'layer of existing values should not change'        );
ok( $shared_config->exists(      'foo'    ),                    'our new setting should exist'                      );
is( $shared_config->valueOf(     'foo'    ),             'bar', 'existing configuration should be unchanged'        );
is( $shared_config->layerNameOf( 'foo'    ),            'test', 'layer of new setting should be the current layer'  );

# see if we caught a notification for the new 'foo' value
is_deeply( [ $configObserver->changedSettings() ], [ qw( foo ) ],  'should have been notified about the "foo" setting' );
is_deeply( $configObserver->notificationForChangeToSetting( 'answer' ),
    undef,
    'not expecting any change to "answer"',
);
is_deeply( $configObserver->notificationForChangeToSetting( 'foo' ),
    {
    settingName => 'foo',
    oldValue    => undef,
    newValue    => 'bar',
    },
    'expected "foo" notification',
);
$configObserver->reset();

# add a third layer and add some low level defaults
$shared_config->pushLayer( layerName => 'defaults' );

$shared_config->setValueOf( 'hello'  => 'boo' );
$shared_config->setValueOf( 'foo'    => 'why?' );
$shared_config->setValueOf( 'myname' => 'Joe' );

is_deeply( [ $shared_config->settingNames() ], [ qw( answer foo hello myname ) ], 'our new setting should appear in the overall list' );
ok( $shared_config->exists(      'answer' ),             '"answer" should continue to exist'                   );
is( $shared_config->valueOf(     'answer' ),         42, 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'answer' ),  'runtime', 'layer of existing configuration should be unchanged' );
ok( $shared_config->exists(      'hello'  ),             '"hello" should continue to exist'                    );
is( $shared_config->valueOf(     'hello'  ),    'world', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'hello'  ),  'runtime', 'layer of existing values should not change'          );
ok( $shared_config->exists(      'foo'    ),             'existing setting should continue to exist'           );
is( $shared_config->valueOf(     'foo'    ),      'bar', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'foo'    ),     'test', 'layer of new setting should be the current layer'    );
ok( $shared_config->exists(      'myname' ),             'our new setting should exist'                        );
is( $shared_config->valueOf(     'myname' ),      'Joe', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'myname' ), 'defaults', 'layer of new setting should be the current layer'    );

# "answer" and "foo" should not have triggered any new notifications
is_deeply( [ $configObserver->changedSettings() ], [],  'not expecting any notifications' );
is_deeply( $configObserver->notificationForChangeToSetting( 'answer' ),
    undef,
    'not expecting any change to "answer"',
);
is_deeply( $configObserver->notificationForChangeToSetting( 'foo' ),
    undef,
    'not expecting any change to "foo"',
);
$configObserver->reset();

# set the current layer to 'runtime' and change some settings
$shared_config->setCurrentLayer( layerName => 'runtime' );
$shared_config->setValueOf( 'foo' => 'baz' );

is_deeply( [ $shared_config->settingNames() ], [ qw( answer foo hello myname ) ], 'our new setting should appear in the overall list' );
ok( $shared_config->exists(      'answer' ),             '"answer" should continue to exist'                   );
is( $shared_config->valueOf(     'answer' ),         42, 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'answer' ),  'runtime', 'layer of existing configuration should be unchanged' );
ok( $shared_config->exists(      'hello'  ),             '"hello" should continue to exist'                    );
is( $shared_config->valueOf(     'hello'  ),    'world', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'hello'  ),  'runtime', 'layer of existing values should not change'          );
ok( $shared_config->exists(      'foo'    ),             'existing setting should continue to exist'           );
is( $shared_config->valueOf(     'foo'    ),      'baz', 'new value for foo'                                   );
is( $shared_config->layerNameOf( 'foo'    ),  'runtime', 'layer has been overridden'                           );
ok( $shared_config->exists(      'myname' ),             'our new setting should exist'                        );
is( $shared_config->valueOf(     'myname' ),      'Joe', 'existing configuration should be unchanged'          );
is( $shared_config->layerNameOf( 'myname' ), 'defaults', 'layer of new setting should be the current layer'    );

# "foo" should trigger a change notification now
is_deeply( [ $configObserver->changedSettings() ], [ qw( foo ) ],  '"foo" should have changed its value' );
is_deeply( $configObserver->notificationForChangeToSetting( 'answer' ),
    undef,
    'not expecting any change to "answer"',
);
is_deeply( $configObserver->notificationForChangeToSetting( 'foo' ),
    {
    settingName => 'foo',
    oldValue    => 'bar',
    newValue    => 'baz',
    },
    'should have got a notification that "foo" changed from "bar" to "baz"',
);
$configObserver->reset();

# reset the runtime values - now we should see default values popping through
$shared_config->resetLayer( layerName => 'runtime' );

is_deeply( [ $shared_config->settingNames() ], [ qw( foo hello myname ) ], 'our new setting should appear in the overall list' );
ok( ! $shared_config->exists(    'answer' ),             '"answer" should cease to exist - it was only defined at runtime' );
ok( $shared_config->exists(      'hello'  ),             '"hello" should continue to exist - defined by the "test" layer'  );
is( $shared_config->valueOf(     'hello'  ),  'rubbish', 'revert to lower-priority value'                                  );
is( $shared_config->layerNameOf( 'hello'  ),     'test', 'revert to lower layer'                                           );
ok( $shared_config->exists(      'foo'    ),             '"foo" should continue to exist - defined by the "test" layer'    );
is( $shared_config->valueOf(     'foo'    ),      'bar', 'revert to lower-priority value'                                  );
is( $shared_config->layerNameOf( 'foo'    ),     'test', 'revert to lower layer'                                           );
ok( $shared_config->exists(      'myname' ),             'existence of myname should be uneffected'                        );
is( $shared_config->valueOf(     'myname' ),      'Joe', 'value of myname should be uneffected'                            );
is( $shared_config->layerNameOf( 'myname' ), 'defaults', 'layer of myname should be uneffected'                            );

# "answer" should have ceased to exist and foo should have changed back to its default value - did we get these notifications?
is_deeply( [ $configObserver->changedSettings() ], [ qw( answer foo ) ],  'expected changes' );
is_deeply( $configObserver->notificationForChangeToSetting( 'answer' ),
    {
    settingName => 'answer',
    oldValue    => 42,
    newValue    => undef,
    },
    'should have got a notification to indicate that "answer" is now undefined',
);
is_deeply( $configObserver->notificationForChangeToSetting( 'foo' ),
    {
    settingName => 'foo',
    oldValue    => 'baz',
    newValue    => 'bar',
    },
    'should have got a notification that "foo" reverted from "baz" to "bar"',
);
$configObserver->reset();

# check that exceptions are thrown where expected
# Note: this syntax is perverted! No comma allowed after '}'
throws_ok { $shared_config->pushLayer(       layerName => 'test'    ) } 'DuplicateConfigurationLayerException', 'duplicate layers are not allowed'    ;
throws_ok { $shared_config->setCurrentLayer( layerName => 'unknown' ) } 'MissingConfigurationLayer',            'not allowed to select unknown layers';

# $shared_config->setValueOf( 'things' => 'world' );
# $shared_config->setValueOf( 'foo' => 'world' );
# $shared_config->setValueOf( 'blah' => 'world' );
# $shared_config->setValueOf( 'wollop' => 'world' );
# $shared_config->setValueOf( 'what the hell did you go and do that for?' => 'world' );

# diag( Dump( $shared_config ) );
# diag( $shared_config->dump() );

done_testing();
exit 0;

package TestConfigWatcher;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->{changed} = {};

    return $self;
}

# catch notifications from settings object
sub configurationValueDidChange {
    my $self  = shift;
    my $param = { @_ };

    $self->{changed}{$param->{settingName}} = $param;
}

# track changes
sub changedSettings {
    my $self = shift;
    return sort keys %{$self->{changed}};
}

sub notificationForChangeToSetting {
    my $self = shift;
    my $key  = shift;
    return $self->{changed}{$key};
}

sub reset {
    my $self = shift;
    $self->{changed} = {};
    return;
}

1;
