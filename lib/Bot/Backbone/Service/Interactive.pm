package Bot::Backbone::Service::Interactive;
use Bot::Backbone::Service;

with qw(
    Bot::Backbone::Service::Role::Service
    Bot::Backbone::Service::Role::ChatConsumer
);

#use AnyEvent::Subprocess;
use AnyEvent::Run;
use Scalar::Util qw( reftype );

service_dispatcher as {
    not_command run_this_method 'interactive_command';
};

has handle => (
    is          => 'rw',
    isa         => 'AnyEvent::Run',
    lazy_build  => 1,
    clearer     => 'clear_handle',
);

sub _build_handle {
    my $self = shift;

    my $handle = AnyEvent::Run->new(
        cmd => $self->run_command,
        on_read => sub {
            my ($handle) = @_;

            my $input = $handle->{rbuf};
            $handle->{rbuf} = '';

            if ($self->has_input_cleaner) {
                local $_  = $input;
                $input = $self->input_cleaner->($input);
            }

            $self->send_message({ text => $input });
        },
        on_error => sub {
            $self->clear_handle;
        },
    );

    return $handle;
}

#has job => (
#    is          => 'rw',
#    isa         => 'AnyEvent::Subprocess',
#    lazy_build  => 1,
#    clearer     => 'clear_job',
#);
#
#sub _build_job {
#    my $self = shift;
#
#    my $job = AnyEvent::Subprocess->new(
#        delegates     => ['StandardHandles'],
#        on_completion => sub { 
#            my $job = shift;
#            die "Interactive run [", join(' ', @{ $self->run_command }), '] FAIL: bad exit status' 
#                unless $job->is_success;
#        },
#        code          => sub {
#            my %args = %{$_[0]};
#            exec(@{ $self->run_command });
#        },
#    );
#
#    $job->run;
#
#    for my $delegate_name (qw( stdout stderr )) {
#        my $delegate = $job->delegate($delegate_name);
#
#        $delegate->handle->on_read(sub {
#            my ($handle) = @_;
#            $self->send_message({ text => $handle->{rbuf} });
#            $handle->{rbuf} = '';
#        });
#    }
#
#    return $job;
#}

has interactive_prefix => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    default     => '#',
);

has run_command => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
);

has input_cleaner => (
    is          => 'ro',
    isa         => 'CodeRef',
    predicate   => 'has_input_cleaner',
);

sub interactive_command {
    my ($self, $message) = @_;
    my $text = $message->text;
    
    my $p = $self->interactive_prefix;

    if ($text =~ /^$p(.*)/) {
        my $send_text = $1;
        $message->add_flag('command');
#        $self->job->delegate('stdin')->handle->push_write($send_text."\n");
        $self->handle->push_write($send_text."\n");
    }
}

sub initialize { }

sub receive_message { }

1;
