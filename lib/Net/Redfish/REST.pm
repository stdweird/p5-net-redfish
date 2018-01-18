package Net::Redfish::REST;

use strict;
use warnings;

use Net::Redfish::Request qw(mkrequest @METHODS_REQUIRE_OPTIONS);
use Net::Redfish::Response;

use REST::Client;
use LWP::UserAgent;
use JSON::XS;

use version;
use Readonly;
use Data::Dumper;


# JSON::XS instance
# sort the keys, to create reproducable results
my $json = JSON::XS->new()->canonical(1);

=head1 methods

=over

=item _new_client

Arguments

=over

=item hostname

=back

Options

=over

=item verify: verify certificate hostname when true (or undefined).

=back

=cut

sub _new_client
{
    my ($self, $hostname, %opts) = @_;

    my $browser = LWP::UserAgent->new();
    # Temporary cookie_jar
    $browser->cookie_jar( {} );

    my $verify = (!defined($opts{verify}) || $opts{verify}) ? 1 : 0;
    $browser->ssl_opts(verify_hostname => $verify);

    my $rc = REST::Client->new(
        useragent => $browser,
        );

    $self->{rc} = $rc;
    $self->{host} = $hostname;

    # attributes set by services method
    $self->{version} = version->new('v0.0.0');
    $self->{services} = {root => '/'};
}

=item services

Discover and update services

Options

=over

=item response: pass response to use.

=back

=cut

sub services
{
    my ($self, $service, %opts) = @_;

    my $resp = $opts{response};
    if (defined($resp)) {
        $self->debug("Using existing response for service $service");
    } else {
        $resp = $self->response($service, 'GET');
    };

    if ($resp) {
        foreach my $service (@{$resp->services}) {
            my $name = join('/', @{$service->[0]});
            my $value = $service->[1];
            if (exists($self->{services}->{$name}) and
                $self->{services}->{$name} ne $value) {
                $self->error("Duplicate service $name found: keeping existing value, skipping $value");
            } else {
                $self->{services}->{$name} = $value;
            }
        }
    } else {
        $self->error("Cannot determine services from invalid response");
    }

    return $resp;
}


=item version

Extract and set the version (from the root request).

=cut

sub set_version
{
    my ($self, $resp) = @_;

    my $version;
    if ($resp and
        exists $resp->{data}->{RedfishVersion}) {
        $version = version->new("v".$resp->{data}->{RedfishVersion});
        $self->{version} = $version;
        $self->info("Redfish version $version found");
    } else {
        $self->warn("Unable to determine version");
    };

    return $version;
}

=item discover_root

Get and parse the root (no login required).

=cut

sub discover_root
{
    my ($self) = @_;

    my $resp = $self->response('root', 'GET');

    # version
    $self->set_version($resp);
    # services
    $self->services('root', response => $resp);

    return 1;
}

=item discover

Gather more services (requires login).

=cut

sub discover
{
    my ($self) = @_;

    # Update more services
    foreach my $svs (qw(AccountService)) {
        $self->services($svs);
    }

    return 1;
};


=item members

Gather the members of a collection (using known service).
Returns list of response instances (one for each member).

=cut

sub members
{
    my ($self, $collection) = @_;

    my $resp = $self->response($collection) or return;

    my @res;

    my @members = @{$resp->members};
    if (@members) {
        if (scalar @members > 1) {
            $self->warn("More than one set of members for collection $collection:" .
                        join(", ", map {join('/', @{$_->[0]})} @members).
                        ". Only using first one.");
        }
        my $member = $members[0];
        $self->debug("Collection $collection member ".join('/', @{$member->[0]}));

        foreach my $endpt (@{$member->[1]}) {
            $resp = $self->rest(mkrequest($endpt, 'GET'));
            push (@res, $resp->result) if $resp;
        }
    }
    return \@res;
}

=item request

Return a request instance, with endpoint based on discovered services

Options

=over

=item suffix: additional endpoint suffix

=item all other options are passed to C<mkrequest>

=back

=cut

sub request
{
    my ($self, $service, $method, %opts) = @_;

    my $endpoint = $self->{services}->{$service};
    if ($endpoint) {
        $endpoint =~ s{/+$}{};
        my $suffix = delete $opts{suffix};
        if (defined($suffix)) {
            $suffix =~ s{^/+}{};
            $suffix =~ s{/+$}{};
            $endpoint .= "/$suffix";
        }
        $self->debug("request service $service suffix $suffix endpoint $endpoint");
        return mkrequest($endpoint, $method, %opts);
    } else {
        $self->error("No service $service found in discovered services");
        return;
    }
}

=item response

Make request and return the response.
All arguments and options are passed to the C<request> method.

=cut

sub response
{
    my $self = shift;
    my $req = $self->request(@_);
    return $self->rest($req);
}

# single line dumper
sub _clean_dump
{
    my $dumper = Data::Dumper->new([@_]);
    $dumper->Indent(1);
    $dumper->Sortkeys(1);
    $dumper->Deepcopy(1);

    my $txt = $dumper->Dump;
    $txt =~ s/^\$VAR\d+\s*=\s*//;
    $txt =~ s/;$//;
    return $txt;
}

# Actual REST::Client call
# Returns tuple repsonse, repsonse headers and error message.
# Processes the repsonse code, including possible JSON decoding
# Reports error and returns err (with repsonse undef)
sub _call
{
    my ($self, $method, $url, $success, @args) = @_;

    my $err;
    my $rc = $self->{rc};

    # make the call
    $rc->$method($url, @args);

    my $code = $rc->responseCode();
    my $content = $rc->responseContent();
    my $rheaders = {map {$_ => defined($rc->responseHeader($_)) ? $rc->responseHeader($_) : '<undef>'} $rc->responseHeaders};
    my $headers_txt = join(',', map {"$_=$rheaders->{$_}"} sort keys %$rheaders);

    my $response;

    if (grep {$_ == $code} @$success) {
        my $type = $rheaders->{'Content-Type'} || 'RESPONSE_WO_CONTENT_TYPE_HEADER';
        if ($type =~ qr{^application/json}i) {
            $response = $json->decode($content);
        } else {
            $response = $content;
        }
        $self->debug("Successful REST $method url $url type $type");
        if ($self->{debugapi}) {
            # might contain sensitive data, eg security token
            $self->debug("REST $method full response headers $headers_txt");
            $self->debug("REST $method full response content $content");
            if ($self->{unittest}) {
                $self->debug("REST $method unittest \${}{headers}="._clean_dump($rheaders));
                $self->debug("REST $method unittest \${}{result}="._clean_dump($response));
            }
        }
    } else {
        $err = "$method failed (url $url code $code)";
        $content = '<undef>' if ! defined($content);
        $self->error("REST $err headers $headers_txt: $content");
    }

    return $response, $rheaders, $err;
}



=item rest

Given a Request instance C<req>, perform this request.
All options are passed to the headers method.
The token option is added if the token attribute exists and
if not token option was already in the options.

=cut

sub rest
{
    my ($self, $req, %opts) = @_;

    if (!($req and ref($req) eq 'Net::Redfish::Request')) {
        $self->error("Invalid request");
        return;
    }

    # methods that require options, must pass said option as body
    # general call is $rc->$method($url, [body if options], $headers)

    my $method = $req->{method};

    # url
    my $url = $req->endpoint($self->{host});

    my $success = [200, 201];
    push(@$success, @{$opts{success}}) if exists($opts{success});
    my @args = ($url, $success);

    # body if needed
    my $body;
    if (grep {$method eq $_} @METHODS_REQUIRE_OPTIONS) {
        my $data = $req->opts_data;
        $body = $json->encode($data);
        push(@args, $body);
    }

    # headers
    $opts{token} = $self->{token} if (exists($self->{token}) && !exists $opts{token});
    my $headers = $req->headers(%opts);
    push(@args, $headers);

    $self->debug("REST $method url $url, ".(defined $body ? '' : 'no ')."body, headers ".join(',', sort keys %$headers));
    if ($self->{debugapi}) {
        # might contain sensitive data, eg security token
        my $headers_txt = join(',', map {"$_=$headers->{$_}"} sort keys %$headers);
        $self->debug("REST $method full headers $headers_txt");
        $self->debug("REST $method full body $body") if $body;
        if ($self->{unittest}) {
            $self->debug("REST $method unittest \${}{cmd}='$method $url ".($body ? $body : '')." $headers_txt';");
        }
    }

    my ($response, $rheaders, $err) = $self->_call($method, @args);

    my %ropts = (
        data => $response,
        headers => $rheaders,
        error => $err,
    );
    $ropts{result_path} = $req->{result} if defined $req->{result};
    return mkresponse(%ropts);
}

=pod

=back

=cut

1;
