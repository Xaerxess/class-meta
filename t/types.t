#!/usr/bin/perl -w

# $Id: types.t,v 1.7 2004/01/07 07:12:03 david Exp $

##############################################################################
# Set up the tests.
##############################################################################

use strict;
use Test::More tests => 56;

##############################################################################
# Create a simple class.
##############################################################################

package Class::Meta::TestTypes;
use strict;
use IO::Socket;

BEGIN {
    $SIG{__DIE__} = \&Carp::confess;
    main::use_ok( 'Class::Meta');
    main::use_ok( 'Class::Meta::Type');
    main::use_ok( 'Class::Meta::Types::Numeric');
    main::use_ok( 'Class::Meta::Types::Perl');
    main::use_ok( 'Class::Meta::Types::String');
    main::use_ok( 'Class::Meta::Types::Boolean');
}

BEGIN {
    # Add the new data type.
    Class::Meta::Type->add( key       => 'io_handle',
                            name      => 'IO Handle',
                            desc      => 'An IO::Handle object.',
                            check     => 'IO::Handle',
                            converter => sub { IO::Handle->new }
                        );

    my $c = Class::Meta->new(package => __PACKAGE__,
                             key     => 'types',
                             name    => 'Class::Meta::TestTypes Class',
                             desc    => 'Just for testing Class::Meta.'
                         );
    $c->add_ctor(name => 'new');

    $c->add_attr( name  => 'name',
                  view   => Class::Meta::PUBLIC,
                  type  => 'string',
                  length   => 256,
                  label => 'Name',
                  field => 'text',
                  desc  => "The person's name.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'age',
                  view   => Class::Meta::PUBLIC,
                  type  => 'integer',
                  label => 'Age',
                  field => 'text',
                  desc  => "The person's age.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'alive',
                  view   => Class::Meta::PUBLIC,
                  type  => 'boolean',
                  label => 'Living',
                  field => 'checkbox',
                  desc  => "Is the person alive?",
                  required   => 0,
                  default   => 1,
              );
    $c->add_attr( name  => 'whole',
                  view   => Class::Meta::PUBLIC,
                  type  => 'whole',
                  label => 'A whole number.',
                  field => 'text',
                  desc  => "A whole number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'dec',
                  view   => Class::Meta::PUBLIC,
                  type  => 'decimal',
                  label => 'A decimal number.',
                  field => 'text',
                  desc  => "A decimal number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'real',
                  view   => Class::Meta::PUBLIC,
                  type  => 'real',
                  label => 'A real number.',
                  field => 'text',
                  desc  => "A real number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'float',
                  view   => Class::Meta::PUBLIC,
                  type  => 'float',
                  label => 'A float.',
                  field => 'text',
                  desc  => "A floating point number.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'scalar',
                  view   => Class::Meta::PUBLIC,
                  type  => 'scalarref',
                  label => 'A scalar.',
                  field => 'text',
                  desc  => "A scalar reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'array',
                  view   => Class::Meta::PUBLIC,
                  type  => 'array',
                  label => 'A array.',
                  field => 'text',
                  desc  => "A array reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'hash',
                  view   => Class::Meta::PUBLIC,
                  type  => 'hash',
                  label => 'A hash.',
                  field => 'text',
                  desc  => "A hash reference.",
                  required   => 0,
                  default   => undef,
                  create   => Class::Meta::GETSET
              );
    $c->add_attr( name  => 'io_handle',
                  view   => Class::Meta::PUBLIC,
                  type  => 'io_handle',
                  label => 'An IO::Handle Object',
                  field => 'text',
                  desc  => 'An IO::Handle object.',
                  required   => 0,
                  default => sub { IO::Handle->new },
                  create   => Class::Meta::GETSET
              );
    $c->build;
}


##############################################################################
# Do the tests.
##############################################################################

package main;
# Instantiate a base class object and test its accessors.
ok( my $t = Class::Meta::TestTypes->new, 'Class::Meta::TestTypes->new');

# Grab its metadata object.
ok( my $class = $t->my_class, "Get the Class::Meta::Class object" );

# Test the is_a() method.
ok( $class->is_a('Class::Meta::TestTypes'), 'Class isa TestTypes');

# Test the key methods.
is( $class->my_key, 'types', 'Key is correct');

# Test the name method.
is( $class->my_name, 'Class::Meta::TestTypes Class', "Name is correct");

# Test the description methods.
is( $class->my_desc, 'Just for testing Class::Meta.',
    "Description is correct");

# Test string.
ok( $t->name('David'), 'name to "David"' );
is( $t->name, 'David', 'name is "David"' );
eval { $t->name([]) };
ok( my $err = $@, 'name to array ref croaks' );
like( $err, qr/^Value .* is not a valid string/, 'correct string exception' );

# Test boolean.
ok( $t->alive, 'alive true');
is( $t->alive(0), 0, 'alive off');
ok( !$t->alive, 'alive false');
ok( $t->alive(1), 'alive on' );
ok( $t->alive, 'alive true again');

# Test whole number.
eval { $t->whole(0) };
ok( $err = $@, 'whole to 0 croaks' );
like( $err, qr/^Value '0' is not a valid whole number/,
     'correct whole number exception' );
ok( $t->whole(1), 'whole to 1.');

# Test integer.
eval { $t->age(0.5) };
ok( $err = $@, 'age to 0.5 croaks');
like( $err, qr/^Value '0\.5' is not a valid integer/,
     'correct integer exception' );
ok( $t->age(10), 'age to 10.');

# Test decimal.
eval { $t->dec('+') };
ok( $err = $@, 'dec to "+" croaks');
like( $err, qr/^Value '\+' is not a valid decimal number/,
     'correct decimal exception' );
ok( $t->dec(3.14), 'dec to 3.14.');

# Test real.
eval { $t->real('+') };
ok( $err = $@, 'real to "+" croaks');
like( $err, qr/^Value '\+' is not a valid real number/,
     'correct real exception' );
ok( $t->real(123.4567), 'real to 123.4567.');
ok( $t->real(-123.4567), 'real to -123.4567.');

# Test float.
eval { $t->float('+') };
ok( $err = $@, 'float to "+" croaks');
like( $err, qr/^Value '\+' is not a valid floating point number/,
     'correct float exception' );
ok( $t->float(1.23e99), 'float to 1.23e99.');

# Test OBJECT with default specifying object type.
ok( my $io = $t->io_handle, 'io_handle' );
isa_ok($io, 'IO::Handle');
eval { $t->io_handle('foo') };
ok( $err = $@, 'io_handle to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid IO Handle/,
     'correct object exception' );

# Try a wrong object.
eval { $t->io_handle($t) };
ok( $err = $@, 'io_handle to \$fh croaks' );
like( $err, qr/^Value '.*' is not a valid IO Handle/,
     'correct object exception' );
ok( $t->io_handle($io), 'io_handle to \$io.');

# Try a subclass.
my $sock = IO::Socket->new;
ok( $t->io_handle($sock), "Set io_handle to a subclass." );
isa_ok($t->io_handle, 'IO::Socket', "Check subclass" );
ok( $t->io_handle($io), 'io_handle to \$io.');

# Test SCALAR.
eval { $t->scalar('foo') };
ok( $err = $@, 'scalar to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Scalar Reference/,
     'correct scalar exception' );
ok( $t->scalar(\"foo"), 'scalar to \\"foo".');

# Test ARRAY.
eval { $t->array('foo') };
ok( $err = $@, 'array to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Array Reference/,
     'correct array exception' );
ok( $t->array(["foo"]), 'array to ["foo"].');

# Test HASH.
eval { $t->hash('foo') };
ok( $err = $@, 'hash to "foo" croaks' );
like( $err, qr/^Value 'foo' is not a valid Hash Reference/,
     'correct hash exception' );
ok( $t->hash({ foo => 1 }), 'hash to { foo => 1 }.');
