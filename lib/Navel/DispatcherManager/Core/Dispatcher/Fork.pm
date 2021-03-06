# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-dispatcher-manager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::DispatcherManager::Core::Dispatcher::Fork 0.1;

use Navel::Base;

use parent 'Navel::Base::WorkerManager::Core::Worker::Fork';

#-> methods

sub wrapped_code {
    my $self = shift;

    'package ' . $self->{worker_package} . " 0.1;

BEGIN {
    open STDIN, '</dev/null';
    open STDOUT, '>/dev/null';
    open STDERR, '>&STDOUT';
}" . '

use Navel::Base;

use URI;
use AnyEvent::HTTP;

use Navel::Queue;
use Navel::Notification;
use Navel::Utils ' . "'json_constructor'" . ';

BEGIN {
    require ' . $self->{definition}->{consumer_backend} . ';
    require ' . $self->{definition}->{publisher_backend} . ';
}

my ($initialized, $exiting, %filler);

my $json_constructor = json_constructor;

*log = \&AnyEvent::Fork::RPC::event;

sub consumer_queue {
    state $queue = Navel::Queue->new(
        size => ' . $self->{definition}->{consumer_queue_size} . '
    );
}

sub publisher_queue {
    state $queue = Navel::Queue->new(
        size => ' . $self->{definition}->{publisher_queue_size} . '
    );
}

sub ' . $self->{worker_rpc_method} . ' {
    my ($done, $backend, $sub, $meta, $dispatcher) = @_;

    if ($exiting) {
        $done->(0, ' . "'currently exiting the worker'" . ');

        return;
    }

    unless ($initialized) {
        $initialized = 1;

        *meta = sub {
            $meta;
        };

        *dispatcher = sub {
            $dispatcher;
        };

        ' . $self->{definition}->{consumer_backend} . '::init;
        ' . $self->{definition}->{publisher_backend} . '::init;

        $filler{uri} = URI->new;

        $filler{uri}->scheme(' . "'http' . (dispatcher()->{filler_tls} ? 's' : ''));" . '
        $filler{uri}->userinfo(' . "dispatcher()->{filler_user} . (defined dispatcher()->{filler_password} ? ':' . dispatcher()->{filler_password} : ''))" . ' if defined dispatcher()->{filler_user};
        $filler{uri}->host(dispatcher()->{filler_host});
        $filler{uri}->port(dispatcher()->{filler_port});
        $filler{uri}->path(dispatcher()->{filler_basepath});

        $filler{as_string} = $filler{uri}->as_string;
    }

    unless (defined $backend) {
        if ($sub eq ' . "'consumer_queue'" . ') {
            $done->(1, scalar @{consumer_queue->{items}});
        } elsif ($sub eq ' . "'consumer_dequeue'" . ') {
            $done->(1, scalar consumer_queue->dequeue);
        } elsif ($sub eq ' . "'publisher_queue'" . ') {
            $done->(1, scalar @{publisher_queue->{items}});
        } elsif ($sub eq ' . "'publisher_dequeue'" . ') {
            $done->(1, scalar publisher_queue->dequeue);
        } elsif ($sub eq ' . "'filler_active_connections'" . ') {
            $done->(1, $AnyEvent::HTTP::ACTIVE);
        } elsif ($sub eq ' . "'batch'" . ') {
            my $events = consumer_queue->dequeue;

            if (@{$events}) {
                my $serialized_events = eval {
                    $json_constructor->encode($events)
                };

                unless ($@) {
                    http_post(
                        $filler{as_string},
                        $serialized_events,
                        tls_ctx => dispatcher()->{filler_tls_ctx},
                        sub {
                            my ($body, $headers) = @_;

                            my $requeue_on_error = sub {
                                my $message = shift;

                                my $size_left = consumer_queue->size_left;

                                consumer_queue->enqueue($size_left < 0 ? @{$events} : splice @{$events}, - ($size_left > @{$events} ? @{$events} : $size_left));

                                ' . $self->{worker_package} . "::log(
                                    [
                                        'err',
                                        \$message . '.'" . '
                                    ]
                                );
                            };

                            if (substr($headers->{Status}, 0, 1) eq ' . "'2'" . ') {
                                my $response = eval {
                                    $json_constructor->decode($body);
                                };

                                if  ( ! $@ && ref $response eq ' . "'HASH'" . ' && ref $response->{notifications} eq ' . "'ARRAY'" . ' && ref $response->{errors} eq ' . "'ARRAY'" . ') {
                                    my $errors = 0;

                                    for (@{$response->{notifications}}) {
                                        my $notification = eval {
                                            Navel::Notification->new(%{$_})->serialize;
                                        };

                                        unless ($@) {
                                            publisher_queue->enqueue($notification);
                                        } else {
                                            $errors++;
                                        }
                                    }

                                    ' . $self->{worker_package} . "::log(
                                        [
                                            'err',
                                            \$errors . ' notification(s) could not be created.'" . '
                                        ]
                                    ) if $errors;

                                    ' . $self->{worker_package} . "::log(
                                        [
                                            'err',
                                            'the filler returned an error: '" . ' . $_
                                        ]
                                    ) for @{$response->{errors}};
                                } else {
                                    $requeue_on_error->(' . "'the filler returned an unexpected response'" . ');
                                }
                            } else {
                                $requeue_on_error->(' . "'the filler returned HTTP '" . ' . $headers->{Status});
                            }

                            $done->(1);
                        }
                    );
                } else {
                    ' . $self->{worker_package} . "::log(
                        [
                            'err'" . ',
                            $@
                        ]
                    );

                    $done->(1);
                }
            } else {
                ' . $self->{worker_package} . "::log(
                    [
                        'debug',
                        'no event to batch.'" . '
                    ]
                );

                $done->(1);
            }
        } else {
            $exiting = 1;

            $done->(1);

            exit;
        }

        return;
    }

    if (my $sub_ref = $backend->can($sub)) {
        $sub_ref->($done);
    } else {
        $done->(0, ' . "\$backend . '::' . \$sub . ' is not declared'" . ');
    }

    return;
}

1;';
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::DispatcherManager::Core::Dispatcher::Fork

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-dispatcher-manager is licensed under the Apache License, Version 2.0

=cut
