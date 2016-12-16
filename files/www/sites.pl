#!/usr/bin/perl

use Modern::Perl;

use Template;
use Apache::Admin::Config;
use Data::Dumper;

my $config_dir = '/etc/apache2/sites-enabled/';

my @configs;

my $DIR;
opendir( $DIR, $config_dir ) or die $!;
while ( my $file = readdir($DIR) ) {
    push( @configs, $file ) unless $file =~ /^\./;
}

my $instances;
foreach my $config (@configs) {
    next unless ( $config =~ /conf$/ );

    my ( $site_name ) = split(/\./, $config);

    my $conf = new Apache::Admin::Config( $config_dir . $config )
      or next;

    # All Koha configs start with a coment that starts with Koha
    my @comments = $conf->select( -type => 'comment' );
    my $header_comment = $comments[0];
    next unless ( $header_comment && $header_comment->value =~ /^Koha/ );

    # Read in the comments at the end
    my $params;
    for my $i ( -4 .. -1 ) {
        my ( $key, $val ) = split( /\:/, $comments[$i]->value );
        $params->{$key} = $val;
    }
    my $instance_type = $params->{Type} || 'misc';
    my $description   = $params->{Description};
    my $notes         = $params->{Notes};
    my $specialist    = $params->{Specialist};

    $instances->{$instance_type}->{$site_name}->{description} = $description;
    $instances->{$instance_type}->{$site_name}->{notes}       = $notes;
    $instances->{$instance_type}->{$site_name}->{specialist}  = $specialist;
    $instances->{$instance_type}->{$site_name}->{name} = $site_name;

    foreach my $vhost ( $conf->section( -name => "VirtualHost" ) ) {
        my $instance;

        my $ServerName  = $vhost->directive('ServerName');
        my $server_name = $ServerName->value;

        my $vhost_type = ( $server_name =~ /^staff/ ) ? 'staff' : 'opac';

        $instance->{ServerName} = $server_name;

        my @SetEnv = $vhost->directive('SetEnv');
        foreach my $se (@SetEnv) {
            my $value = $se->value;
            my ( $var, $val ) = split( / /, $value );
            $val =~ s/'//g;
            $val =~ s/"//g;

            $instance->{Env}->{$var} = $val;
        }

        # Try looking up version in the modern way, fail to legacy way
        eval { require "/var/lib/koha/$site_name/kohaclone/Koha.pm" };
        if ($@) {
            eval { require "/var/lib/koha/$site_name/kohaclone/Koha.pm" };
            if ($@) {
                eval { require "/var/lib/koha/$site_name/kohaclone/kohaversion.pl"; };

                if ($@) {
                    eval { require "/usr/share/koha/intranet/cgi-bin/kohaversion.pl"; };
                }

                eval { $instance->{KohaVersion} = kohaversion() };
            } else {
                eval { $instance->{KohaVersion} = Koha::version() };
            }
        } else {
            eval { $instance->{KohaVersion} = Koha::version() };
        }

        $instances->{$instance_type}->{$site_name}->{version} = $instance->{KohaVersion};

        push(
            @{ $instances->{$instance_type}->{$site_name}->{$vhost_type} },
            $instance
        );
    }
}

my $tt = Template->new(
    {
        INCLUDE_PATH => '/usr/lib/cgi-bin/sites',
    }
) || die "$Template::ERROR\n";

print qq(Content-type: text/html\n\n);
$tt->process( 'sites.tt', { instances => $instances } )
  || die $tt->error(), "\n";
