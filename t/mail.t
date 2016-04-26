#!perl

use utf8;
use strict;
use warnings;

BEGIN {
    $ENV{EMAIL_SENDER_TRANSPORT} = 'Test';
    $ENV{DBIX_CONFIG_DIR} = "t";
}

use Test::More tests => 25;
use AmuseWikiFarm::Utils::Mailer;
use Data::Dumper;
use File::Spec::Functions qw/catfile catdir/;
use lib catdir(qw/t lib/);
use AmuseWiki::Tests qw/create_site/;
use AmuseWikiFarm::Schema;
use Test::WWW::Mechanize::Catalyst;

my $mailer = AmuseWikiFarm::Utils::Mailer->new(mkit_location => 't/mkits');

ok($mailer);
ok($mailer->transport);
{
    my $exit = $mailer->send_mail(test => {
                                           from => "Mić <me\@localhost>",
                                           to => "Mać <me\@localhost>",
                                           cc => '',
                                           subject => 'testè',
                                           test => 'Mić Mać Đoè'
                                          });
    ok($exit, "Deliver ok");
}
{
    my $exit = $mailer->send_mail(test => {
                                           from => "Mić <me\@localhost>",
                                           to => "Mać <me\@localhost>",
                                           cc => '',
                                           subject => 'testè',
                                          });
    ok(!$exit, "Deliver not ok");
}


my $site_id = '0mail0';
my $schema = AmuseWikiFarm::Schema->connect('amuse');
my $site = create_site($schema, $site_id);
$site->update({ mail_from => 'root@amusewiki.org', locale => 'hr' });

my $user = $site->update_or_create_user({
                                         username => 'mailer',
                                         password => 'pallino',
                                         email => 'pallino@amusewiki.org',
                                         active   => 1,
                                        });
$user->set_roles([{ role => 'librarian' }]);

my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'AmuseWikiFarm',
                                               host => "$site_id.amusewiki.org");


$mech->get_ok('/login');
$mech->submit_form(form_id => 'login-form',
                   fields => { username => 'mailer',
                               password => 'pallino',
                             },
                   button => 'submit');
$mech->get_ok('/user/create');

$schema->resultset('User')->search({ username => 'newmailer' })->delete;
$mech->submit_form(with_fields => {
                                   username => 'newmailer',
                                   password => 'pazzXXXXXXXXXXXXX',
                                   passwordrepeat => 'pazzXXXXXXXXXXXXX',
                                   email => 'newmailer@amusewiki.org',
                                   emailrepeat => 'newmailer@amusewiki.org',
                                  },
                   button => 'create',
                  );

$mech->get_ok('/logout');
$user->update({ email => '' });
$mech->get_ok('/login');
$mech->submit_form(form_id => 'login-form',
                   fields => { username => 'mailer',
                               password => 'pallino',
                             },
                   button => 'submit');
$mech->get_ok('/user/create');
$schema->resultset('User')->search({ username => 'newmailer' })->delete;
$mech->submit_form(with_fields => {
                                   username => 'newmailer',
                                   password => 'pazzXXXXXXXXXXXXX',
                                   passwordrepeat => 'pazzXXXXXXXXXXXXX',
                                   email => 'newmailer@amusewiki.org',
                                   emailrepeat => 'newmailer@amusewiki.org',
                                  },
                   button => 'create',
                  );



{
    my @mails = Email::Sender::Simple->default_transport->deliveries;
    is scalar(@mails), 3, "3 mails sent";
    if (@mails and my $sent = shift @mails) {
        ok ($sent, "Email sent") and diag $sent->{email}->as_string;
        my $body = $sent->{email}->as_string;
        ok ($body);
        like ($body, qr/Hello there Mi=C4=87 Ma=C4=87 =C4=90o=C3=A8/);
        like ($body, qr/To: =\?UTF-8\?B\?TWHEhw==\?= <me\@localhost>/);
        like ($body, qr/From: =\?UTF-8\?B\?TWnEhw==\?= <me\@localhost>/);
    }
    if (@mails and my $sent = shift @mails) {
        ok ($sent, "The application sent the mail");
        my $body = $sent->{email}->as_string;
        ok ($body);
        diag $body;
        like $body, qr{cc: pallino\@amusewiki.org}i;
        like $body, qr{newmailer.*pazzXXXXXXXXXXXXX}s, "Email body has username and pass";
        is_deeply $sent->{successes}, ['newmailer@amusewiki.org',
                                       'pallino@amusewiki.org' ];
    }
    if (@mails and my $sent = shift @mails) {
        ok ($sent, "The application sent the mail");
        my $body = $sent->{email}->as_string;
        ok ($body);
        diag $body;
        like $body, qr{newmailer.*pazzXXXXXXXXXXXXX}s, "Email body has username and pass";
        unlike $body, qr{cc: pallino\@amusewiki.org}i;
        is_deeply $sent->{successes}, ['newmailer@amusewiki.org' ];
    }

}