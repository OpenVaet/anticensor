package threadreadermirror;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Bcrypt;
use Mojolicious::Static;
use Mojo::IOLoop;
use DBI;
use JSON;
use Cwd;
use Data::Printer;
# use Digest::MD5 qw(md5_hex);
use FindBin;
use lib "$FindBin::Bin/../../lib";
use config;

# This method will run once at server start
sub startup () {

    my $self = shift;
    $self->plugin('Config');
    $self->config(
        hypnotoad => {
            listen => ['http://*:8084']
        },
    );

    # load and configure CORS
    $self->plugin('SecureCORS');
    $self->plugin('SecureCORS', { max_age => undef });
    $self->plugin('RemoteAddr');

    # set app-wide CORS defaults
    $self->hook(
        before_dispatch => sub {
            my $c = shift;
            $c->res->headers->header('Access-Control-Allow-Origin' => '*');
            $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, POST, OPTIONS');
            $c->res->headers->access_control_allow_origin('*');
            my $forwardBase = $c->req->headers->header('X-Forwarded-Base');
            $c->req->url->base(Mojo::URL->new($forwardBase)) if $forwardBase;
        }
    );
    $self->hook(
        after_dispatch => sub { 
            my $c        = shift;
            my $referrer = $c->req->headers->referrer || '';
            my $method   = $c->req->method || '';
            if ($method eq 'OPTIONS') {
                $c->res->headers->header('Access-Control-Allow-Origin' => '*'); 
                $c->res->headers->access_control_allow_origin('*');
                $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, POST, OPTIONS');
                $c->res->headers->header('Access-Control-Allow-Headers' => 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
                $c->respond_to(any => { data => '', status => 200 });
            }
        }
    );

    # Load configuration from hash returned by config file
    my $config = \%config;
    $self->helper(config => sub {return $config});
    $self->plugin('RemoteAddr');

    # Configure the application
    $self->secrets($config->{'secrets'});

    # Router
    my $r = $self->routes;

    ######################## Unprotected routes
    $r->get('/')->to('index#index');
}

sub connect_dbi
{
    my ($config) = shift;
    return DBI->connect("DBI:mysql:database=" . $config->{databaseName} . ";" .
                        "host=" . $config->{databaseHost} . ";port=" . $config->{databasePort},
                        $config->{databaseUser}, $config->{databasePassword},
                        { PrintError => 1}) || die $DBI::errstr;
}

1;
