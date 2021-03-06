use utf8;
package AmuseWikiFarm::Schema::Result::Job;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

AmuseWikiFarm::Schema::Result::Job - Queue for jobs

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::PassphraseColumn>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "PassphraseColumn");

=head1 TABLE: C<job>

=cut

__PACKAGE__->table("job");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 site_id

  data_type: 'varchar'
  is_foreign_key: 1
  is_nullable: 0
  size: 16

=head2 task

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 payload

  data_type: 'text'
  is_nullable: 1

=head2 status

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 created

  data_type: 'datetime'
  is_nullable: 0

=head2 completed

  data_type: 'datetime'
  is_nullable: 1

=head2 priority

  data_type: 'integer'
  is_nullable: 1

=head2 produced

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 errors

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "site_id",
  { data_type => "varchar", is_foreign_key => 1, is_nullable => 0, size => 16 },
  "task",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "payload",
  { data_type => "text", is_nullable => 1 },
  "status",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "created",
  { data_type => "datetime", is_nullable => 0 },
  "completed",
  { data_type => "datetime", is_nullable => 1 },
  "priority",
  { data_type => "integer", is_nullable => 1 },
  "produced",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "errors",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 job_files

Type: has_many

Related object: L<AmuseWikiFarm::Schema::Result::JobFile>

=cut

__PACKAGE__->has_many(
  "job_files",
  "AmuseWikiFarm::Schema::Result::JobFile",
  { "foreign.job_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 site

Type: belongs_to

Related object: L<AmuseWikiFarm::Schema::Result::Site>

=cut

__PACKAGE__->belongs_to(
  "site",
  "AmuseWikiFarm::Schema::Result::Site",
  { id => "site_id" },
  { is_deferrable => 0, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07042 @ 2016-02-02 09:44:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:z+PYOIN/jkotu1Gh4xEO/Q

use Cwd;
use File::Spec;
use File::Copy qw/copy move/;
use Text::Amuse::Compile::Utils qw/read_file append_file/;
use DateTime;
use JSON qw/to_json
            from_json/;
use AmuseWikiFarm::Archive::BookBuilder;
use AmuseWikiFarm::Log::Contextual;
use AmuseWikiFarm::Utils::Amuse qw/clean_username/;

has bookbuilder => (is => 'ro',
                    isa => 'Maybe[Object]',
                    lazy => 1,
                    builder => '_build_bookbuilder');

sub _build_bookbuilder {
    my $self = shift;
    if ($self->task eq 'bookbuilder') {
        my $bb = AmuseWikiFarm::Archive::BookBuilder->new(%{$self->job_data},
                                                          site => $self->site,
                                                          job_id => $self->id,
                                                         );
        return $bb;
    }
    else {
        return undef;
    }
}

=head2 as_json

Return the json string for the job, ascii encoded.

=head2 as_hashref

Return the job representation as an hashref

=cut

sub as_hashref {
    my $self = shift;
    my $data = {
                  id       => $self->id,
                  site_id  => $self->site_id,
                  task     => $self->task,
                  payload  => from_json($self->payload),
                  status   => $self->status,
                  created  => $self->created->iso8601,
                  # completed => $self->completed->iso8601,
                  priority => $self->priority,
                  produced => $self->produced,
                  errors   => $self->errors,
                  logs     => $self->logs,
                  position => 0,
                 };
    if ($data->{status} eq 'pending') {
        my $pending = $self->result_source->resultset->pending
          ->search({},
                   { columns => [qw/id/] });
        my $found = 0;
        my $position = 0;
        while (my $pend = $pending->next) {
            if ($pend->id eq $self->id) {
                $found = 1;
                last;
            }
            $position++;
        }
        # update the position only if found, there could be a race
        # condition.
        $data->{position} = $position if $found;
    }
    elsif ($data->{status} eq 'completed') {
        $data->{produced} ||= '/';
        if (my $bb = $self->bookbuilder) {
            $data->{message} = 'Your file is ready';
            $data->{sources} = '/custom/' .$bb->sources_filename;
        }
        elsif ($data->{task} eq 'publish') {
            $data->{message} = 'Changes applied';
        }
        else {
            $data->{message} = 'Done';
        }

    }
    return $data;
}

sub as_json {
    my $self = shift;
    return to_json($self->as_hashref, { ascii => 1, pretty => 1 } );
}

=head2 log_file

Return the location of the log file. Beware that the location is
computed in the current directory, but returned as absolute.

=head2 log_dir

Return the B<absolute> path to the log directory (./log/jobs).

=head2 old_log_file

=head2 make_room_for_logs

Ensure that the file doesn't exit yet.

=cut

sub log_dir {
    my $dir = File::Spec->catdir(qw/log jobs/);
    unless (-d $dir) {
        unless (-d 'log') {
            mkdir 'log' or die "Cannot create log dir! $!";
        }
        mkdir $dir or die "Cannot create  $dir $!";
    }
    return File::Spec->rel2abs($dir);
}


sub log_file {
    my $self = shift;
    return File::Spec->catfile($self->log_dir, $self->id . '.log');
}

sub old_log_file {
    my $self = shift;
    my $now = DateTime->now->iso8601;
    $now =~ s/[^0-9a-zA-Z]/-/g;
    $now .= '-' . int(rand(10000));
    return File::Spec->catfile($self->log_dir, $self->id . '-' . $now . '.log');
}

sub make_room_for_logs {
    my $self = shift;
    my $logfile = $self->log_file;
    if (-f $logfile) {
        my $oldfile = $self->old_log_file;
        log_warn { "$logfile exists, renaming to $oldfile" };
        move($logfile, $oldfile) or log_error { "cannot move $logfile to $oldfile $!" };
    }
}

=head2 logs

Return the content of the log file.

=cut

sub logs {
    my $self = shift;
    my $file = $self->log_file;
    if (-f $file) {
        my $log = read_file($file);
        # obfuscate the current directory
        my $cwd = getcwd();
        $log =~ s/$cwd/./g;
        return $log;
    }
    return '';
}

=head2 logger

Return a sub for logging into C<log_file>

=cut

sub logger {
    my $self = shift;
    my $logfile = $self->log_file;
    my $logger = sub {
        append_file($logfile, @_);
    };
    return $logger;
}

=head2 dispatch_job

Inspect the content of the job and do it. This is the main method to
trigger a job.

=cut

sub dispatch_job {
    my $self = shift;
    $self->update({ status => 'taken' });
    my $task = $self->task;
    my $handlers = $self->result_source->resultset->handled_jobs_hashref;
    if ($handlers->{$task}) {
        # catch the warns
        my @warnings;
        local $SIG{__WARN__} = sub {
            push @warnings, @_;
        };
        my $method = "dispatch_job_$task";
        $self->make_room_for_logs;
        my $logger = $self->logger;
        $logger->("Job $task started at " . localtime() . "\n");
        my $output;
        eval {
            $output = $self->$method($logger);
        };
        if ($@) {
            $self->status('failed');
            $self->errors($@);
            log_error { $@ };
        }
        else {
            $self->completed(DateTime->now);
            $self->status('completed');
            $self->produced($output);
        }
        if (@warnings) {
            $logger->("WARNINGS intercepted:\n", @warnings);
        }
        $logger->("Job $task finished at " . localtime() . "\n");
    }
    else {
        log_error { "No handler found for $task!" };
        $self->status('failed');
        $self->errors("No handler found for $task!\n");
    }
    $self->update;
}

=head2 job_data

Return the deserialized payload, or an empty hashref.

=cut

sub job_data {
    my $self = shift;
    my $payload = $self->payload;
    return {} unless $payload;
    return from_json($payload);
}

=head2 DISPATCHERS

=head3 dispatch_job_publish

Publish the revision

=head3 dispatch_job_testing

Dummy method

=head3 dispatch_job_git

Git push/pull

=head3 dispatch_job_bookbuilder

Bookbuilder job.

=head3 dispatch_job_purge

Purge an already deleted text.

=cut

sub dispatch_job_purge {
    my ($self, $logger) = @_;
    my $data = $self->job_data;
    my $site = $self->site;
    my $text = $site->titles->find($data->{id});
    die "Couldn't find title $data->{id} in this site!\n" unless $text;
    die $text->title . " is not deleted!\n" unless $text->deleted;
    my $user = $data->{username};
    die "No user!" unless $user;
    my $path = $text->f_full_path_name;
    my $uri = $text->full_uri;
    log_info { "Removing $path, job purged" };
    if (my $git = $site->git) {
        local $ENV{GIT_COMMITTER_NAME}  = $self->committer_name;
        local $ENV{GIT_COMMITTER_EMAIL} = $self->committer_mail;
        local $ENV{GIT_AUTHOR_NAME}  = $self->committer_name;
        local $ENV{GIT_AUTHOR_EMAIL} = $self->committer_mail;
        $git->rm($path);
        $git->commit({ message => "$uri deleted by $user" });
    }
    else {
        unlink $path or die "Couldn't delete $path $!\n";
    }
    $text->delete;
    return '/';
}


sub dispatch_job_publish {
    my ($self, $logger) = @_;
    my $id = $self->job_data->{id};
    Dlog_debug { "job data is $_" } $self->job_data;
    local $ENV{GIT_COMMITTER_NAME}  = $self->committer_name;
    local $ENV{GIT_COMMITTER_EMAIL} = $self->committer_mail;
    # will return the $self->title->full_uri
    return $self->site->revisions->find($id)->publish_text($logger);
}

sub dispatch_job_git {
    my ($self, $logger) = @_;
    my $data = $self->job_data;
    my $site = $self->site;
    my $remote = $data->{remote};
    my $action = $data->{action};
    my $validate = $site->remote_gits_hashref;
    die "Couldn't validate" unless $validate->{$remote}->{$action};
    if ($action eq 'fetch') {
        $site->repo_git_pull($remote, $logger);
        $site->update_db_from_tree($logger);
    }
    elsif ($action eq 'push') {
        $site->repo_git_push($remote, $logger);
    }
    else {
        die "Unhandled action $action!";
    }
    return '/console/git';
}

sub dispatch_job_alias_create {
    my ($self, $logger) = @_;
    my $data = $self->job_data;
    my $site = $self->site;
    my $alias = $site->redirections->update_or_create({
                                                       uri => $data->{src},
                                                       type => $data->{type},
                                                       redirect => $data->{dest},
                                                      });
    unless ($alias->is_a_category) {
        $alias->delete;
        die "Direct creation possible only for categories\n";
    }
    $logger->("Created alias " . $alias->full_src_uri .
              " pointing to " . $alias->full_dest_uri . "\n");
    if (my $cat = $alias->aliased_category) {
        my @texts = $cat->titles;
        my $cat_uri = $cat->full_uri;
        $logger->("Deleting $cat_uri\n");
        $cat->delete;
        if (@texts) {
            $site->compile_and_index_files(\@texts, $logger);
        }
        else {
            $logger->("No texts found in $cat_uri\n");
        }
    }
    else {
        $logger->("No texts found for " . $alias->full_dest_uri . "\n");
    }
    return '/console/alias';
}

sub dispatch_job_alias_delete {
    my ($self, $logger) = @_;
    my $data = $self->job_data;
    my $site = $self->site;
    if (my $alias = $site->redirections->find($data->{id})) {
        die $alias->full_src_uri . " can't be deleted by us\n"
          unless $alias->can_safe_delete;
        my @texts = $alias->linked_texts;
        $alias->delete;
        if (@texts) {
            $site->compile_and_index_files(\@texts, $logger);
        }
        else {
            $logger->("No texts found for " . $alias->full_dest_uri . "\n");
        }
    }
    return '/console/alias';
}

sub dispatch_job_testing {
    my ($self, $logger) = @_;
    log_debug { "Dispatching fake testing job" };
    return;
}

sub produced_files {
    my $self = shift;
    my @out = ($self->log_file);
    foreach my $file ($self->job_files) {
        my $path = $file->path;
        if (-f $path) {
            push @out, $path;
        }
        else {
            Dlog_error { "$path (in produced files) couldn't be found in " . $_ } $self->job_data;
        }
    }
    return @out;
}

sub dispatch_job_bookbuilder {
    my ($self, $logger) = @_;
    my $bb = $self->bookbuilder;
    if (my $file = $bb->compile($logger)) {
        my $schema = $self->result_source->schema;
        my $guard = $schema->txn_scope_guard;
        $self->add_to_job_files({
                                 filename => $bb->produced_filename,
                                 slot => 'produced',
                                });
        $self->add_to_job_files({
                                  filename => $bb->sources_filename,
                                  slot => 'sources',
                                });
        if (my $cover = $bb->coverfile) {
            # we register it here because we usually want to delete
            # this on job removal. *But*, this file can be reused by
            # subsequent jobs. So the latest wins and takes it over.
            if (my $exist = $schema->resultset('JobFile')->find($cover)) {
                $exist->delete;
            }
            $self->add_to_job_files({
                                     filename => $cover,
                                     slot => 'cover',
                                    });
        }
        $guard->commit;
        return '/custom/' . $bb->produced_filename;
    }
    return;
}

before delete => sub {
    my $self = shift;
    my @leftovers = $self->produced_files;
    foreach my $file (@leftovers) {
        log_info { "Unlinking $file after job removal" };
        unlink $file or log_error { "Cannot unlink $file $!" };
    }
};

# same as Result::Revision
sub committer_username {
    my $self = shift;
    return clean_username($self->username);
}
sub committer_name {
    my $self = shift;
    return ucfirst($self->committer_username);
}
sub committer_mail {
    my $self = shift;
    my $hostname = 'localhost';
    if (my $site = $self->site) {
        $hostname = $site->canonical;
    }
    return $self->committer_username . '@' . $hostname;
}

__PACKAGE__->meta->make_immutable;
1;
