#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Fast;
use Data::Dumper;
use English;

use JSON;
use MIME::Base64;
use OpenXPKI::Exception;
use OpenXPKI::Client::Simple;
use OpenXPKI::Client::Config;
use OpenXPKI::Serialization::Simple;

use Log::Log4perl;
use Log::Log4perl::MDC;

our $config = OpenXPKI::Client::Config->new('rpc');
my $log = $config->logger();

$log->info("RPC handler initialized");

my $json = new JSON();

sub send_output {

    my $cgi = shift;
    my $result = shift;

    if ($ENV{'HTTP_ACCEPT'} && $ENV{'HTTP_ACCEPT'} eq 'text/plain') {
       print $cgi->header( -type => 'text/plain', charset => 'utf8' );
       if ($result->{error}) {
           print 'error.code=' . $result->{error}->{code}."\n";
           print 'error.message=' . $result->{error}->{message}."\n";
       } else {
           print 'id=' . $result->{result}->{id}."\n";
           print 'state=' . $result->{result}->{state}."\n";
           map { printf "data.%s=%s\n", $_, $result->{result}->{data}->{$_} } keys %{$result->{result}->{data}} if ($result->{result}->{data});
       }

    } else {
        # prepare response header
        print $cgi->header( -type => 'application/json', charset => 'utf8' );
        print $json->encode( $result );
    }

}

while (my $cgi = CGI::Fast->new()) {

    my $conf = $config->config();

    my $method = $cgi->param('method');

    # if method is not set via param check for full body post
    my $postdata;
    if ( !$method && $conf->{input}->{allow_raw_post} && $cgi->param('POSTDATA')) {
        # TODO - evaluate security implications regarding blessed objects
        # and consider to filter out serialized objects for security reasons
        $json->max_depth(  $conf->{input}->{parse_depth} || 5 );
        my $raw = $cgi->param('POSTDATA');
        $log->trace("RPC raw postdata : " . $raw) if ($log->is_trace());
        eval{$postdata = $json->decode($raw);};
        if (!$postdata || $EVAL_ERROR) {
            $log->error("RPC decoding postdata failed: " . $EVAL_ERROR);
            send_output( $cgi,  { error => {
                code => 42,
                message=> "RPC decoding postdata failed",
                data => { pid => $$ }
            }});
            next;
        }
        $method = $postdata->{method};
    }

    $method = $config->route() unless($method);

    # method should be set now
    if ( !$method ) {
        # TODO: Return as "400 Bad Request"?
        $log->error("RPC no method set in request");
        send_output( $cgi,  { error => {
            code => 42,
            message=> "RPC no method set in request",
            data => { pid => $$ }
        }});
        next;
    }

    my $servername = $conf->{$method}->{servername} || '';

    Log::Log4perl::MDC->put('server', $servername);
    Log::Log4perl::MDC->put('endpoint', $config->endpoint());

    my $error = '';


    my $workflow_type = $conf->{$method}->{workflow};
    if ( !defined $workflow_type ) {
        # TODO: Return as "400 Bad Request"?
        $log->error("RPC no workflow_type set for requested method $method");
        send_output( $cgi,  { error => {
            code => 42,
            message=> "RPC no workflow_type set for requested method $method",
            data => { pid => $$ }
        }});
        next;
    }

    # Only parameters which are whitelisted in the config are mapped!
    # This is crucial to prevent injection of server-only parameters
    # like the autoapprove flag...
    my $param;

    if ($conf->{$method}->{param}) {
        my @keys;
        @keys = split /\s*,\s*/, $conf->{$method}->{param};
        foreach my $key (@keys) {

            my $val;
            if ($postdata) {
                $val = $postdata->{$key};
            } else {
                $val = $cgi->param($key);
            }
            next unless (defined $val);

            if (!ref $val) {
                $val =~ s/\A\s+//;
                $val =~ s/\s+\z//;
            }
            $param->{$key} = $val;
        }
    }

    # if given, append to the paramter list
    if ($servername) {
        $param->{'server'} = $servername;
        $param->{'interface'} = 'rpc';
    }

    my %envkeys;
    if ($conf->{$method}->{env}) {
        %envkeys = map {$_ => 1} (split /\s*,\s*/, $conf->{$method}->{env});
    }

    # IP Transport
    if ($envkeys{'client_ip'}) {
        $param->{'client_ip'} = $ENV{REMOTE_ADDR};
    }

    # Gather data from TLS session
    my $auth_dn = '';
    my $auth_pem = '';
    if ( defined $ENV{HTTPS} && lc( $ENV{HTTPS} ) eq 'on' ) {

        $log->debug("calling context is https");
        $auth_dn = $ENV{SSL_CLIENT_S_DN};
        $auth_pem = $ENV{SSL_CLIENT_CERT};
        if ( defined $auth_dn ) {
            $log->info("RPC authenticated client DN: $auth_dn");

            if ($envkeys{'signer_dn'}) {
                $param->{'signer_cert'} = $auth_dn;
            }
            if ($auth_pem && $envkeys{'signer_cert'}) {
                $param->{'signer_cert'} = $auth_pem;
            }
        }
        else {
            $log->debug("RPC unauthenticated (no cert)");
        }
    } else {
        $log->debug("RPC unauthenticated (plain http)");
    }

    $log->trace( "Calling $method on ".$config->endpoint()." with parameters: " . Dumper $param ) if $log->is_trace;

    my $workflow;
    my $client;
    eval {

        # create the client object
        $client = OpenXPKI::Client::Simple->new({
            logger => $log,
            config => $conf->{global}, # realm and locale
            auth => $conf->{auth}, # auth config
        });

        if ( !$client ) {
            # TODO: Return as "500 Internal Server Error"?
            $log->error("Could not instantiate client object");
            send_output( $cgi,  { error => {
                code => 42,
                message=> "Could not instantiate client object",
                data => { pid => $$ }
            }});
            next;
        }

        my $wf_id;
        # check for pickup parameter
        if ($conf->{$method}->{pickup}) {
            my $pickup_key = $conf->{$method}->{pickup};
            my $pickup_value;
            if ($postdata) {
                $pickup_value = $postdata->{$pickup_key};
            } else {
                $pickup_value = $cgi->param($pickup_key);
            }

            if ($pickup_value) {
                $log->debug("Pickup workflow with $pickup_key => $pickup_value" );
                my $wfl = $client->run_command('search_workflow_instances', {
                    type => $workflow_type,
                    attribute => { $pickup_key => $pickup_value },
                    limit => 2
                });

                if (@$wfl > 1) {
                    die "Unable to pickup workflow - ambigous search result";
                } elsif (@$wfl == 1) {
                    $wf_id = $wfl->[0]->{workflow_id};
                }
            }
        }

        if ($wf_id) {
            $workflow = $client->handle_workflow({
                TYPE => $workflow_type,
                ID => $wf_id
            });
        } else {
            $workflow = $client->handle_workflow({
                TYPE => $workflow_type,
                PARAMS => $param
            });
        }

        $log->trace( 'Workflow info '  . Dumper $workflow );
    };

    my $res;
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        # TODO: Return as "500 Internal Server Error"?
        $log->error("Unable to instantiate workflow: ". $exc->message );
        $res = { error => { code => 42, message => $exc->message, data => { pid => $$ } } };
    }
    elsif (my $eval_err = $EVAL_ERROR) {

        # TODO: Return as "500 Internal Server Error"?
        my $error = $client->last_error();
        if ($error) {
            $log->error("Unable to create workflow: ". $error );
            if ($error !~ /I18N_OPENXPKI_UI_/) {
                $error = 'uncaught error';
            }
        } else {
            $log->error("Unable to create workflow: ". $eval_err );
            $error = 'uncaught error';
        }
        $res = { error => { code => 42, message => $error, data => { pid => $$ } } };
    } elsif (( $workflow->{'PROC_STATE'} ne 'finished' && !$workflow->{ID} ) || $workflow->{'PROC_STATE'} eq 'exception') {
        # TODO: Return as "500 Internal Server Error"?
        $log->error("workflow terminated in unexpected state" );
        $res = { error => { code => 42, message => 'workflow terminated in unexpected state', data => { pid => $$, id => $workflow->{ID}, 'state' => $workflow->{'STATE'} } } };
    } else {
        $log->info(sprintf("RPC request was processed properly (Workflow: %01d, State: %s",
            $workflow->{ID}, $workflow->{STATE}) );
        $res = { result => { id => $workflow->{ID}, 'state' => $workflow->{'STATE'},  pid => $$ }};

        # Map context parameters to the response if requested
        if ($conf->{$method}->{output}) {
            $res->{result}->{data} = {};
            my @keys;
            @keys = split /\s*,\s*/, $conf->{$method}->{output};
            $log->debug("Keys " . join(", ", @keys));
            $log->trace("Raw context: ". Dumper $workflow->{CONTEXT});
            foreach my $key (@keys) {
                my $val = $workflow->{CONTEXT}->{$key};
                next unless (defined $val);
                next unless ($val ne '' || ref $val);
                if (OpenXPKI::Serialization::Simple::is_serialized($val)) {
                    $val = OpenXPKI::Serialization::Simple->new()->deserialize( $val );
                }
                $res->{result}->{data}->{$key} = $val;
            }
        }
    }

    send_output( $cgi,  $res );

    if ($client) {
        $client->disconnect();
    }

}


1;

__END__;

=head1 rpc.fcgi

A RPC interface to run workflows

=head1 Configuration

The wrapper uses the OpenXPKI::Client::Config module to load a config
file based on the called script name.

=head2 Basic Configuration

The basic configuration in default.conf must contain log and auth info:

  [global]
  log_config = /etc/openxpki/rpc/log.conf
  log_facility = client.rpc
  socket = /var/openxpki/openxpki.socket

  [auth]
  stack = _System
  pki_realm = ca-one

=head2 Method Invocation

The parameters are expected in the query string or in the body of a
HTTP POST operation (application/x-www-form-urlencoded). A minimal
request must provide the parameter "method". The name of the used method
must match a section in the config file. The section must at least contain
the name of a workflow:

  [RevokeCertificateByIdentifier]
  workflow = status_system

You need to define parameters what parameters should be mapped from the
input to the workflow. Values for the given keys are copied to the
workflow input parameter with the same name. In addition, you can load
certain information from the environment

  [RevokeCertificateByIdentifier]
  workflow = certificate_revocation_request_v2
  param = cert_identifier, reason_code, comment, invalidity_time
  env = signer_cert, signer_dn, client_ip

The keys I<signer_cert/signer_dn> are only available on authenticated TLS
conenctions and are filled with the PEM block and the full subject dn
of the client certificate. Note that this data is only available if the
ExportCertData and StdEnvVars option is set in the apache config!

If the workflow uses endpoint specific configuraton, you must also set the
name of the server using the I<servername> key.

  [RevokeCertificateByIdentifier]
  workflow = certificate_revocation_request_v2
  param = cert_identifier, reason_code, comment, invalidity_time
  env = signer_cert, signer_dn, client_ip
  servername  = myserver

=head2 Response

=head3 Success

The default response does not include any data from the workflow itself,
it just returns the meta information of workflow:

  {"result":{"id":"300287","pid":4375,"state":"SUCCESS"}}';

I<id> is the workflow id, which can be used in the workflow search to
access this workflow, I<state> is the current state of the workflow.
I<pid> is the internal process id and only relevant for extended debug.

Note: A successfull RPC response does not tell you anything about the
status of the requested business process! It just says that the workflow
ran in a technical expected manner.

=head3 Process Information

You can add a list of workflow context items to be exported with the
response:

    [RequestCertificate]
    workflow = certificate_enroll
    param = pkcs10, comment
    output = cert_identifier, error_code

This will add a new section I<data> to the response with the value of the
named context item. Items are only included if they exist.

    {"result":{"id":"300287","pid":4375,"state":"SUCCESS",
        "data":{"cert_identifier":"i7Dvxp7fz_9WZlzf9hW_9tlbF6M"},
    }}

=head3 Error Response

In case the workflow can not be created or terminates with an unexpected
error, the return structure looks different:

 {"error":{"data":{"pid":4567,"id":12345},"code":42,
     "message":"I18N_OPENXPKI_SERVER_ACL_AUTHORIZE_WORKFLOW_CREATE_PERMISSION_DENIED"
 }}

 The message gives a verbose description on what happend, the data node will
 contain the workflow id only in case it was started.

=head2 TLS Authentication

In case you want to use TLS Client authentication you must tell the
webserver to pass the client certificate to the script. For apache,
put the following lines into your SSL Host section:

    <Location /rpc>
        SSLVerifyClient optional
        SSLOptions +StdEnvVars +ExportCertData
    </Location>


