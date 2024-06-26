#!/usr/bin/perl

# (C) Sergey Kandaurov
# (C) Nginx, Inc.
# (C) 2023 Web Server LLC

# Tests for http proxy cache, min_free parameter.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http proxy cache/)
	->has_daemon("openssl");


$t->has(qw/http_v3/);
$t->prepare_ssl();

$t->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    proxy_cache_path   %%TESTDIR%%/cache  levels=1:2 min_free=4k
                       keys_zone=NAME:1m;

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        location / {
            proxy_pass https://127.0.0.1:%%PORT_8999_UDP%%;
            proxy_http_version  3;

            proxy_cache   NAME;

            proxy_cache_valid   any      1m;

            add_header X-Cache-Status $upstream_cache_status;
        }
    }

    server {
        ssl_certificate_key localhost.key;
        ssl_certificate localhost.crt;

        listen       127.0.0.1:%%PORT_8999_UDP%% quic;

        server_name  localhost;

        location / { }
    }
}

EOF

$t->write_file('t.html', 'SEE-THIS');
$t->run()->plan(2);

###############################################################################

like(http_get('/t.html'), qr/SEE-THIS/, 'proxy request');

$t->write_file('t.html', 'NOOP');
like(http_get('/t.html'), qr/SEE-THIS/, 'proxy request cached');

###############################################################################
