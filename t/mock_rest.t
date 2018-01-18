use strict;
use warnings;

use File::Basename;
use Test::More;

BEGIN {
    push(@INC, dirname(__FILE__));
}

use Test::MockModule;

use Net::Redfish;
use mock_rest qw(mock_rest);
use logger;

=head2 import

=cut

is(scalar keys %mock_rest::cmds, 2, "imported example data");

=head2 Test the mock_rest test module

=cut

my $rf = Net::Redfish->new('fqdn', log => logger->new(), debugapi => 1);
isa_ok($rf, 'Net::Redfish', 'Net::Redfish instance');

# call it here, is only tested it self later
reset_method_history;

# was already called once
my $resp = $rf->services('root');
isa_ok($resp, 'Net::Redfish::Response', 'got valid response');

is_deeply($resp->{data},
          {woo => 'hoo', 'SessionService' => {'@odata.id' => '/redfish/v1/SessionService'}},
          "Correct data from GET");
is_deeply($resp->{headers}, {'Content-Type' => 'application/json'}, "Correct (default) headers");
is_deeply($resp->result,
          {woo => 'hoo', 'SessionService' => {'@odata.id' => '/redfish/v1/SessionService'}},
          "Result with absent result path");
ok(!$resp->{error}, "response error is false");
ok($resp, "response is not an error");

$resp = $rf->login(username => 'abc', password => 'def');
is_deeply($resp->{data}, {success => 1}, "Correct (default) data from POST");
is_deeply($resp->{headers},
          {'Content-Type' => 'application/json', 'Special' => 123, 'Location' => 'something', 'X-Auth-Token' => 'testtoken'},
          "Correct headers");
is($resp->result, 'testtoken', "Result path as header applied to response data");

my @hist = find_method_history(''); # empty string matches everything
#diag "whole history ", explain \@hist;
is_deeply(\@hist, [
    'GET https://fqdn/redfish/v1/  Content-Type=application/json',
    'POST https://fqdn/redfish/v1/SessionService/Sessions/ {"Password":"def","UserName":"abc"} Content-Type=application/json',
], "method history: one POST call");

ok(method_history_ok(['GET', 'POST https://fqdn/redfish/v1/SessionService/Sessions/']), "call history ok");

# Tests the order
ok(! method_history_ok(['POST', 'GET']), "GET not called after POST");

# Test not_commands
ok(method_history_ok(['GET', 'POST'], ['PATCH']), "no PATCH called (in method history)");
ok(!method_history_ok(['POST'], ['GET']), "no no GET called (i.e. GET called in method history)");

reset_method_history;

@hist = find_method_history('');
is_deeply(\@hist, [], "method history empty after reset");

done_testing();
