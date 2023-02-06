package threadreadermirror::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Log;
use JSON;
use Email::Valid;
use Math::Round qw(nearest);
use Data::Printer;
use FindBin;
use lib "$FindBin::Bin/../lib";
use time;
use json_parsing;

sub index {
    my $self = shift;

    my $threadId = $self->param('threadId');
    my %threads  = ();

    if (!$threadId) {

        # Loading the list of known threads.
        my $json = json_parsing::json_from_file($threadsFile);
        %threads = %$json;
    }

    $self->render(
        threadId => $threadId,
        threads  => \%threads
    );
}

1;