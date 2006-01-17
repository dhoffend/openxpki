use strict;
use warnings;
use English;
use Data::Dumper;
use Test;

# use Smart::Comments;

use Workflow::Factory;

BEGIN { plan tests => 56; };

print STDERR "OpenXPKI::Server::Workflow - Sample workflow instance processing\n";

our $basedir;

print STDERR "OpenXPKI::Server::Workflow\n";

require 't/60_workflow/common.pl';


my $debug = $ENV{DEBUG};
### Debug: $debug

my $factory = Workflow::Factory->instance();

### reading Workflow configuration...
$factory->add_config_from_file(
    workflow  => "$basedir/02_workflow_request_dataonly.xml",
    action    => "$basedir/02_workflow_activity.xml",
    persister => "$basedir/02_workflow_persister.xml",
    );



# interface: user clicks on "Create new data only (basic) request"

# run two workflow tests, one in which the passphrase is supplied by the
# user and one where it is automatically generated
foreach my $testmode (qw( user_supplied_passphrase 
                          autogenerated_passphrase)) {

    ### instantiate new basic request workflow instance...
    my $workflow = $factory->create_workflow('data only certificate request');

    # shortcut for easier context access
    my $context = $workflow->context;
    
    # uncomment to show the workflow instance
    # show_workflow_instance($workflow);

    # interface: find out which fields it has to query from the user

    # interface: fill in the required fields
    # record who created this request
    $context->param(creator  => 'dummy');

    # other parameters
    $context->param(subject  => 'CN=John Doe, DC=example, DC=com');
    $context->param(profile  => 'dummy');
    # $context->param(keytype  => 'DSA');
    # $context->param(keylength  => 1024);
    $context->param(tokentype => 'DEFAULT');
    $context->param(pkirealm  => 'Test Root CA');

    if ($testmode eq "user_supplied_passphrase") {
	$context->param(passphrase  => '123456');
	### User-supplied passphrase: $context->param('passphrase')
    }



    ### run workflow test...

    ### do_step - instantiate request...
    do_step($workflow, 
	    EXPECTED_STATE => 'INITIAL',
	    EXPECTED_ACTIONS => [ 'request.certificate.dataonly.create' ],
	    EXECUTE_ACTION => 'request.certificate.dataonly.create',
	);

    ### do_step - get token...
    do_step($workflow, 
	    EXPECTED_STATE => 'GET_TOKEN',
	    EXPECTED_ACTIONS => [ 'token.get' ],
	    EXECUTE_ACTION => 'token.get',
	);

    ### check if branching the workflow works as expected
    if (! defined $context->param('passphrase')) {
	### passphrase was not present in context - generate it
	### do_step - generate passphrase...
	do_step($workflow, 
		EXPECTED_STATE => 'GENERATE_PASSPHRASE',
		EXPECTED_ACTIONS => [ 'passphrase.generate', ],
		EXECUTE_ACTION => 'passphrase.generate',
	    );
    } else {
	### passphrase was present in context - move on
	### do_step - generate passphrase (null action expected)...
	do_step($workflow, 
		EXPECTED_STATE => 'GENERATE_PASSPHRASE',
		EXPECTED_ACTIONS => [ 'null', ],
		EXECUTE_ACTION => 'null',
	    );
    }

    ### passphrase: $context->param('passphrase')
    ok(defined $context->param('passphrase')
       && ($context->param('passphrase') ne ""));

    ### do_step - generate key...
    do_step($workflow, 
	    EXPECTED_STATE => 'GENERATE_KEY',
	    EXPECTED_ACTIONS => [ 'key.generate', ],
	    EXECUTE_ACTION => 'key.generate',
	);

    ### key: $context->param('key')
    ok($context->param('key') =~ /^-----BEGIN ENCRYPTED PRIVATE KEY-----/);

    ### do_step - create request...
    do_step($workflow, 
	    EXPECTED_STATE => 'CREATE_REQUEST',
	    EXPECTED_ACTIONS => [ 'request.certificate.pkcs10.create', ],
	    EXECUTE_ACTION => 'request.certificate.pkcs10.create',
	);


    ### PKCS10 request: $context->param('pkcs10request')
    ok($context->param('pkcs10request') =~ /^-----BEGIN CERTIFICATE REQUEST-----/);

    ### do_step - finished...
    do_step($workflow, 
	    EXPECTED_STATE => 'FINISHED',
	    EXPECTED_ACTIONS => [  ],
	);

    ## $context

}


1;
