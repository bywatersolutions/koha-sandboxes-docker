package SandboxManager::Controller::Sandboxes;

use Mojo::Base 'Mojolicious::Controller';

use DateTime;
use File::Slurp;
use FindBin qw($Bin);
use Try::Tiny;
use YAML qw{ LoadFile DumpFile };

our $sandboxes_dir = "/sandboxes";
our $config_dir    = "$sandboxes_dir/configs";
our $logs_dir      = "$sandboxes_dir/logs";
our $user_vars     = LoadFile("$Bin/../../ansible/vars/user.yml");

sub list {
    my $self = shift;

    my @sandboxes;

    opendir( DIR, $config_dir );
    while ( my $file = readdir(DIR) ) {
        next unless ( -f "$config_dir/$file" );
        next unless ( $file =~ m/\.yml$/ );

        my $yaml = LoadFile("$config_dir/$file");

        push( @sandboxes, $yaml );
    }

    $self->render(
        title     => "Koha Sandbox Manager",
        sandboxes => \@sandboxes,
        user_vars => $user_vars,
        view      => 'list',
    );
}

sub create_form {
    my $self = shift;

    $self->redirect_to('/') if $self->max_sandboxes_reached;

    $self->render( title => "Koha Sandbox Manager - Create Sandbox", );
}

sub create_submit {
    my $self = shift;

    $self->redirect_to('/') if $self->max_sandboxes_reached;

    my $name        = $self->param('name');
    my $description = $self->param('description');
    my $notes       = $self->param('notes');
    my $user        = $self->param('user');
    my $email       = $self->param('email');
    my $password    = $self->param('password');
    my $bug         = $self->param('bug');
    my $git_remote  = $self->param('git_remote');
    my $git_branch  = $self->param('git_branch');

    my $errors = {};
    $errors->{name_required}  = 1 unless $name;
    $errors->{user_required}  = 1 unless $user;
    $errors->{email_required} = 1 unless $email;
    $errors->{name_taken}     = 1 unless $name;    #TODO

    if ( keys %$errors ) {
        $self->render(
            errors   => $errors,
            title    => "Koha Sandbox Manager",
            template => 'sandboxes/create_form',
        );

    }
    else {
        DumpFile(
            "$config_dir/$name.yml",
            {
                KOHA_INSTANCE  => $name,
                GIT_USER_EMAIL => $email,
                GIT_USER_NAME  => $user,
                KOHA_CONF      => "/etc/koha/sites/$name/koha-conf.xml",
                BUG_NUMBER     => $bug,
                GIT_REMOTE     => $git_remote,
                GIT_BRANCH     => $git_branch,
                NOTES          => $notes,
                DESCRIPTION    => $description,
                PASSWORD       => $password,
                CREATED_ON     => DateTime->now()->datetime(q{ }),
            }
        );
        $self->redirect_to('/');
    }
}

sub signoff_form {
    my $self = shift;

    my $name = $self->param('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");

    $self->render(
        title   => "Koha Sandbox Manager - Sign off patches",
        sandbox => $sandbox
    );
}

sub signoff_submit {
    my $self = shift;

    my $name   = $self->param('name');
    my $user   = $self->param('user');
    my $email  = $self->param('email');
    my $number = $self->param('number');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = q{};
    $output .= qx{ docker exec koha-$name /bin/bash -c "cd /kohadevbox/koha && git s $number && yes | git bza2 $number" } . "\n";

    $self->render(
        title  => "Koha Sandbox Manager - Sign off patches",
        text   => $output,
        format => 'txt'
    );
}

sub apply_bug_form {
    my $self = shift;

    my $name = $self->param('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");

    $self->render(
        title   => "Koha Sandbox Manager - Apply bug patches",
        sandbox => $sandbox
    );
}

sub apply_bug_submit {
    my $self = shift;

    my $name = $self->param('name');
    my $bug = $self->param('bug');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = q{};
    $output .= qx{ docker exec koha-$name /bin/bash -c "cd /kohadevbox/koha && yes | git bz apply $bug" } . "\n";

    $self->render(
        title  => "Koha Sandbox Manager - Sign off patches",
        text   => $output,
        format => 'txt'
    );
}

sub delete {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");
    $sandbox->{DELETE} = 1;
    DumpFile( "$config_dir/$name.yml", $sandbox );

    $self->redirect_to('/');
}

sub restart_all {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec koha-$name /bin/bash -c "service koha-common stop" }   . "\n";
    $output   .=  qx{ docker exec koha-$name /bin/bash -c "service koha-common start" } . "\n";
    $output   .=  qx{ docker exec koha-$name /bin/bash -c "service apache2 reload" }    . "\n";
    $output   .= qx{ docker restart memcached } . "\n";

    $self->render(
        title  => "Restart services",
        text   => $output,
        format => 'txt'
    );
}

sub reindex_full {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec koha-$name /bin/bash -c "koha-rebuild-zebra -f -v $name" } . "\n";

    $self->render(
        title  => "Full Zebra Reindex",
        text   => $output,
        format => 'txt'
    );
}

sub clear_database {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec koha-$name /bin/bash -c "koha-mysql $name <<< 'DROP DATABASE koha_$name; CREATE DATABASE koha_$name;'" } . "\n";
    $output .= qx{ docker exec koha-$name /bin/bash -c "service koha-common stop" }  . "\n";
    $output .= qx{ docker exec koha-$name /bin/bash -c "service koha-common start" } . "\n";
    $output .= qx{ docker exec koha-$name /bin/bash -c "service apache2 reload" }    . "\n";
    $output .= qx{ docker restart memcached } . "\n";

    $self->render(
        title  => "Full Zebra Reindex",
        text   => $output,
        format => 'txt'
    );
}

sub provision_log {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text;
    try {
        $text = read_file("$logs_dir/$name.log");
    }
    catch {
        $text = $_;
    };

    $self->render( title => "Provision log", text => $text, format => 'txt' );
}

sub docker_log {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text = qx{ docker logs -t koha-$name };

    $self->render( title => "Docker log", text => $text, format => 'txt' );
}

sub koha_log {
    my $self = shift;
    my $name = $self->stash('name');
    my $file = $self->stash('file');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $filename =
        $file eq "plack"          ? "/var/log/koha/$name/plack-error.log"
      : $file eq "intranet-error" ? "/var/log/koha/$name/intranet-error.log"
      : $file eq "opac-error"     ? "/var/log/koha/$name/opac-error.log"
      :                             undef;

    $self->redirect_to('/') unless $filename;

    my $text = qx{ docker exec koha-$name cat $filename };

    $self->render( title => "Koha log", text => $text, format => 'txt' );
}

sub git_log {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text = qx{ docker exec koha-$name bash -c "cd /kohadevbox/koha && git log HEAD~50..HEAD" };

    $self->render( title => "Koha git log", text => $text, format => 'txt' );
}

sub max_sandboxes_reached {
    opendir( my $dh, $config_dir );
    my $count = () = readdir($dh);
    closedir($dh);

    return $count >= $user_vars->{MAX_SANDBOXES};
}

1;
