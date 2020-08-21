package WebService::Clockify;

# ABSTRACT: Access to the Clockify API

our $VERSION = '0.0001';

use Carp;
use DateTime;
use Mojo::JSON qw(decode_json);
use Mojo::URL;
use Mojo::UserAgent;
use Try::Tiny;

use Moo;
use strictures 2;
use namespace::clean;

=head1 SYNOPSIS

  use WebService::Clockify;

  my $w = WebService::Clockify->new(apikey => '1234567890abcdef');

  my $r = $w->user;

  $r = $w->fetch(endpoint => 'projects');

  $r = $w->start_timer(
    billable    => 1,
    description => 'Working on foo()',
    project_id  => '1234567890',
  );
  # Do something cool...
  $r = $w->stop_timer;

=head1 DESCRIPTION

C<WebService::Clockify> provides access to the L<https://clockify.me/developers-api>.

This module is in its infancy and much must be done to have it wrap
every call and parameter in the Clockify API...

=head1 ATTRIBUTES

=head2 apikey

Your required authorized access key.

=cut

has apikey => (
    is       => 'ro',
    required => 1,
);

=head2 user_id

The current user id.  A computed attribute.

=cut

has user_id => (
    is       => 'rw',
    init_arg => undef,
);

=head2 active_workspace

The current user activeWorkspace.  A computed attribute.

=cut

has active_workspace => (
    is       => 'rw',
    init_arg => undef,
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

=cut

=head2 user

  $r = $w->user;

Fetch the user results given the B<apikey> attribute and set the
B<user_id> and B<active_workspace> attributes.

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

=head2 fetch

  $r = $w->fetch(endpoint => $endpoint);
  $r = $w->fetch(endpoint => 'projects', id => $id);

Get the B<endpoint> of the active workspace.

If an B<id> is provided (for the C<projects> endpoint), append it to
the URL.

Supported endpoints are:

  clients
  projects
  tags
  users
  user-groups
  custom-fields

=cut

sub fetch {
    my ($self, %args) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/' . $args{endpoint};

    $url .= '/' . $args{id}
        if $args{id};

    my $tx = $self->ua->get($url, { 'X-Api-Key' => $self->apikey });

    my $data = _handle_response($tx);

    return $data;
}

=head2 add

  $r = $w->add(endpoint => $endpoint, payload => $payload);

Add a new item of type B<endpoint> given the B<payload>.

Supported endpoints are:

  clients
  projects
  tags
  time-entries
  user-groups
  users
  shared-reports

=cut

sub add {
    my ($self, %args) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/user/' . $self->user_id
        . '/' . $args{endpoint};

    my $tx = $self->ua->post($url, { 'X-Api-Key' => $self->apikey } => json => $args{payload});

    my $data = _handle_response($tx);

    return $data;
}

=head2 start_timer

  $r = $w->start_timer({
    billable     => $billable,
    description  => $description,
    projectId    => $project_id,
    taskId       => $task_id,
    tagIds       => $tag_ids,
    customFields => $custom_fields,
  });

Start a time entry for the given project on the currently active workspace.

=cut

sub start_timer {
    my ($self, $payload) = @_;

    my $url = $self->base
        . '/workspaces/' . $self->active_workspace
        . '/user/' . $self->user_id
        . '/time-entries';

    $payload->{start} = DateTime->now->iso8601 . 'Z';
    $payload->{description} ||= 'Testing ' . time();

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

L<Carp>

L<DateTime>

L<Mojo::JSON>

L<Mojo::URL>

L<Mojo::UserAgent>

L<Moo>

L<Try::Tiny>

=cut
