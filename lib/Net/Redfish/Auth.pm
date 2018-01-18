package Net::Redfish::Auth;

use strict;
use warnings;

use Net::Redfish::Request qw(mkrequest $HDR_X_AUTH_TOKEN);
use Readonly;

=head1 methods

=over

=item login

Login and obtain token for further authentication.

Options:

=over

=item username: username to login

=item password: password matching username

=back

=cut

sub login
{
    my ($self, %opts) = @_;

    my $resp;
    if ($opts{username} && $opts{password}) {
        my $data = {UserName => $opts{username}, Password => $opts{password}};
        my $req = $self->request(
            'SessionService', 'POST',
            raw => $data,
            result => $HDR_X_AUTH_TOKEN,
            suffix => 'Sessions',
            );
        # Some dell devices give 405/'No method allowed' with full headers
        $resp = $self->rest($req, success => [405]);
        if ($resp) {
            $self->{token} = $resp->result;
            $self->error("No token found") if ! defined $self->{token};
            # also store session url, used to logout
            $self->{session} = $resp->{headers}->{Location};
            $self->error("No session found") if ! defined $self->{session};
        }
    } else {
        $self->error("Only username/password supported for now");
        return;
    }

    return $resp;
}

=item logout

Logout from current session

=cut

sub logout
{
    my ($self) = @_;

    my $resp;
    if ($self->{session}) {
        my $req = mkrequest($self->{session}, 'DELETE');
        $resp = $self->rest($req);
    } else {
        $self->error("No sessions found");
        return;
    }

    return $resp;
}

=pod

=back

=cut

1;
