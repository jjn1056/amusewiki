package AmuseWikiFarm::Schema::ResultSet::Category;

use utf8;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

__PACKAGE__->load_components('Helper::ResultSet::Random');

=head1 NAME

AmuseWikiFarm::Schema::ResultSet::Category - Category resultset

=head1 METHODS

=head2 by_type($type)

Return the sorted categories of a given type.

=cut

sub by_type {
    my ($self, $type) = @_;
    return $self->search({ type => $type },
                         { order_by => [qw/sorting_pos
                                           name/] });
}

=head2 active_only_by_type($type)

Return the sorted categories of a given type (C<author> or C<topic>)
which have a text count greater than 0.

=cut

sub active_only_by_type {
    my ($self, $type) = @_;
    return $self->search({
                          type => $type,
                          text_count => { '>' => 0 },
                         },
                         {
                          order_by => [qw/sorting_pos name/],
                         });
}

sub active_only_by_type_no_site {
    my ($self, $type) = @_;
    return $self->search({
                          type => $type,
                          text_count => { '>' => 0 },
                         });
}

=head2 by_type_and_uri($type, $uri)

Return the category which corresponds to type and uri

=cut


sub by_type_and_uri {
    my ($self, $type, $uri) = @_;
    return $self->single({type => $type,
                          uri  => $uri});
}

=head2 active_only

Filter the categories which have text_count > 0

=cut


sub active_only {
    return shift->search({ text_count => { '>' => 0 }});
}

=head2 min_texts($integer)

=cut

sub min_texts {
    my ($self, $num) = @_;
    my $me = $self->current_source_alias;
    my $limit = 0;
    if ($num and $num =~ m/\A([1-9][0-9]*)\z/) {
        $limit = $num - 1;
    }
    return $self->search({ "$me.text_count" => { '>' => $limit }});
}


=head2 listing_tokens

Use HRI to pull the data and select only some columns.

=cut

sub listing_tokens {
    my $self = shift;
    my @all = $self->search(undef, {
                                    columns => [qw/type uri name text_count/],
                                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                                   });
    foreach my $row (@all) {
        $row->{full_uri} = join('/', '', 'category', $row->{type}, $row->{uri});
    }
    return \@all;
}

=head2 authors_count

Return the number of active authors

=cut

sub authors_count {
    my $self = shift;
    return $self->active_only_by_type('author')->count;
}

=head2 topics_count

Return the number of active topics

=cut

sub topics_count {
    my $self = shift;
    return $self->active_only_by_type('topic')->count;
}

sub topics_only {
    return shift->search({ type => 'topic' });
}

sub authors_only {
    return shift->search({ type => 'author' });
}

1;

