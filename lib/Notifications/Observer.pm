package Notifications::Observer;

use strict;
use warnings;

use Notifications;

sub new {
    my $class = shift;

    my $self  = bless {}, $class;

    return $self;
}

sub start { Notifications->add_observer(    shift ); }
sub stop  { Notifications->remove_observer( shift ); }

sub accept_notification
    {
    my $self         = shift;
    my $notification = shift;

    require POSIX;
    printf( "%s %s %s(): %s\n%s",
           POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime( ($notification->timestamp())[0] ) ), 
           uc $notification->event(),
           $notification->function(),
           $notification->message(),
           $notification->dumped_user_data(),
        );
    }

1;

# TODO: Riehm [2011-02-15] write some documentation for this thing!
