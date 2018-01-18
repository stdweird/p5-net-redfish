use strict;
use warnings;

use File::Basename;
use Test::More;

BEGIN {
    push(@INC, dirname(__FILE__));
}

use Net::Redfish;
use mock_rest qw(auth rest);

use logger;

my $rf = Net::Redfish->new('fqdn', log => logger->new(), debugapi=>1);
isa_ok($rf, 'Net::Redfish::Auth', 'the client is an Auth instance');

reset_method_history;

$rf->login(username => 'abc', password => 'def');
is($rf->{token}, 'testtoken', "token set");
is($rf->{session}, '/some/session', "session set");

$rf->logout();
my @hist = find_method_history(''); # empty string matches everything
diag "whole history ", explain \@hist;
is_deeply(\@hist, [
    'POST https://fqdn/redfish/v1/SessionService/Sessions/ {"Password":"def","UserName":"abc"} Content-Type=application/json',
    'DELETE https://fqdn/redfish/v1/some/session/  Content-Type=application/json,X-Auth-Token=testtoken',
], "method history");


done_testing;
