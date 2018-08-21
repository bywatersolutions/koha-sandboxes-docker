package SandboxManager::Controller::Sandboxes;

use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use File::Slurp;
use YAML qw{ LoadFile DumpFile };

sub list {
    my $self = shift;

    my @sandboxes;

    my $dir = q{/sandboxes/configs/};
    opendir(DIR, $dir);
    while (my $file = readdir(DIR)) {
        next unless (-f "$dir/$file");
        next unless ($file =~ m/\.yml$/);

        my $yaml = LoadFile( $dir . $file );

        push( @sandboxes, $yaml );
    }

    my $user_vars = LoadFile('../ansible/vars/user.yml');
warn Data::Dumper::Dumper( $user_vars );

    $self->render(
        title           => "Koha Sandbox Manager",
        sandboxes       => \@sandboxes,
        user_vars       => $user_vars,
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
    my $email       = $self->param('email');
    my $password    = $self->param('password');
    my $bug         = $self->param('bug');

    my $errors = {};
    $errors->{name_required}  = 1 unless $name;
    $errors->{user_required}  = 1 unless $user;
    $errors->{email_required} = 1 unless $email;
    $errors->{name_taken}     = 1 unless $name; #TODO

    my $params = {
        name        => $name,
        description => $description,
        notes       => $notes,
        user        => $user,
        password    => $password,
        created_on  => DateTime->now()->datetime(q{ }),
	bug        => $bug,
    };

    warn Data::Dumper::Dumper( $errors );
    if ( keys %$errors ) {
        $self->render(
            errors   => $errors,
            params   => $params,
            title    => "Koha Sandbox Manager",
            template => 'sandboxes/create_form',
        );

    }
    else {
	DumpFile("/sandboxes/configs/$name.yml", {
            KOHA_INSTANCE => $name,
    	    GIT_USER_EMAIL=> $email,
            GIT_USER_NAME => $user,
	    KOHA_CONF => "/etc/koha/sites/$name/koha-conf.xml",
	    BUG_NUMBER => $bug,
	    NOTES => $notes,
	    DESCRIPTION => $description,
	    PASSWORD => $password,
	    CREATED_ON => DateTime->now()->datetime(q{ }),
        });
        $self->stash( { sandbox => $params } );
        $self->render( title => "Koha Sandbox Manager - Provision Sandbox" );
    }
}

sub provision {
    my $self = shift;
    my $name = $self->stash('name');

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
