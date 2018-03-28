package SandboxManager::Controller::Sandboxes;
use Mojo::Base 'Mojolicious::Controller';

sub list {
    my $self = shift;

    my $results   = $self->sqlite->db->query("SELECT * FROM sandboxes");
    my $sandboxes = $results->hashes;

    $self->render(
        title     => "Koha Sandbox Manager",
        sandboxes => $sandboxes,
    );
}

sub create_form {
    my $self = shift;

    $self->render(
        title     => "Koha Sandbox Manager - Create Sandbox",
    );
}

1;
