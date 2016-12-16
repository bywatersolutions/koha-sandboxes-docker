#!/usr/bin/perl

use Modern::Perl;

use CGI;

my $cgi = new CGI;

my $message = $cgi->param('message');

my $pipe = '/tmp/devbot';

open( FIFO, "> $pipe" ) or die $!;
print FIFO $message;
close(FIFO);

print $cgi->header(
    -type            => 'text/html',
);
say $message;
