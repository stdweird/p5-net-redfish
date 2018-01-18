package Net::Redfish;

use strict;
use warnings;

use parent qw(
    Net::Redfish::Auth
    Net::Redfish::Base
    Net::Redfish::REST
    Net::Redfish::User
);

# ABSTRACT: Redfish REST API client

=head1 NAME

Net::Redfish

=head1 SYNOPSIS

Example usage:
    use Net::Redfish;
    ...
    my $rf = Net::Redfish->new('myhost.example.com');

For basic reporting:
    use Net::Redfish;
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($INFO);
    ...
    my $rf = Net::Redfish->new(
        'myhost.example.com',
        log => Log::Log4perl->get_logger()
        );

For debugging, including full JSON request / repsonse and headers (so contains sensitive data!):
    use Net::Redfish;
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($DEBUG);
    ...
    my $rf = Net::Redfish->new(
        'myhost.example.com',
        log => Log::Log4perl->get_logger(),
        debugapi => 1
        );

=head2 Public methods

=over

=item new

Arguments

=over

=item hostname: hostname / ip for Redfish API endpoint.

=back

Options

=over

=item log

An instance that can be used for logging (with error/warn/info/debug methods)
(e.g. L<Log::Log4perl>).

=item debugapi

When true, log the request and response body and headers with debug.
This can contain sensitive data. Use with care.

=item verify:

Enable or disable SSL verify_hostname.

A lot of Redfish devices use default certificates signed
by not well known or private CA (or are self-signed).

Passed to L<Net::Redfish::REST::_new_client>

=item unittest

Boolean to also report the debugapi data in unittest format.
(Requires C<debugapi> enabled.)

=back

If more options are definded, they are passed to
passed to L<Net::Redfish::Auth::login>.
(If no other options are defined, C<login> is not called).

=cut

# return 1 on success
sub _initialize
{
    my ($self, $hostname, %opts) = @_;

    $self->{log} = delete $opts{log};
    $self->{debugapi} = delete $opts{debugapi};
    $self->{unittest} = delete $opts{unittest};

    # Initialise the REST::Client
    my %clopts;
    $clopts{verify} = delete $opts{verify} if exists($opts{verify});
    $self->_new_client($hostname, %clopts);
    # run discovery on root service
    $self->discover_root();

    # Login, get token and gather services
    if (%opts) {
        if ($self->login(%opts)) {
            $self->discover();
        }
    }

    return 1;
}

=pod

=back

=cut


1;
