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

    my $name        = $self->param('name');

    if ( lc($self->param('captcha')) ne 'koha' ) {
        $self->app->log->info("Someone failed the captcha on create_submit for $name");
        $self->render( text => 'Failed captcha', status => 403 );
	return;
    }

    $self->redirect_to('/') if $self->max_sandboxes_reached;

    my $description  = $self->param('description');
    my $notes        = $self->param('notes');
    my $user         = $self->param('user');
    my $email        = $self->param('email');
    my $password     = $self->param('password');
    my $bug          = $self->param('bug');
    my $marc_flavour = $self->param('marc_flavour') || 'marc21';
    my $git_remote   = $self->param('git_remote');
    my $git_branch   = $self->param('git_branch');
    my $git_commitid = $self->param('git_commitid');

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

        $self->app->log->info("Someone called create_submit with $name");

        my $lifetime_hours = $user_vars->{SB_LIFETIME_HOURS};
        my $expiration = $lifetime_hours ? DateTime->now()->add( hours => $lifetime_hours )->datetime(q{ }) : undef;
        my $created_on = DateTime->now()->datetime(q{ });

        DumpFile(
            "$config_dir/$name.yml",
            {
                KOHA_INSTANCE     => $name,
                GIT_USER_EMAIL    => $email,
                GIT_USER_NAME     => $user,
                KOHA_CONF         => "/etc/koha/sites/$name/koha-conf.xml",
                BUG_NUMBER        => $bug,
                KOHA_MARC_FLAVOUR => $marc_flavour,
                GIT_REMOTE        => $git_remote,
                GIT_BRANCH        => $git_branch,
		GIT_COMMITID      => $git_commitid,
                NOTES             => $notes,
                DESCRIPTION       => $description,
                PASSWORD          => $password,
                CREATED_ON        => $created_on,
                EXPIRATION        => $expiration,
                RENEWALS          => 0,
            }
        );
        $self->redirect_to('/');
    }
}

sub renew {
    my $self = shift;

    my $name = $self->param('name');
    $self->app->log->info("Someone called renew on $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");

    my $max_renewals = $user_vars->{SB_MAX_RENEWALS};
    my $renewals = $sandbox->{RENEWALS};

    if ( $max_renewals && $renewals < $max_renewals ) {
        my $lifetime_hours = $user_vars->{SB_LIFETIME_HOURS};
        my $expiration = DateTime->now()->add( hours => $lifetime_hours )->datetime(q{ });
	$sandbox->{RENEWALS}++;
        $sandbox->{EXPIRATION} = $expiration;
        DumpFile( "$config_dir/$name.yml", $sandbox );
    }

    $self->redirect_to('/');
}

sub signoff_form {
    my $self = shift;

    my $name = $self->param('name');
    $self->app->log->info("Someone called signoff_form on $name");

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

    if ( lc($self->param('captcha')) ne 'koha' ) {
        $self->app->log->info("Someone failed the captcha on signoff_submit for $name");
        $self->render( text => 'Failed captcha', status => 403 );
	return;
    }

    my $user   = $self->param('user');
    my $email  = $self->param('email');
    my $bug    = $self->param('bug');
    my $number = $self->param('number');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = q{};
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "cd /kohadevbox/koha && git stash" };
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "cd /kohadevbox/koha && git s $number && yes | git bza2 $number $bug" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "cd /kohadevbox/koha && git stash pop" };

    $self->render(
        title  => "Koha Sandbox Manager - Sign off patches",
        text   => $output,
        format => 'txt'
    );
}

sub apply_bug_form {
    my $self = shift;

    my $name = $self->param('name');
    $self->app->log->info("Someone called apply_bug_form for $name");

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
    $self->app->log->info("Someone called apply_bug_submit for $name with $bug");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");
    $sandbox->{BUG_NUMBER} = $bug;
    DumpFile( "$config_dir/$name.yml", $sandbox );

    my $output = q{};
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "cd /kohadevbox/koha && yes | git bz apply $bug" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "perl koha/installer/data/mysql/updatedatabase.pl" } . "\n";

    $self->render(
        title  => "Koha Sandbox Manager - Sign off patches",
        text   => $output,
        format => 'txt'
    );
}

sub install_translation_form {
    my $self = shift;

    my $name = $self->param('name');
    $self->app->log->info("Someone called install_translation_form for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");

    $self->render(
        title   => "Koha Sandbox Manager - Install translation",
        sandbox => $sandbox
    );
}

sub install_translation_submit {
    my $self = shift;

    my $name = $self->param('name');
    my $translation = $self->param('translation');
    $self->app->log->info("Someone called apply_translation_submit for $name with $translation");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "(cd koha; ./misc/translator/translate install -v $translation)" } . "\n";
    $output   .= qx{ docker exec -t koha-$name /bin/bash -c "service koha-common stop" }   . "\n";
    $output   .= qx{ docker exec -t koha-$name /bin/bash -c "service koha-common start" } . "\n";
    $output   .= qx{ docker exec -t koha-$name /bin/bash -c "service apache2 reload" }    . "\n";
    $output   .= qx{ docker restart memcached } . "\n";

    $self->render(
        title  => "Koha Sandbox Manager - Translation installed",
        text   => $output,
        format => 'txt'
    );
}

sub rebuild_dbic {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called rebuild_dbic for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "(cd koha; misc/devel/update_dbix_class_files.pl --db_name=koha_$name --db_host=db --db_user=koha_$name --db_passwd=$user_vars->{KOHA_DB_PASSWORD})" } . "\n";

    $self->render(
        title  => "Full DBIC Schema Rebuild",
        text   => $output,
        format => 'txt'
    );
}

sub build_css {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called rebuild_css for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "(cd koha; yarn install)" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "(cd koha; yarn build)" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "(cd koha; yarn build --view=opac)" } . "\n";

    $self->render(
        title  => "Rebuild of css from scss",
        text   => $output,
        format => 'txt'
    );
}

sub delete {
    my $self = shift;

    my $name = $self->stash('name');

    if ( lc($self->param('captcha')) ne 'koha' ) {
        $self->app->log->info("Someone failed the captcha on create_submit for $name");
        $self->render( text => 'Failed captcha', status => 403 );
	return;
    }

    $self->app->log->info("Someone called delete for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $sandbox = LoadFile("$config_dir/$name.yml");
    $sandbox->{DELETE} = 1;
    DumpFile( "$config_dir/$name.yml", $sandbox );

    $self->redirect_to('/');
}

sub restart_all {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called restart_all for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "service koha-common stop" }   . "\n";
    $output   .=  qx{ docker exec -t koha-$name /bin/bash -c "service koha-common start" } . "\n";
    $output   .=  qx{ docker exec -t koha-$name /bin/bash -c "service apache2 reload" }    . "\n";
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
    $self->app->log->info("Someone called reindex_all for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "koha-rebuild-zebra -f -v $name" } . "\n";

    $self->render(
        title  => "Full Zebra Reindex",
        text   => $output,
        format => 'txt'
    );
}

sub reindex_es {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called reindex_es for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "koha-elasticsearch --rebuild -d -v $name" } . "\n";

    $self->render(
        title  => "Full Elastic Reindex",
        text   => $output,
        format => 'txt'
    );
}

sub clear_database {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called clear_database for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $output = qx{ docker exec -t koha-$name /bin/bash -c "koha-mysql $name <<< 'DROP DATABASE koha_$name; CREATE DATABASE koha_$name;'" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "service koha-common stop" }  . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "service koha-common start" } . "\n";
    $output .= qx{ docker exec -t koha-$name /bin/bash -c "service apache2 reload" }    . "\n";
    $output .= qx{ docker restart memcached } . "\n";
    $output .= qq{ Koha should now show the web installer. The username will be 'koha_$name' with the password 'password' } . "\n";

    $self->render(
        title  => "Full Zebra Reindex",
        text   => $output,
        format => 'txt'
    );
}

sub provision_log {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called provision_log for $name");

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
    $self->app->log->info("Someone called docker_log for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text = qx{ docker logs -t koha-$name };

    $self->render( title => "Docker log", text => $text, format => 'txt' );
}

sub koha_log {
    my $self = shift;
    my $name = $self->stash('name');
    my $file = $self->stash('file');
    $self->app->log->info("Someone called koha_log for $name with $file");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $filename =
        $file eq "plack"          ? "/var/log/koha/$name/plack-error.log"
      : $file eq "intranet-error" ? "/var/log/koha/$name/intranet-error.log"
      : $file eq "opac-error"     ? "/var/log/koha/$name/opac-error.log"
      :                             undef;

    $self->redirect_to('/') unless $filename;

    my $text = qx{ docker exec -t koha-$name cat $filename };

    $self->render( title => "Koha log", text => $text, format => 'txt' );
}

sub git_log {
    my $self = shift;
    my $name = $self->stash('name');
    $self->app->log->info("Someone called git_log for $name");

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text = qx{ docker exec koha-$name bash -c "cd /kohadevbox/koha && git log HEAD~50..HEAD" };

    $self->render( title => "Koha git log", text => $text, format => 'txt' );
}

sub mail_log {
    my $self = shift;
    my $name = $self->stash('name');

    $self->redirect_to('/') unless -f "$config_dir/$name.yml";

    my $text = qx{ docker exec koha-$name bash -c "cat /kohadevbox/mail" };

    $self->render( title => "Koha mail log", text => $text, format => 'txt' );
}

sub max_sandboxes_reached {
    opendir( my $dh, $config_dir );
    my $count = () = readdir($dh);
    closedir($dh);

    # Add 2 to account for `.` and `..`
    my $max = $user_vars->{MAX_SANDBOXES} + 2;
    return $count >= $max;
}

1;
