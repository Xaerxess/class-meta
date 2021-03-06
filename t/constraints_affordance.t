#!perl -w

##############################################################################
# Set up the tests.
##############################################################################

use strict;
use Test::More tests => 22;

##############################################################################
# Create a simple class.
##############################################################################

package Class::Meta::Testing123;
use strict;

BEGIN {
    main::use_ok('Class::Meta');
    main::use_ok('Class::Meta::Types::String', 'affordance');
}

BEGIN {
    # Import Test::More functions into this package.
    Test::More->import;
    ok( my $cm = Class::Meta->new, "Create new Class::Meta object" );

    # Add a constructor.
    ok( $cm->add_constructor( name => 'new',
                             create  => 1 ),
        "Add constructor" );

    # Add a required attribute with a default
    ok( $cm->add_attribute( name     => 'req_def',
                            type     => 'string',
                            required => 1,
                            default  => 'hello',
                       ),
        "Add required attribute with a default" );

    # Add a once attribute.
    ok( $cm->add_attribute( name => 'once',
                            type => 'string',
                            once => 1,
                       ),
        "Add a once attribute" );

    # Add a once attribute with a default.
    ok( $cm->add_attribute( name    => 'once_def',
                            type    => 'string',
                            once    => 1,
                            default => 'hola',
                       ),
        "Add a once attribute" );

    # Add a required once attribute with a default.
    ok( $cm->add_attribute( name     => 'once_req',
                            type     => 'string',
                            once     => 1,
                            required => 1,
                            default  => 'bonjour',
                       ),
        "Add a required once attribute" );

    # Build the class.
    ok( $cm->build, "Build class" );
}

package main;

ok( my $obj = Class::Meta::Testing123->new, 'Create new object' );

# Check required attribute.
is( $obj->get_req_def, 'hello', 'Check required attribute' );
ok( $obj->set_req_def('foo'), 'Set required attribute' );
is( $obj->get_req_def, 'foo', 'Check required attribute new value' );
eval { $obj->set_req_def(undef) };
ok( $@, 'Catch required exception' );

# Check once attribute.
is( $obj->get_once, undef, "Once is undefined" );
ok( $obj->set_once('hee'), "set once attribute" );
is( $obj->get_once, 'hee', "Check new once value" );
eval { $obj->set_once('ha') };
ok( $@, 'Catch once exception' );

# Check once with a default.
is( $obj->get_once_def, 'hola', 'Check once_def' );
eval { $obj->set_once_def('ha') };
ok( $@, 'Catch once_def exception' );

# Check required once with a default.
is( $obj->get_once_req, 'bonjour', 'Check once_req' );
eval { $obj->set_once_def('ha') };
ok( $@, 'Catch once_req exception' );
