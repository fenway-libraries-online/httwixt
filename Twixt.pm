#!/usr/bin/perl

package HTTP::Twixt;

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib/perl5lib";

use Digest;
use Getopt::Long
    qw(:config posix_default gnu_compat require_order bundling no_ignore_case);

use constant VERSION => '0.03';

sub usage;
sub fatal;

my $reqlenlimit = 1<<16;  # Max. 64KB
my %default_config = (
    'uri_base' => $ENV{'HTTWIXT_URI_BASE'} || 'http://localhost',
    'root' => $ENV{'HTTWIXT_ROOT'} || $ENV{'DOCUMENT_ROOT'} || '/var/local/httwixt',
    'public_dir' => 'public',
    'private_dir' => 'private',
    'redirect_status' => '302',
);

if (!defined caller) {
    # Three modes:
    #   - CGI
    #   - FastCGI
    #   - daemon
    #   - inetd/xinetd
    print(VERSION, "\n"), exit 0
        if @ARGV == 1 && $ARGV[0] eq '--version';
    my $config_file;
    my $verbose;
    my $cls;
    my %cmd_config;
    GetOptions(
        'D|daemon' => sub { $cls = __PACKAGE__ . '::Daemon' },
        'I|inetd'  => sub { $cls = __PACKAGE__ . '::Inetd'  },
        'C|cgi'    => sub { $cls = __PACKAGE__ . '::CGI'    },
        'F|fcgi'   => sub { $cls = __PACKAGE__ . '::FCGI'   },
        'T|term'   => sub { $cls = __PACKAGE__ . '::Term'   },
        'c|config-file=s' => \$config_file,
        'u|uri-base=s' => \$cmd_config{'uri_base'},
        'r|root=s' => \$cmd_config{'root'},
        'p|public=s' => \$cmd_config{'public_dir'},
        'q|private=s' => \$cmd_config{'private_dir'},
        's|redirect-status=i' => \$cmd_config{'redirect_status'},
        'v|verbose' => \$cmd_config{'verbose'},
    ) or die;
    $cls ||= 'HTTP::Twixt::' . (
        -t STDERR    ? 'Term'   :
        $0 =~ /fcgi/ ? 'FCGI'   :
        $0 =~ /cgi/  ? 'CGI'    :
        $0 =~ /xtd$/ ? 'Daemon' :
                       'Inetd'
    );
    my $self = bless { %default_config }, $cls;
    my $root = $cmd_config{'root'} ||= $default_config{'root'};
    $config_file = "$root/$config_file"
        if defined $config_file && $config_file !~ m{^/};
    $config_file = -e "$root/httwixt.conf" ? "$root/httwixt.conf" : '/dev/null';
    delete $default_config{'root'};
    %$self = (
        %$self,
        %{ $self->read_config_file($config_file) },
        %cmd_config,
    );
    foreach (qw(public_dir private_dir)) {
        $self->{$_} = "$root/$self->{$_}" if !m{/};
    }
    $self->run;
}

sub new {
    my $cls = shift;
    bless { @_ }, $cls;
}

sub read_config_file {
    my ($self, $f) = @_;
    open my $fh, '<', $f or die "open $f: $!";
    my %config;
    while (<$fh>) {
        if (/^([A-Za-z]\w+)\s+(.+)$/) {
            usage if !exists $default_config{$1};
            $config{$1} = $2;
        }
        elsif (!/^\s*(?:#.*)?$/) {
            die "bad line in config $f: $_";
        }
    }
    return \%config;
}

sub process {
    my ($self) = @_;
    my ($root, $pub, $prv, $red) = @$self{
        qw(root public_dir private_dir redirect_status)
    };
    my ($hash, $url, $tpl) = eval { 
        my $path = $self->read_request;
        $self->publish($path);
    };
    if (defined $tpl) {
        # Return HTML with the temporary URL embedded in it
        my $html = $self->process_template(\$tpl, {
            url => $url,
            root => $root,
            public => $pub,
            private => $prv,
            hash => $hash,
        });
        $self->send_response('200 OK', \$html);
    }
    elsif (defined $url) {
        # Redirect to the desired resource
        $self->send_response("$red Found", { Location => $url }, \"<html>Found</html>\n");
    }
    else {
        # No such resource
        local $_ = $@;
        s/\A|(?<=\n)/|/mgs;
        print STDERR "ERROR\n$_\n" if length > 1;
        $self->send_response('404 Not Found', \"<html>Not found</html>\n");
    }
}

sub run {
    my ($self) = @_;
    $self->check_options;
    $self->process;
}

sub check_options {
    my ($self) = @_;
    # Make sure we have absolute paths to the public and private directories
    my ($root, $pub, $prv, $red) = @$self{
        qw(root public_dir private_dir redirect_status)
    };
    $pub = "$root/$pub" if $pub !~ m{^/};
    $prv = "$root/$prv" if $prv !~ m{^/};
    # Make sure they all exist
    die "no such directory: $root" if !-d $root;
    die "no such directory: $pub"  if !-d $pub;
    die "no such directory: $prv"  if !-d $prv;
    # Redirects must use a 3xx status code
    die if $red !~ /^3[0-9][0-9]$/;
    @$self{
        qw(root public_dir private_dir redirect_status)
    } = ($root, $pub, $prv, $red);
}

sub process_template {
    my ($self, $tplref, $vars) = @_;
    (my $out = $$tplref) =~ s/{{(\w+)}}/$vars->{$1} || ''/eg;
    return $out;
}

sub publish {
    my ($self, $path) = @_;
    my ($root, $pub, $prv, $red) = @$self{
        qw(root public_dir private_dir redirect_status)
    };
    # Read the HTTP request and find the desired file
    die if $path !~ m{/(.+)/([^/\s]+)$};
    my ($coll, $file) = ($1, $2);
    die if !-e "$prv/$coll/$file";
    # Create a "random" URL and published the desired file
    my $hash = $self->digest;
    my ($src, $dst) = ("$prv/$coll", "$pub/$hash");
    die if !mkdir $dst;
    die if !symlink "$src/$file", "$dst/$file";
    # Find a template for the HTTP response
    my $url = join('/', $self->{'uri_base'}, $hash, $file);
    my $tpl = $self->template($coll, $file);
    print STDERR "httwixt: published $prv$path as $pub/$hash/$file\n" if $self->{'verbose'};
    return ($hash, $url, $tpl);
}

sub digest {
    my $dig;
    foreach (qw(SHA-256 SHA-1 MD5)) {
        last if $dig = eval { Digest->new($_) }
    }
    die if !$dig;
    return substr $dig->add(time, $$, rand)->hexdigest, 0, 32;
}

sub template {
    my ($self, $coll, $file) = @_;
    my ($root, $pub, $prv, $red) = @$self{
        qw(root public_dir private_dir redirect_status)
    };
    my $dir = "$prv/$coll";
    my ($tfile) = (
        glob("$dir/$file.httwixt"),
        glob("$dir/httwixt"),
    );
    return if !defined $tfile || !-e $tfile;
    open my $fh, '<', $tfile or die;
    local $/;
    my $tpl = <$fh>;
    die if !defined $tpl;
    return $tpl;
}

sub send_response {
    my $self = shift;
    my ($status, $header, $cref) = $self->response_params(@_);
    my @header = $self->make_header($status, $header, $cref),
    my $crlf = $self->crlf;
    print $_, $crlf for @header, '';
    print $$cref;
}

sub make_header {
    my ($self, $status, $header, $cref) = @_;
    my $clen = length $$cref;
    my $ctype = 'text/html';
    my @out = (
        $self->status($status),
        "Content-Type: $ctype",
        "Content-Length: $clen",
    );
    while (my ($k, $v) = each %$header) {
        push @out, "$k: $v";
    }
    return @out;
}

sub response_params {
    my $self = shift;
    my $status = shift;
    my ($header, $ctype, $cref) = ({}, 'text/html', \'');
    foreach (@_) {
        my $r = ref $_;
        $header = $_, next if $r eq 'HASH';
        $ctype  = $_, next if $r eq '';
        $cref   = $_, next if $r eq 'SCALAR';
        die;
    }
    $header->{'Content-Type'} = $ctype;
    return ($status, $header, $cref);
}

sub crlf { "\x0d\x0a" }

sub status { "Status: $_[1]" }

# ------------------------------------------------------------------------------

package HTTP::Twixt::Term;

use base qw(HTTP::Twixt);

sub read_request {
    my ($self) = @_;
    print STDERR "Path: " if -t STDIN;
    my $path = <STDIN>;
    print STDERR "\n" if -t STDIN;
    die if !defined $path;
    chomp $path;
    return $path;
}

sub status { "HTTP/1.0 $_[1]" }

sub crlf { "\n" }

# ------------------------------------------------------------------------------

package HTTP::Twixt::Inetd;

use base qw(HTTP::Twixt);

use HTTP::Request;

sub read_request {
    my ($self) = @_;
    my $buf;
    my $n = read(STDIN, $buf, $reqlenlimit) or die;
    die if $n == $reqlenlimit;
    my $req = HTTP::Request->parse($buf);
    die if $req->method ne 'GET';
    my $path = $req->uri->path;
}

sub status { "HTTP/1.0 $_[1]" }

# ------------------------------------------------------------------------------

package HTTP::Twixt::Daemon;

use base qw(Net::Server::HTTP HTTP::Twixt);

sub run {
    my ($self) = @_;
    eval "use Net::Server::HTTP; 1" or die;
    my $config = $self->{'config'} ||= {};
    $config->{'port'} ||= 9999;
    $self->check_options;
    $self->SUPER::run(
        %$config,
        -t STDIN ? (server_type => 'Single') : (),
    );
}

sub read_request {
    eval "use CGI; 1" or die;
    my ($self) = @_;
    my $q = $self->{'_cgi'} = CGI->new;
    return $q->path_info || '/';
}

sub process_http_request {
    my ($self) = @_;
    $self->process;
}

# ------------------------------------------------------------------------------

package HTTP::Twixt::FCGI;

use base qw(HTTP::Twixt);

# ------------------------------------------------------------------------------

package HTTP::Twixt::CGI;

use base qw(HTTP::Twixt);

sub read_request {
    eval "use CGI; 1" or die;
    my ($self) = @_;
    my $q = $self->{'_cgi'} = CGI->new;
    return $q->path_info || '/';
}

# ------------------------------------------------------------------------------

1;
