package WebService::Clockify;

# ABSTRACT: Access to the Clockify API

our $VERSION = '0.0001';

use Moo;
use strictures 2;
use namespace::clean;

use Carp;
use DateTime;
use Mojo::UserAgent;
use Mojo::JSON::MaybeXS;
use Mojo::JSON qw(decode_json);
use Mojo::URL;
use Try::Tiny;

=head1 SYNOPSIS

  use WebService::Clockify;

  my $w = WebService::Clockify->new(apikey => '1234567890abcdefghij');

  my $r = $w->user;

  $r = $w->projects;

  $r = $w->start_timer(
    billable    => 1,
    description => 'Working on foo()',
    project_id  => '1234567890',
  );
  # Do something cool...
  $r = $w->stop_timer;

=head1 DESCRIPTION

C<WebService::Clockify> provides access to the L<https://clockify.me/developers-api>.

=head1 ATTRIBUTES

=head2 apikey

Your authorized access key.

=cut

has apikey => (
    is => 'ro',
);

=head2 user_id

The current user id.

=cut

has user_id => (
    is => 'rw',
);

=head2 active_workspace

The current user activeWorkspace.

=cut

has active_workspace => (
    is => 'rw',
);

=head2 base

The base URL.

Default: C<https://api.clockify.me/api/v1>

=cut

has base => (
    is      => 'rw',
    default => sub { Mojo::URL->new('https://api.clockify.me/api/v1') },
);

=head2 ua

The user agent.

=cut

has ua => (
    is      => 'rw',
    default => sub { Mojo::UserAgent->new },
);

=head1 METHODS

=head2 new

  $w = WebService::Clockify->new(%arguments);

Create a new C<WebService::Clockify> object.

=for Pod::Coverage BUILD

=cut

sub BUILD {
    my ($self, $args) = @_;
}

=head2 user

  $r = $w->user;

Fetch the user results given the B<apikey> attribute.

=cut

sub user {
    my ($self) = @_;

    my $url = $self->base . '/user';

    my $tx = $self->ua->get($url, { 'X-Api-Key' => $self->apikey });

    my $data = _handle_response($tx);

    $self->user_id($data->{id})
        if $data->{id};

    $self->active_workspace($data->{activeWorkspace})
        if $data->{activeWorkspace};

    return $data;
}

=head2 start_timer

  $r = $w->start_timer(
    billable    => $billable,
    description => $description,
    project_id  => $project_id,
  );

Start a time entry for the given project on the currently active workspace.

=cut

sub start_timer {
    my ($self, %args) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/user/' . $self->user_id
        . '/time-entries';

    my $payload = {
        start       => DateTime->now->iso8601 . 'Z',
        billable    => $args{billable} ? 'true' : 'false',
        description => $args{description} || 'Testing ' . time(),
        projectId   => $args{project_id},
    };

    my $tx = $self->ua->post($url, { 'X-Api-Key' => $self->apikey } => json => $payload);

    my $data = _handle_response($tx);

    return $data;
}

=head2 stop_timer

  $r = $w->stop_timer;

Stop the currently running time entry.

=cut

sub stop_timer {
    my ($self) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/user/' . $self->user_id
        . '/time-entries';

    my $payload = { end => DateTime->now->iso8601 . 'Z' };

    my $tx = $self->ua->patch($url, { 'X-Api-Key' => $self->apikey } => json => $payload);

    my $data = _handle_response($tx);

    return $data;
}

=head2 projects

  $r = $w->projects;

Get the projects of the active workspace.

=cut

sub projects {
    my ($self) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/projects';

    my $tx = $self->ua->get($url, { 'X-Api-Key' => $self->apikey });

    my $data = _handle_response($tx);

    return $data;
}

sub _handle_response {
    my ($tx) = @_;

    my $data;

    my $res = $tx->result;

    if ( $res->is_success ) {
        my $body = $res->body;
        try {
            $data = decode_json($body);
        }
        catch {
            croak $body, "\n";
        };
    }
    else {
        croak "Connection error: ", $res->message;
    }

    return $data;
}

1;
__END__

=head1 SEE ALSO

L<https://clockify.me/developers-api>

L<Moo>

L<Mojo::JSON>

L<Mojo::JSON::MaybeXS>

L<Mojo::UserAgent>

L<Mojo::URL>

=cut
