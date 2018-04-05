package SandboxManager::Controller::Sandboxes;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::Transaction::WebSocket;

use DateTime;
use File::Slurp qw( read_file );
use Try::Tiny;

sub list {
    my $self = shift;

    my $results   = $self->sqlite->db->query("SELECT * FROM sandboxes");
    my $sandboxes = $results->hashes;

    $self->render(
        title           => "Koha Sandbox Manager",
        sandbox_created => $self->param('scs'),
        sandboxes       => $sandboxes,
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
        status      => 'pending',
    };

    if ( keys %$errors ) {
        $self->render(
            errors   => $errors,
            params   => $params,
            title    => "Koha Sandbox Manager",
            template => 'sandboxes/create_form',
        );

    }
    else {
        $self->sqlite->db->insert( 'sandboxes', $params );
        $self->stash( { sandbox => $params } );
        $self->render( title => "Koha Sandbox Manager - Provision Sandbox" );
    }
}

sub provision {
    my $self = shift;
    my $name = $self->stash('name');

    #FIXME: Where should this live?
    $self->minion->add_task(
        "provision" => sub {
            my ( $job, $name ) = @_;

            $job->on(
                finished => sub {
                    my ( $job, $result ) = @_;

                    $self->sqlite->db->update(
                        'sandboxes',
                        { status => 'provisioned' },
                        { name   => $name }
                    );

                }
            );

            warn "EXECING";
        qx( ansible-playbook -i 'localhost,' -c local --extra-vars 'instance_name=$name' /home/kyle/bws-development-ansible/create-sandbox-instance.yml >>/tmp/$name.log 2>&1 );
            warn "DONE EXECING";

        }
    );

    $self->minion->enqueue( provision => $name );
#    $self->minion->perform_jobs;

    $self->render( json => { provisioning => 1 } );
}

sub provision_log {
    my $self = shift;
    my $name = $self->stash('name');

    my $text;
    try {
        $text = read_file("/tmp/$name.log");
    }
    catch {
        $text = $_;
    };

    $self->render( json => { text => $text } );
}
1;
