package Net::Redfish::Request;

use strict;
use warnings;

use base qw(Exporter);
use Readonly;

Readonly our @SUPPORTED_METHODS => qw(DELETE GET PATCH POST PUT);
Readonly our @METHODS_REQUIRE_OPTIONS => qw(PATCH POST PUT);

our @EXPORT = qw(mkrequest);
our @EXPORT_OK = qw(@SUPPORTED_METHODS @METHODS_REQUIRE_OPTIONS $HDR_X_AUTH_TOKEN $ENDPOINT_PREFIX);

use overload bool => '_boolean';

Readonly our $HDR_ACCEPT => 'Accept';
Readonly our $HDR_ACCEPT_ENCODING => 'Accept-Encoding';
Readonly our $HDR_CONTENT_TYPE => 'Content-Type';
Readonly our $HDR_X_AUTH_TOKEN => 'X-Auth-Token';
Readonly our $HDR_X_SUBJECT_TOKEN => 'X-Subject-Token';


Readonly my %DEFAULT_HEADERS => {
    $HDR_CONTENT_TYPE => 'application/json',
    #$HDR_ACCEPT => 'application/json, text/plain',
    #$HDR_ACCEPT_ENCODING => 'identity, gzip, deflate, compress',
};


Readonly our $ENDPOINT_PREFIX => '/redfish/v1';

=head1 NAME

Net::Redfish::Request is an request class for Net::Redfish.

Boolean logic is overloaded using C<_boolean> method (as inverse of C<is_error>).

=head2 Public functions

=over

=item mkrequest

A C<Net::Redfish::Request> factory

=cut

sub mkrequest
{
    return Net::Redfish::Request->new(@_);
}



=pod

=back

=head2 Public methods

=over

=item new

Create new request instance from options for command C<endpoint>
and REST HTTP C<method>.

The C<endpoint> is the URL to use (when it does not start with C</redfish>,
it will be prefixed with C</redfish/v1>.

Options

=over

=item rest: options for rest method

=item raw: payload hashref

=item error: an error (no default)

=item result: result path for the response

=back

=cut

sub new
{
    my ($this, $endpoint, $method, %opts) = @_;
    my $class = ref($this) || $this;

    if (defined $endpoint) {
        if ($endpoint !~ m{^/}) {
            $endpoint = "/$endpoint";
        }

        if ($endpoint !~ m{^/redfish}) {
            $endpoint = "$ENDPOINT_PREFIX$endpoint";
        }

        $endpoint =~ s{/+$}{}; # strip all trailing /
        # add one trailing /, useful to avoid 308/"permanent redirects" with certain BMCs
        $endpoint .= "/";
    } else {
        $opts{error} = 'No endpoint defined';
    }

    my $self = {
        endpoint => $endpoint,

        rest => $opts{rest} || {}, # options for rest
        raw => $opts{raw},

        error => $opts{error}, # no default

        result => $opts{result},
    };

    if (grep {$method eq $_} @SUPPORTED_METHODS) {
        $self->{method} = $method;
    } else {
        $self->{error} = "Unsupported method $method";
    }

    bless $self, $class;

    return $self;
};

=item endpoint

Return endpoint https://<fqdn>/<endpoint>

=cut


sub endpoint
{
    my ($self, $host) = @_;

    # reset error attribute
    $self->{error} = undef;

    if (!defined $host) {
        $self->{error} = "endpoint host argument missing";
        return;
    } else {
        return "https://$host$self->{endpoint}";
    }
}

=item opts_data

Generate hashref from options and paths attribute, to be used for JSON encoding.
If C<raw> attribute is defined, ignore all options and return it.

Returns empty hasref, even if no options existed.

=cut

sub opts_data
{
    my ($self) = @_;

    my $root;

    if ($self->{raw}) {
        # ignore all options passed
        $root = $self->{raw};
    } else {
        $root = {};
        foreach my $key (sort keys %{$self->{opts}}) {
            my @paths = @{$self->{paths}->{$key}};
            my $lastpath = pop(@paths);
            my $here = $root;
            foreach my $path (@paths) {
                # build tree
                $here->{$path} = {} if !exists($here->{$path});
                $here = $here->{$path};
            }
            # no intermediate variable with value
            $here->{$lastpath} = $self->{opts}->{$key};
        }
    }

    return $root;
}

=item headers

Return headers for the request.

Supported options:

=over

=item token: authentication token stored in X-Auth-Token

=item headers: hashref with headers to add that take precedence over the defaults.
Headers with an undef value will be removed.

=back

=cut

sub headers
{
    my ($self, %opts) = @_;

    my $headers = {%DEFAULT_HEADERS};

    while (my ($hdr, $value) = each %{$opts{headers} || {}}) {
        if (defined($value)) {
            $headers->{$hdr} = $value;
        } else {
            delete $headers->{$hdr};
        }
    }

    $headers->{$HDR_X_AUTH_TOKEN} = $opts{token} if defined $opts{token};

    return $headers;
}


=item is_error

Test if this is an error or not (based on error attribute).

=cut

sub is_error
{
    my $self = shift;
    return $self->{error} ? 1 : 0;
}

# Overloaded boolean, inverse of is_error
sub _boolean
{
    my $self = shift;
    return ! $self->is_error();
}

=pod

=back

=cut

1;
