#!perl

use strict;
use warnings;
use utf8;
use Test::More tests => 73;
BEGIN { $ENV{DBIX_CONFIG_DIR} = "t" };

use File::Spec::Functions qw/catfile catdir/;
use File::Path qw/make_path/;
use Data::Dumper;
use File::Slurp qw/write_file/;
use lib catdir(qw/t lib/);
use AmuseWiki::Tests qw/create_site/;
use AmuseWikiFarm::Schema;

my $schema = AmuseWikiFarm::Schema->connect('amuse');
my $site_id = '0multi0';
my $site = create_site($schema, $site_id);
$site->multilanguage(1);
$site->update->discard_changes;

my $root = $site->repo_root;
my $filedir = catdir($root, qw/a at/);
my $specialdir = catdir($root, 'specials');
make_path($filedir);
make_path($specialdir);

die "$filedir doesn't exist" unless -d $filedir;

my @langs = (qw/en hr it/);
my @uids  = (qw/id1 id2 id3/);

my @texts;
foreach my $lang (@langs) {
    # generate the indexes
    my $index = "index-$lang";
    my $indexfilename = catfile($specialdir, $index . '.muse');
    my $body =<<"MUSE";
#title Index ($lang)
#lang $lang

This is the $lang index

MUSE
    write_file($indexfilename, { binmode => ':encoding(utf-8)' }, $body);

    foreach my $uid (qw/id1 id2 id3/) {
        # create the muse files
        my $basename = "a-test-$uid-$lang";
        push @texts, $basename;
        my $filename = catfile($filedir, $basename . '.muse');
        my $body =<<"MUSE";
#title $lang-$uid
#uid $uid
#lang $lang
#topics Test
#author Marco

Blabla *bla* has uid $uid and lang $lang

MUSE
        write_file($filename, { binmode => ':encoding(utf-8)' }, $body);
    }
}

$site->update_db_from_tree;


use Test::WWW::Mechanize::Catalyst;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'AmuseWikiFarm',
                                               host => "$site_id.amusewiki.org");

$mech->get_ok('/library');

$mech->get_ok('/archive');

foreach my $text (@texts) {
    $mech->content_contains($text);
}

foreach my $path ("/archive", "/topics/test") {
    foreach my $lang (@langs) {
        $mech->get_ok("$path/$lang");
        foreach my $uid (@uids) {
            $mech->content_contains("/library/a-test-$uid-$lang");
        }
        my @others = grep { $_ ne $lang } @langs;
        foreach my $other (@others) {
            foreach my $uid (@uids) {
                $mech->content_lacks("/library/a-test-$uid-$other");
            }
        }
    }
}

$mech->get("/archive/ru");
is $mech->status, "404", "No russian texts, no archive/ru";
$mech->get("/topics/test/ru")
;is $mech->status, "404", "No russian texts, no topics/test/ru";