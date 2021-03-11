package SandboxManager;

use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
     my $self = shift;

    # Load configuration from hash returned by "my_app.conf"
    my $config = $self->plugin('Config');

    # Documentation browser under "/perldoc"
    #$self->plugin('PODRenderer') if $config->{perldoc};
    #PODRenderer is DEPRECATED

    $self->log( Mojo::Log->new( path => '/var/log/sandbox_manager.log', level => 'debug' ) );

    $self->plugin('TemplateToolkit');
    $self->plugin( TemplateToolkit => { template => { INTERPOLATE => 1 } } );
    $self->renderer->default_handler('tt2');

    # Router
    my $r = $self->routes;

    # Normal route to controller
    $r->get('/')->to('sandboxes#list');
    $r->get('/create')->to('sandboxes#create_form');
    $r->post('/create')->to('sandboxes#create_submit');
    $r->any('/renew/:name')->to('sandboxes#renew');
    $r->get('/signoff/:name')->to('sandboxes#signoff_form');
    $r->post('/signoff/:name')->to('sandboxes#signoff_submit');
    $r->get('/apply_bug/:name')->to('sandboxes#apply_bug_form');
    $r->post('/apply_bug/:name')->to('sandboxes#apply_bug_submit');
    $r->any('/provision_log/:name')->to('sandboxes#provision_log');
    $r->any('/docker_log/:name')->to('sandboxes#docker_log');
    $r->any('/koha_log/:name/:file')->to('sandboxes#koha_log');
    $r->any('/git_log/:name')->to('sandboxes#git_log');
    $r->any('/mail_log/:name')->to('sandboxes#mail_log');
    $r->any('/delete/:name')->to('sandboxes#delete');
    $r->any('/restart_all/:name')->to('sandboxes#restart_all');
    $r->any('/reindex_full/:name')->to('sandboxes#reindex_full');
    $r->any('/reindex_es/:name')->to('sandboxes#reindex_es');
    $r->any('/rebuild_dbic/:name')->to('sandboxes#rebuild_dbic');
    $r->any('/build_css/:name')->to('sandboxes#build_css');
    $r->any('/clear_database/:name')->to('sandboxes#clear_database');
    $r->get('/install_translation/:name')->to('sandboxes#install_translation_form');
    $r->post('/install_translation/:name')->to('sandboxes#install_translation_submit');
}

1;
