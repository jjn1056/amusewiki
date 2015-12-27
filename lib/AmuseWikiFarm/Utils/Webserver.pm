package AmuseWikiFarm::Utils::Webserver;

use strict;
use warnings;
use Moose;
use namespace::autoclean;

use AmuseWikiFarm::Log::Contextual;
use AmuseWikiFarm::Archive::CgitProxy;
use File::Spec;
use File::Temp ();
use Cwd;

has cgit_port => (is => 'ro',
                  isa => 'Int',
                  default => sub { '9015' },
                 );

has log_format => (is => 'ro',
                   isa => 'Str',
                   default => sub { 'combined' });

has nginx_root => (is => 'ro',
                   isa => 'Str',
                   default => sub { '/etc/nginx' });

has instance_name => (is => 'ro',
                      isa => 'Str',
                      default => sub { 'amusewiki' });

has fcgiwrap_socket => (is => 'ro',
                        isa => 'Str',
                        default => sub { '/var/run/fcgiwrap.socket' });

has cgit_proxy => (is => 'ro',
                   isa => 'Object',
                   lazy => 1,
                   builder => '_build_cgit_proxy');

sub _build_cgit_proxy {
    my $self = shift;
    log_info { "Loading cgitproxy" };
    return AmuseWikiFarm::Archive::CgitProxy->new(port => $self->cgit_port);
}

has ssl_directory => (is => 'ro',
                      isa => 'Str',
                      lazy => 1,
                      builder => '_build_ssl_directory');

sub _build_ssl_directory {
    my $self = shift;
    my $ssl_dir = File::Spec->catdir($self->app_directory, 'ssl');
    unless (-d $ssl_dir) {
        mkdir $ssl_dir or die "Cannot create $ssl_dir $!";
    }
    return $ssl_dir;
}

has app_directory => (is => 'ro',
                      isa => 'Str',
                      lazy => 1,
                      builder => '_build_app_directory');

sub _build_app_directory {
    my $self = shift;
    # check against myself
    my $cwd = getcwd;
    die "Application started from the wrong directory!"
      unless (-f File::Spec->catfile($cwd, qw/lib AmuseWikiFarm Utils Webserver.pm/));
    return $cwd;
}

has ssl_default_key => (is => 'ro',
                        isa => 'Str',
                        lazy => 1,
                        builder => '_build_ssl_default_key');

has ssl_default_cert => (is => 'ro',
                         isa => 'Str',
                         lazy => 1,
                         builder => '_build_ssl_default_cert');

sub _build_ssl_default_cert {
    my $self = shift;
    return File::Spec->catfile($self->ssl_directory,
                               $self->instance_name . '.crt');
}
sub _build_ssl_default_key {
    my $self = shift;
    return File::Spec->catfile($self->ssl_directory,
                               $self->instance_name . '.key');
}

has webserver_root => (is => 'ro',
                       isa => 'Str',
                       lazy => 1,
                       builder => '_build_webserver_root');

sub _build_webserver_root {
    my $self = shift;
    return File::Spec->catdir($self->app_directory, 'root');
}

sub generate_nginx_config {
    my ($self, @sites) = @_;
    return unless @sites;
    my $output_dir = File::Temp
      ->newdir(CLEANUP => 0,
               TMPDIR => 1,
               TEMPLATE => 'nginx-amusewiki-XXXXXXXX')->dirname;
    my $cgit_port = $self->cgit_port;
    my $fcgiwrap_socket = $self->fcgiwrap_socket;
    my $cgit_path = File::Spec->catfile(qw/root git cgit.cgi/);
    my $amw_home = $self->app_directory;
    my $webserver_root = $self->webserver_root;

    # generate the ssl default cert if missing
    if (! -f $self->ssl_default_cert and
        ! -f $self->ssl_default_key) {
        my $hostname_for_cert = $sites[0]->canonical;
        unless (-d $self->ssl_directory) {
            mkdir $self->ssl_directory
              or die "Cannot create " . $self->ssl_directory . " $!";
        }
        system(openssl => req => '-new',
               -newkey => 'rsa:4096',
               -days => '3650',
               -nodes => -x509 => -subj => "/CN=$hostname_for_cert",
               -keyout => $self->ssl_default_key,
               -out => $self->ssl_default_cert) == 0
                 or log_error { "Couldn't generate the ssl certs!" };
        chmod 0600, $self->ssl_default_key;
    }

    my $cgit = "### cgit is not installed ###\n";
    if (-f $cgit_path) {
        $cgit = <<"EOF";
server {
    listen 127.0.0.1:$cgit_port;
    server_name localhost;
    location /git/ {
        root $webserver_root;
        fastcgi_split_path_info ^/git()(.*);
        fastcgi_param   PATH_INFO       \$fastcgi_path_info;
        fastcgi_param   SCRIPT_FILENAME \$document_root/git/cgit.cgi;

        fastcgi_param  QUERY_STRING       \$query_string;
        fastcgi_param  REQUEST_METHOD     \$request_method;
        fastcgi_param  CONTENT_TYPE       \$content_type;
        fastcgi_param  CONTENT_LENGTH     \$content_length;

        fastcgi_param  SCRIPT_NAME        \$fastcgi_script_name;
        fastcgi_param  REQUEST_URI        \$request_uri;
        fastcgi_param  DOCUMENT_URI       \$document_uri;
        fastcgi_param  DOCUMENT_ROOT      \$document_root;
        fastcgi_param  SERVER_PROTOCOL    \$server_protocol;
        fastcgi_param  HTTPS              \$https if_not_empty;

        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx/\$nginx_version;

        fastcgi_param  REMOTE_ADDR        \$remote_addr;
        fastcgi_param  REMOTE_PORT        \$remote_port;
        fastcgi_param  SERVER_ADDR        \$server_addr;
        fastcgi_param  SERVER_PORT        \$server_port;
        fastcgi_param  SERVER_NAME        \$server_name;

        fastcgi_pass    unix:$fcgiwrap_socket;
    }
}
EOF
    }
    my $conf_file = File::Spec->catfile($output_dir, $self->instance_name);
    open (my $fhc, '>:encoding(UTF-8)', $conf_file)
      or die "Cannot open $conf_file $!";
    print $fhc $cgit;

    foreach my $site (@sites) {
        print $fhc $self->_insert_server_stanza($site);
    }
    close $fhc;

    my $include_file = File::Spec->catfile($output_dir,
                                           $self->instance_name . '_include');

    open (my $fh, '>:encoding(UTF-8)', $include_file)
      or die "Cannot open $include_file $!";

    print $fh <<"INCLUDE";
    root $webserver_root;

    # LEGACY STUFF
    rewrite ^/lib/(.*)\$ /library/\$1 permanent;
    rewrite ^/HTML/(.*)\\.html\$ /library/\$1 permanent;
    rewrite ^/pdfs/a4/(.*)_a4\\.pdf /library/\$1.pdf permanent;
    rewrite ^/pdfs/letter/(.*)_letter\\.pdf /library/\$1.pdf permanent;
    rewrite ^/pdfs/a4_imposed/(.*)_a4_imposed\\.pdf /library/\$1.a4.pdf permanent;
    rewrite ^/pdfs/letter_imposed/(.*)_letter_imposed\\.pdf /library/\$1.lt.pdf permanent;
    rewrite ^/print/(.*)\\.html /library/\$1.html permanent;
    rewrite ^/epub/(.*)\\.epub /library/\$1.epub permanent;
    rewrite ^/topics/(.*)\\.html /category/topic/\$1 permanent;
    rewrite ^/authors/(.*)\\.html /category/author/\$1 permanent;
    # END LEGACY STUFF

    # deny direct access to the cgi file
    location /git/cgit.cgi {
        deny all;
    }
    location /src/ {
        deny all;
    }
    location /themes/ {
        deny all;
    }
    location /private/repo/ {
        internal;
        alias $amw_home/repo/;
    }
    location /private/bbfiles/ {
        internal;
        alias $amw_home/bbfiles/;
    }
    location /private/staging/ {
        internal;
        alias $amw_home/staging/;
    }
    location / {
        try_files \$uri \@proxy;
        expires max;
    }
    location \@proxy {
        fastcgi_param  QUERY_STRING       \$query_string;
        fastcgi_param  REQUEST_METHOD     \$request_method;
        fastcgi_param  CONTENT_TYPE       \$content_type;
        fastcgi_param  CONTENT_LENGTH     \$content_length;

        fastcgi_param  SCRIPT_NAME        '';
        fastcgi_param  PATH_INFO          \$fastcgi_script_name;
        fastcgi_param  REQUEST_URI        \$request_uri;
        fastcgi_param  DOCUMENT_URI       \$document_uri;
        fastcgi_param  DOCUMENT_ROOT      \$document_root;
        fastcgi_param  SERVER_PROTOCOL    \$server_protocol;
        fastcgi_param  HTTPS              \$https if_not_empty;

        fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
        fastcgi_param  SERVER_SOFTWARE    nginx/\$nginx_version;

        fastcgi_param  REMOTE_ADDR        \$remote_addr;
        fastcgi_param  REMOTE_PORT        \$remote_port;
        fastcgi_param  SERVER_ADDR        \$server_addr;
        fastcgi_param  SERVER_PORT        \$server_port;
        fastcgi_param  SERVER_NAME        \$server_name;

        fastcgi_param HTTP_X_SENDFILE_TYPE X-Accel-Redirect;
        fastcgi_param HTTP_X_ACCEL_MAPPING $amw_home=/private;
        fastcgi_pass  unix:$amw_home/var/amw.sock;
    }
INCLUDE

    close $fh;
    my $nginx_root = $self->nginx_root;
    my $conf_target = File::Spec->catfile($nginx_root, 'sites-enabled',
                                          $self->instance_name);
    my $include_target = File::Spec->catfile($nginx_root,
                                             $self->instance_name . '_include');

    # check if the file differs
    my $directions = '';
    if ($self->_slurp($include_file) ne $self->_slurp($include_target)) {
        $directions .= "diff -Nu $include_target $include_file\n";
        $directions .= "cat $include_file > $include_target\n";
    }
    if ($self->_slurp($conf_target) ne $self->_slurp($conf_file)) {
        $directions .= "diff -Nu $conf_target $conf_file\n";
        $directions .= "cat $conf_file > $conf_target\n";
    }
    if ($directions) {
        $directions .= "nginx -t && service nginx reload\n";
    }
    else {
        # cleanup, not needed
        log_debug { "Config is up-to-date, cleaning up $output_dir" };
        unlink $include_file or log_warn { "Cannot remove $include_file $!" };
        unlink $conf_file or log_warn { "Cannot remove $conf_file $!" };
        rmdir $output_dir or log_warn { "Cannot remove $output_dir $!" };
    }
    return $directions;
}

sub _insert_server_stanza {
    my ($self, $site) = @_;
    my $canonical = $site->canonical;
    my @vhosts = $site->alternate_hostnames;
    my $hosts = join("\n" . (" " x 16),  $canonical, @vhosts);
    my $out = '';
    my $redirect_to_secure;
    my $default_key = $self->ssl_default_key;
    my $default_crt = $self->ssl_default_cert;

    # look if the user set this in the db or we have let's encrypt material,
    # or we have a pair in ssl/<domain>/{key.pem,fullchain.pem}
    my $site_key = $site->ssl_key ? File::Spec->rel2abs($site->ssl_key, $self->nginx_root)
      : File::Spec->catfile($self->ssl_directory, $canonical, 'key.pem');
    my $site_crt = $site->ssl_chained_cert ? File::Spec->rel2abs($site->ssl_chained_cert, $self->nginx_root)
      : File::Spec->catfile($self->ssl_directory, $canonical,'fullchain.pem');

    my $amwbase = $self->instance_name;
    $out = <<"DEFAULT";
    listen 80;
    listen 443 ssl;
    ssl_certificate_key $default_key;
    ssl_certificate     $default_crt;
DEFAULT

    # check in ssl
    if (-f $site_key and -f $site_crt) {
        $out = '';
        if ($site->secure_site_only) {
            $redirect_to_secure = 1;
        }
        else {
            $out .= "    listen 80;\n";
        }
        $out .= "    listen 443 ssl;\n";
        $out .= "    ssl_certificate_key $site_key;\n";
        $out .= "    ssl_certificate     $site_crt;\n";
    }

    $out .= "    server_name $hosts;\n";
    if (my $logformat = $self->log_format) {
        $out .= "    access_log /var/log/nginx/$canonical.log $logformat;\n";
    }
    $out .= "    include ${amwbase}_include;\n";
    my $stanza = "server {\n$out\n}\n";
    if ($redirect_to_secure) {
        $stanza .= <<"REDIRECT";
server {
    listen 80;
    server_name $hosts;
    return 301 https://$canonical\$request_uri;
}
REDIRECT
    }
    $stanza .= "\n";
    return $stanza;
}

sub _slurp {
    my ($self, $file) = @_;
    die "Bad usage" unless $file;
    return '' unless -f $file;
    open (my $fh, '<:encoding(UTF-8)', $file) or die "Cannot open $file!";
    local $/ = undef;
    my $content = <$fh>;
    close $fh;
    return $content;
}



__PACKAGE__->meta->make_immutable;


1;
