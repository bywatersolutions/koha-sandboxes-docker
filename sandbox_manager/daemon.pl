#!/usr/bin/perl

use Modern::Perl;
use feature 'say';

use Cwd qw( realpath getcwd );
use Data::Dumper;
use DateTime;
use File::Spec::Functions;
use Getopt::Long;
use Proc::Daemon;
use YAML qw( LoadFile DumpFile );

my $config_dir = q{/sandboxes/configs};
my $logs_dir   = q{/sandboxes/logs};
my $script_dir = Cwd::realpath('..');

chdir($script_dir);

my $pf = catfile( getcwd(), 'pidfile.pid' );
my $daemon = Proc::Daemon->new(
    pid_file => $pf,
    work_dir => getcwd()
);

# are you running?  Returns 0 if not.
my $pid       = $daemon->Status($pf);
my $daemonize = 0;

GetOptions(
    'd|daemon' => \$daemonize,
    "start"    => \&start,
    "status"   => \&status,
    "stop"     => \&stop
);

sub stop {
    if ($pid) {
        say "Stopping pid $pid...";
        if ( $daemon->Kill_Daemon($pf) ) {
            say "Successfully stopped.";
        }
        else {
            say "Unable to find $pid.";
        }
    }
    else {
        say "Daemon not running, nothing to stop.";
    }
}

sub status {
    if ($pid) {
        say "Daemon running with pid $pid.";
    }
    else {
        say "Daemon not running.";
    }
}

sub start {
    if ( !$pid ) {
        say "Starting...";
        $daemon->Init if $daemonize;

	my $user_vars = LoadFile('ansible/vars/user.yml');

        while (1) {
            opendir( DIR, $config_dir );
            while ( my $file = readdir(DIR) ) {
                next unless ( -f "$config_dir/$file" );
                next unless ( $file =~ m/\.yml$/ );

                my $sandbox = LoadFile("$config_dir/$file");
                my $sandbox_name = $sandbox->{KOHA_INSTANCE};

                if ( !$sandbox->{PROVISIONED_ON} ) {
                    $sandbox->{PROVISIONED_ON} = DateTime->now()->datetime(q{ });
                    if ( DumpFile( "$config_dir/$file", $sandbox ) ) {
			say "PROVISIONING $sandbox_name";

                        my $output = qx{ $script_dir/create-sandbox-instance.sh -f $config_dir/$file 2>&1 1>$logs_dir/$sandbox_name.log };

			say "LOGFILE: $logs_dir/$sandbox_name.log";

			$sandbox->{PROVISION_COMPLETE} = 1;
			DumpFile( "$config_dir/$file", $sandbox );
                    }
                    else {
                        say "Unable to write to $config_dir/$file!";
                    }
                } elsif ( $sandbox->{DELETE} ) {
	            say "DELETING $sandbox_name";
                    qx{ $script_dir/destroy-sandbox-instance.sh -f $config_dir/$file };
		    unlink "$logs_dir/$sandbox_name.log";
		    unlink "$config_dir/$sandbox_name.yml";
		    say "DELETION OF $sandbox_name COMPLETE";
		}

            }
            sleep(1);
        }
    }
    else {
        say "Daemon already running with pid $pid";
    }
}
