package Notifications::Notification;

use strict;
use warnings;

use Time::HiRes qw( gettimeofday );
use YAML;

sub new
    {
    my $class = shift;
    my %param = @_;

    my $self = bless {}, $class;

    $self->{event}              = $param{event};
    $self->{message}            = $param{message}             || '-';
    $self->{source_package}     = $param{source_package};
    $self->{source_function}    = $param{source_function};
    $self->{source_file}        = $param{source_file};
    $self->{source_line_number} = $param{source_line_number};
    $self->{timestamp}          = $param{timestamp}           || [ gettimeofday() ];
    $self->{is_being_skipped}   = $param{is_being_skipped}    || 0;
    $self->{user_data}          = $param{user_data}           || {};
    $self->{dumped_user_data}   = undef;

    return $self;
    }

sub skip
    {
    my $self = shift;
    $self->{is_being_skipped} = 1;
    return;
    }

sub message          { return shift->{'message'};            }
sub event            { return shift->{'event'};              }
sub package          { return shift->{'source_package'};     }
sub file             { return shift->{'source_file'};        }
sub line             { return shift->{'source_line_number'}; }
sub function         { return shift->{'source_function'};    }
sub timestamp        { return shift->{'timestamp'};          }
sub is_being_skipped { return shift->{'is_being_skipped'};   }

sub user_data
    {
    my $self = shift;
    return $self->{'user_data'};
    }

## @fn      dumped_user_data()
#  @brief   returns the user_data as a single string (using YAML::Dump)
#  @param   <none>
#  @return  a string representation of the additional user data.
#           a zero-length string will be returned if there is no additional data
sub dumped_user_data
    {
    my $self = shift;

    if( not defined $self->{'dumped_user_data'} )
        {
        if( $self->{user_data} and scalar keys %{$self->{user_data}} )
            {
            $self->{'dumped_user_data'} = Dump( $self->{user_data} ) . "--\n";
            }
        else
            {
            $self->{'dumped_user_data'} = '';
            }
        }

    return $self->{'dumped_user_data'};
    }


1;

# TODO: Riehm [2011-02-15] write some documentation for this thing!
