use strict;
use warnings;

use File::Basename;
use Test::More;

BEGIN {
    push(@INC, dirname(__FILE__));
}

use Test::MockModule;
use JSON::XS;
use Net::Redfish;
use version;

use mock_rest qw(rest);


# only logger is required for self
use logger;
my $rf = Net::Redfish->new('fqdn', log => logger->new(), debugapi=>1);
isa_ok($rf, 'Net::Redfish::REST', 'the client is a REST instance');

# Most rest functionality is already tested in mock_rest
is($rf->{version}, version->new('v1.0.2'), 'version from root');
is_deeply($rf->{services}, {
    'root' => '/',
    'AccountService' => '/redfish/v1/Managers/iDRAC.Embedded.1/AccountService',
    'Chassis' => '/redfish/v1/Chassis',
    'EventService' => '/redfish/v1/EventService',
    'JsonSchemas' => '/redfish/v1/JSONSchemas',
    'Managers' => '/redfish/v1/Managers',
    'Registries' => '/redfish/v1/Registries',
    'SessionService' => '/redfish/v1/SessionService',
    'Systems' => '/redfish/v1/Systems',
    'Tasks' => '/redfish/v1/TaskService',
    'Links/Sessions' => '/redfish/v1/Sessions',
}, "services discovered from root");

my $req = $rf->request('AccountService', 'POST', suffix => 'Accounts', raw => {woohoo => 1});
isa_ok($req, 'Net::Redfish::Request', 'request returns a Net::Redfish::Request instance');
is($req->{method}, 'POST', 'correct method');
is($req->{endpoint}, '/redfish/v1/Managers/iDRAC.Embedded.1/AccountService/Accounts/', 'correct endpoint');
is_deeply($req->{raw}, {woohoo =>1}, 'raw option passed');

done_testing;
