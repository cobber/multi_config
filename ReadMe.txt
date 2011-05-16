Multi Layered Configuration
===========================

Yhis perl module is intended to help manage complex configuration situations.

Existing modules attempt to solve this problem by dictating the kind of
configuration files can be imported, and their locations.

This module works a little bit differently, in that it can define any number of
configuration "layers", which in practice, overlap each other so that
configurations set in "higher" levels obscure default values defined by lower
levels.

This provides te flixibility to allow simple or complex configuration of
anything from cli scripts to web applications.

The interface is fully object oriented - and may soon be moosified ;-)

If you're thinking of forking this project, please let me know. It's based on
"my real world" experience, which may of course differ wildly from yours ;-)

Stephen Riehm
2011-05-17
