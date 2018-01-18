package Net::Redfish::User;

use strict;
use warnings;

use Net::Redfish::Request;
use Readonly;


=head2 Public functions

=over

=item users

Return arrayref with user (hashref of userdata per user).

=cut

sub users
{
    my ($self) = @_;

    my $allusers = $self->members('Accounts');

    return $allusers;
}

=item roles

Return arrayref with known roles

=cut

sub roles
{
    my ($self) = @_;

    my $allroles = $self->members('Roles');

    return $allroles;
}

=pod

=back

=cut

1;
