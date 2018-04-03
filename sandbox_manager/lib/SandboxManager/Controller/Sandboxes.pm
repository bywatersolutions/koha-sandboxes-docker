package SandboxManager::Controller::Sandboxes;
use Mojo::Base 'Mojolicious::Controller';

use DateTime;

sub list {
    my $self = shift;

    my $results   = $self->sqlite->db->query("SELECT * FROM sandboxes");
    my $sandboxes = $results->hashes;

    $self->render(
        title     => "Koha Sandbox Manager",
        sandbox_created => $self->param('scs'),
        sandboxes => $sandboxes,
    );
}

sub create_form {
    my $self = shift;

    $self->render( title => "Koha Sandbox Manager - Create Sandbox", );
}

sub create_submit {
    my $self = shift;

    my $name        = $self->param('name');
    my $description = $self->param('description');
    my $notes       = $self->param('notes');
    my $user        = $self->param('user');
    my $password    = $self->param('password');

    my $errors = {};
    $errors->{name_required} = 1 unless $name;
    $errors->{user_required} = 1 unless $user;
    $errors->{name_taken}    = 1
      if $self->sqlite->db->query(
        'SELECT COUNT(*) AS count FROM sandboxes WHERE name = ?', $name )
      ->hash->{count} > 0;

    my $params = {
        name        => $name,
        description => $description,
        notes       => $notes,
        user        => $user,
        password    => $password,
        created_on  => DateTime->now()->datetime(q{ }),
    };

    if ( keys %$errors ) {
        $self->render(
            errors => $errors,
            params => $params,

            title => "Koha Sandbox Manager",

            template => 'sandboxes/create_form',
        );

    }
    else {
        if ( my $id = $self->sqlite->db->insert( 'sandboxes', $params )->last_insert_id ) {
            warn "PWD: " . qx( pwd );
            my $output = qx( ansible-playbook -i 'localhost,' -c local --extra-vars 'instance_name=$name' /home/kyle/bws-development-ansible/create-sandbox-instance.yml );
            warn "OUTPUT: $output";
        }

        $self->stash( { sandbox_created => 'success' } );
        $self->redirect_to('/?scs=1');
    }
}

1;
