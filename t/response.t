use strict;
use warnings;

use Net::Redfish::Response;

use Test::More;

my $r;

=new init

=cut

$r = Net::Redfish::Response->new();
isa_ok($r, 'Net::Redfish::Response', 'a Net::Redfish::Response instance created');

$r = mkresponse();
isa_ok($r, 'Net::Redfish::Response', 'a Net::Redfish::Response instance created using mkrequest');

isa_ok($r->{error}, 'Net::Redfish::Error', 'Error instance by default');
ok(! $r->is_error(), 'is_error false');
ok($r, 'overloaded boolean = true if no error via is_error');

$r = mkresponse(error => 'abc');
isa_ok($r->{error}, 'Net::Redfish::Error', 'error attribute set');
is("$r->{error}", "Error abc", "string as message");
ok($r->is_error(), 'is_error true');
ok(! $r, 'overloaded boolean = false on error via is_error');


=head2 set_error

=cut

my $e = $r->set_error();
isa_ok($r->{error}, 'Net::Redfish::Error', 'error attribute set 2');
is("$r->{error}", "No error", "no error error message");
ok(! $r->is_error(), 'is_error false');
ok($r, 'overloaded boolean = true on error via is_error');

isa_ok($e, 'Net::Redfish::Error', 'set_error returns error');
is("$e", "No error", "no error error message for returned error");

$e = $r->set_error({code => 100});
isa_ok($r->{error}, 'Net::Redfish::Error', 'error attribute set 3');
is("$r->{error}", "Error 100", "code 100 error message");
ok($r->is_error(), 'is_error true');
ok(! $r, 'overloaded boolean = false on error via is_error');

isa_ok($e, 'Net::Redfish::Error', 'set_error returns error');
is("$e", "Error 100", "code 100 error message for returned error");

=head2 set_result

=cut

$r = mkresponse(data => { a => { b => {c => { d => 1}}}}, headers => {myheader => 1});
is_deeply($r->set_result(), { a => { b => {c => { d => 1}}}}, "result using default resultpath returns result");
is_deeply($r->{result}, { a => { b => {c => { d => 1}}}}, "result attribute set using default resultpath");

is_deeply($r->set_result('myheader'), 1, "result using non-absolute path resultpath returns header data");

is_deeply($r->set_result('/a/b/c'), {d => 1}, "result using custom resultpath");

ok(! defined($r->set_result('/a/b/e')), "result undef using non-existing resultpath");

$r = mkresponse(data => { a => {b => {c => { d => 1}}}}, error => 1);
ok($r->is_error(), 'error response');
ok(! defined($r->set_result('/a/b/c')), "set_result returns undef on error response");
ok(! defined($r->{result}), "result attribute not set on error response");

=head2 _walk

=cut

sub testb
{
    my ($data, $key) = @_;

    return if $key ne 'b';
    return $data;
}
$r = mkresponse(data => {a => {b => 1}, e => [qw(1 2 3)], f => {g => {b => 1}}});
#diag explain [Net::Redfish::Response::_walk($r->{data}, \&testb)];
is_deeply([Net::Redfish::Response::_walk($r->{data}, \&testb)],
    [[['a', 'b'], 1], [['f', 'g', 'b'], 1]], "_walk returns as expected");

=head2 _service_url / services

=cut

my $hp_root = {
  '@odata.context' => '/redfish/v1/$metadata#ServiceRoot',
  '@odata.id' => '/redfish/v1/',
  'AccountService' => {
    '@odata.id' => '/redfish/v1/AccountService/'
  },
  'Chassis' => {
    'target' => '/redfish/v1/Chassis/'
  },
  'Id' => 'v1',
  'Name' => 'HP RESTful Root Service',
  'Oem' => {
    'Hp' => {
      '@odata.type' => '#HpiLOServiceExt.1.0.0.HpiLOServiceExt',
      'Manager' => [
        {
            'DefaultLanguage' => 'en',
        }
      ],
      'Type' => 'HpiLOServiceExt.1.0.0',
      'links' => {
        'ResourceDirectory' => {
          'href' => '/redfish/v1/ResourceDirectory/'
        }
      }
    }
  }
};

is(Net::Redfish::Response::_service_url($hp_root->{Chassis}, 'abc'),
   '/redfish/v1/Chassis/', '_service_url found');
ok(!defined Net::Redfish::Response::_service_url($hp_root->{Name}, 'cde'),
   '_service_url returns undef');

$r = mkresponse(data => $hp_root);
#diag explain $r->services;
is_deeply($r->services,
          [[['AccountService'], '/redfish/v1/AccountService/'],
           [['Chassis'], '/redfish/v1/Chassis/'],
           [[qw(Oem Hp links ResourceDirectory)], '/redfish/v1/ResourceDirectory/'],
          ],
          "Response found services");

=head2 _member_urls / members

=cut

my $hp_users = {
    'MemberType' => 'ManagerAccount.1',
  'Members' => [
    {
      '@odata.id' => '/redfish/v1/AccountService/Accounts/1/'
    },
    {
      '@odata.id' => '/redfish/v1/AccountService/Accounts/2/'
    }
  ],
  'Members@odata.count' => 2,
  'Name' => 'Accounts',
  'Total' => 2,
  'Type' => 'Collection.1.0.0',
  'links' => {
    'Member' => [
      {
        'href' => '/redfish/v1/AccountService/Accounts/1/'
      },
      {
        'href' => '/redfish/v1/AccountService/Accounts/2/'
      }
    ],
    'self' => {
      'href' => '/redfish/v1/AccountService/Accounts/'
    }
  }
};

is_deeply(Net::Redfish::Response::_member_urls($hp_users->{Members}, 'Members'),
   ['/redfish/v1/AccountService/Accounts/1/', '/redfish/v1/AccountService/Accounts/2/'],
   '_member_urls found');
# Member (w/o s) not a typo
ok(!defined Net::Redfish::Response::_service_url($hp_root->{links}, 'links'),
   '_member_urls returns undef');

$r = mkresponse(data => $hp_users);
#diag explain $r->members;
is_deeply($r->members,
          [
           [['Members'], ['/redfish/v1/AccountService/Accounts/1/', '/redfish/v1/AccountService/Accounts/2/']],
          ],
          "Response found members");


done_testing();
