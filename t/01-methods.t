#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use Mojo::Base -strict;
use Mojolicious;

use Try::Tiny qw(try catch);

use_ok 'WebService::Clockify';

my $ws = new_ok 'WebService::Clockify' => [ apikey => '1234567890' ];

can_ok $ws, 'user';

my $mock = Mojolicious->new;
$mock->log->level('fatal'); # only log fatal errors to keep the server quiet
$mock->routes->get('/user' => sub {
    my $c = shift;
    return $c->render(status => 200, json => {ok => 1});
});
$ws->ua->server->app($mock); # point our UserAgent to our new mock server

$ws->base(Mojo::URL->new(''));

my $data = try { $ws->user } catch { $_ };
is_deeply $data, {ok => 1}, 'user';

done_testing();
