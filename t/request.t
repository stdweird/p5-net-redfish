use strict;
use warnings;

# does not test mkrequest auto-export via @EXPORT
use Net::Redfish::Request qw(mkrequest @SUPPORTED_METHODS);

use REST::Client;
use Test::More;
use version;

use File::Basename;
BEGIN {
    push(@INC, dirname(__FILE__));
}

my $r;

my $rclient = REST::Client->new();
foreach my $method (@SUPPORTED_METHODS) {
    ok($rclient->can($method), "REST::Client supports method $method");
}


=head1 init

=cut

$r = Net::Redfish::Request->new('c', 'POST');
isa_ok($r, 'Net::Redfish::Request', 'a Net::Redfish::Request instance created');


$r = mkrequest('c', 'POST');
isa_ok($r, 'Net::Redfish::Request', 'a Net::Redfish::Request instance created using mkrequest');

is($r->{endpoint}, '/redfish/v1/c/', 'endpoint set');
is($r->{method}, 'POST', 'method set');
is_deeply($r->{rest}, {}, 'empty hash ref as rest by default');
ok(! defined($r->{error}), 'No error attribute set by default');
ok(! $r->is_error(), 'is_error false');
ok($r, 'overloaded boolean = true if no error via is_error');

$r = mkrequest('d', 'PUT', error => 'message', rest => {woo => 'hoo'});
is($r->{endpoint}, '/redfish/v1/d/', 'endpoint set 2');
is($r->{method}, 'PUT', 'method set 2');
is_deeply($r->{rest}, {woo => 'hoo'}, 'hash ref as rest');
is($r->{error}, 'message', 'error attribute set');
ok($r->is_error(), 'is_error true');
ok(! $r, 'overloaded boolean = false on error via is_error');

$r = Net::Redfish::Request->new('c', 'NOSUCHMETHOD');
isa_ok($r, 'Net::Redfish::Request', 'a Net::Redfish::Request instance created');
ok(!defined($r->{method}), "undefined method attribute with unsupported method");
ok(!$r, "false request with unsupported method");
is($r->{error}, "Unsupported method NOSUCHMETHOD", "error message with unsupported method");

=head1 endpoints

=cut

my $endpt = 'a/b/c';
my $rfendpt = "/redfish/v1/$endpt/";
$r = mkrequest($endpt, 'PUT');
is($r->{endpoint}, $rfendpt, "endpoint after init");
ok(!defined($r->endpoint), "endpoint returns undef with host missing");
is($r->endpoint("my.fqdn"), "https://my.fqdn$rfendpt", "endpoint with fqdn host");
is($r->{endpoint}, $rfendpt, "endpoint after templating");

=head1 headers

=cut

is_deeply($r->headers(), {
    'Content-Type' => 'application/json',
}, "headers without args returns default headers");


is_deeply($r->headers(token => 123, headers => {test => 1}), {
    'Content-Type' => 'application/json',
    'X-Auth-Token' => 123,
    test => 1,
}, "headers with token and custom headers");

done_testing();
