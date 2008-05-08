package Class::Meta::Attribute;

# $Id$

=head1 NAME

Class::Meta::Attribute - Class::Meta class attribute introspection

=head1 SYNOPSIS

  # Assuming MyApp::Thingy was generated by Class::Meta.
  my $class = MyApp::Thingy->my_class;
  my $thingy = MyApp::Thingy->new;

  print "\nAttributes:\n";
  for my $attr ($class->attributes) {
      print "  o ", $attr->name, " => ", $attr->get($thingy), $/;
      if ($attr->authz >= Class::Meta::SET && $attr->type eq 'string') {
          $attr->get($thingy, 'hey there!');
          print "    Changed to: ", $attr->get($thingy) $/;
      }
  }

=head1 DESCRIPTION

An object of this class describes an attribute of a class created by
Class::Meta. It includes metadata such as the name of the attribute, its data
type, its accessibility, and whether or not a value is required. It also
provides methods to easily get and set the value of the attribute for a given
instance of the class.

Class::Meta::Attribute objects are created by Class::Meta; they are never
instantiated directly in client code. To access the attribute objects for a
Class::Meta-generated class, simply call its C<my_class()> method to retrieve
its Class::Meta::Class object, and then call the C<attributes()> method on the
Class::Meta::Class object.

=cut

##############################################################################
# Dependencies                                                               #
##############################################################################
use strict;

##############################################################################
# Package Globals                                                            #
##############################################################################
our $VERSION = '0.60';

##############################################################################
# Private Package Globals                                                    #
##############################################################################
my %type_pkg_for = (
    map( { $_ => 'Boolean' } qw(bool boolean) ),
    map( { $_ => 'Numeric' } qw(whole integer int decimal dec real float) ),
    map(
        { $_ => 'Perl' }
        qw(scalar scalarref array arrayref hash hashref code coderef closure)
    ),
    string => 'String',
);

##############################################################################
# Constructors                                                               #
##############################################################################

=head1 INTERFACE

=head2 Constructors

=head3 new

A protected method for constructing a Class::Meta::Attribute object. Do not
call this method directly; Call the
L<C<add_attribute()>|Class::Meta/"add_attribute"> method on a Class::Meta
object, instead.

=cut

sub new {
    my $pkg = shift;
    my $class = shift;

    # Check to make sure that only Class::Meta or a subclass is constructing a
    # Class::Meta::Attribute object.
    my $caller = caller;
    Class::Meta->handle_error("Package '$caller' cannot create $pkg "
                              . "objects")
      unless UNIVERSAL::isa($caller, 'Class::Meta')
        || UNIVERSAL::isa($caller, __PACKAGE__);

    # Make sure we can get all the arguments.
    $class->handle_error("Odd number of parameters in call to new() when "
                         . "named parameters were expected")
      if @_ % 2;
    my %p = @_;

    # Validate the name.
    $class->handle_error("Parameter 'name' is required in call to new()")
      unless $p{name};
    # Is this too paranoid?
    $class->handle_error("Attribute '$p{name}' is not a valid attribute "
                         . "name -- only alphanumeric and '_' characters "
                         . "allowed")
      if $p{name} =~ /\W/;

    # Grab the package name.
    $p{package} = $class->{package};

    # Set the required and once attributes.
    for (qw(required once)) {
        $p{$_} = $p{$_} ? 1 : 0;
    }

    # Make sure the name hasn't already been used for another attribute
    $class->handle_error("Attribute '$p{name}' already exists in class '"
                         . $class->{attrs}{$p{name}}{package} . "'")
      if ! delete $p{override} && exists $class->{attrs}{$p{name}};

    # Check the view.
    if (exists $p{view}) {
        $p{view} = Class::Meta::_str_to_const($p{view});
        $class->handle_error(
            "Not a valid view parameter: '$p{view}'"
        ) unless $p{view} == Class::Meta::PUBLIC
          or     $p{view} == Class::Meta::PROTECTED
          or     $p{view} == Class::Meta::TRUSTED
          or     $p{view} == Class::Meta::PRIVATE;
    } else {
        # Make it public by default.
        $p{view} = Class::Meta::PUBLIC;
    }

    # Check the authorization level.
    if (exists $p{authz}) {
        $p{authz} = Class::Meta::_str_to_const($p{authz});
        $class->handle_error(
            "Not a valid authz parameter: '$p{authz}'"
        ) unless $p{authz} == Class::Meta::NONE
          or     $p{authz} == Class::Meta::READ
          or     $p{authz} == Class::Meta::WRITE
          or     $p{authz} == Class::Meta::RDWR;
    } else {
        # Make it read/write by default.
        $p{authz} = Class::Meta::RDWR;
    }

    # Check the creation constant.
    if (exists $p{create}) {
        $p{create} = Class::Meta::_str_to_const($p{create});
        $class->handle_error(
            "Not a valid create parameter: '$p{create}'"
        ) unless $p{create} == Class::Meta::NONE
          or     $p{create} == Class::Meta::GET
          or     $p{create} == Class::Meta::SET
          or     $p{create} == Class::Meta::GETSET;
    } else {
        # Rely on the authz setting by default.
        $p{create} = $p{authz};
    }

    # Check the context.
    if (exists $p{context}) {
        $p{context} = Class::Meta::_str_to_const($p{context});
        $class->handle_error(
            "Not a valid context parameter: '$p{context}'"
        ) unless $p{context} == Class::Meta::OBJECT
          or     $p{context} == Class::Meta::CLASS;
    } else {
        # Put it in object context by default.
        $p{context} = Class::Meta::OBJECT;
    }

    # Check the type.
    $p{type} = delete $p{is} if exists $p{is};
    $p{type} ||= $class->default_type;
    $class->handle_error( "No type specified for the '$p{name}' attribute" )
        unless $p{type};
    unless ( eval { Class::Meta::Type->new($p{type}) } ) {
        my $pkg = $type_pkg_for{ $p{type} }
            or $class->handle_error( "Unknown type: '$p{type}'" );
        eval "require Class::Meta::Types::$pkg";
        $class->handle_error( "Unknown type: '$p{type}'" ) if $@;
        "Class::Meta::Types::$pkg"->import;
    }

    # Check the default.
    if (exists $p{default}) {
        # A code ref should be executed when the default is called.
        $p{_def_code} = delete $p{default}
          if ref $p{default} eq 'CODE';
    }

    # Create and cache the attribute object.
    $class->{attrs}{$p{name}} = bless \%p, ref $pkg || $pkg;

    # Index its view.
    push @{ $class->{all_attr_ord} }, $p{name};
    if ($p{view} > Class::Meta::PRIVATE) {
        push @{$class->{prot_attr_ord}}, $p{name}
          unless $p{view} == Class::Meta::TRUSTED;
        if ($p{view} > Class::Meta::PROTECTED) {
            push @{$class->{trst_attr_ord}}, $p{name};
            push @{$class->{attr_ord}}, $p{name}
              if $p{view} == Class::Meta::PUBLIC;
        }
    }

    # Store a reference to the class object.
    $p{class} = $class;

    # Let 'em have it.
    return $class->{attrs}{$p{name}};
}

##############################################################################
# Instance Methods                                                           #
##############################################################################

=head2 Instance Methods

=head3 name

  my $name = $attr->name;

Returns the name of the attribute.

=head3 type

  my $type = $attr->type;

Returns the name of the attribute's data type. Typical values are "scalar",
"string", and "boolean". See L<Class::Meta|Class::Meta/"Data Types"> for a
complete list.

=head3 is

  if ($attr->is('string')) {
      # ...
  }

A convenience methed for C<< $attr->type eq $type >>.

=head3 desc

  my $desc = $attr->desc;

Returns a description of the attribute.

=head3 label

  my $label = $attr->label;

Returns a label for the attribute, suitable for use in a user interface. It is
distinguished from the attribute name, which functions to name the accessor
methods for the attribute.

=head3 required

  my $req = $attr->required;

Indicates if the attribute is required to have a value.

=head3 once

  my $once = $attr->once;

Indicates whether an attribute value can be set to a defined value only once.

=head3 package

  my $package = $attr->package;

Returns the package name of the class that attribute is associated with.

=head3 view

  my $view = $attr->view;

Returns the view of the attribute, reflecting its visibility. The possible
values are defined by the following constants:

=over 4

=item Class::Meta::PUBLIC

=item Class::Meta::PRIVATE

=item Class::Meta::TRUSTED

=item Class::Meta::PROTECTED

=back

=head3 context

  my $context = $attr->context;

Returns the context of the attribute, essentially whether it is a class or
object attribute. The possible values are defined by the following constants:

=over 4

=item Class::Meta::CLASS

=item Class::Meta::OBJECT

=back

=head3 authz

  my $authz = $attr->authz;

Returns the authorization for the attribute, which determines whether it can be
read or changed. The possible values are defined by the following constants:

=over 4

=item Class::Meta::READ

=item Class::Meta::WRITE

=item Class::Meta::RDWR

=item Class::Meta::NONE

=back

=head3 class

  my $class = $attr->class;

Returns the Class::Meta::Class object that this attribute is associated
with. Note that this object will always represent the class in which the
attribute is defined, and I<not> any of its subclasses.

=cut

sub name     { $_[0]->{name}     }
sub type     { $_[0]->{type}     }
sub desc     { $_[0]->{desc}     }
sub label    { $_[0]->{label}    }
sub required { $_[0]->{required} }
sub once     { $_[0]->{once}     }
sub package  { $_[0]->{package}  }
sub view     { $_[0]->{view}     }
sub context  { $_[0]->{context}  }
sub authz    { $_[0]->{authz}    }
sub class    { $_[0]->{class}    }
sub is       { $_[0]->{type} eq $_[1] }

##############################################################################

=head3 default

  my $default = $attr->default;

Returns the default value for a new instance of this attribute. Since the
default value can be determined dynamically, the value returned by
C<default()> may change on subsequent calls. It all depends on what was
passed for the C<default> parameter in the call to C<add_attribute()> on the
Class::Meta object that generated the class.

=cut

sub default {
    if (my $code = $_[0]->{_def_code}) {
        return $code->();
    }
    return $_[0]->{default};
}

##############################################################################

=head3 get

  my $value = $attr->get($thingy);

This method calls the "get" accessor method on the object passed as the sole
argument and returns the value of the attribute for that object. Note that it
uses a C<goto> to execute the accessor, so the call to C<set()> itself
will not appear in a call stack trace.

=cut

sub get {
    my $self = shift;
    my $code = $self->{_get} or $self->class->handle_error(
        q{Cannot get attribute '}, $self->name, q{'}
    );
    goto &$code;
}

##############################################################################

=head3 set

  $attr->set($thingy, $new_value);

This method calls the "set" accessor method on the object passed as the first
argument and passes any remaining arguments to assign a new value to the
attribute for that object. Note that it uses a C<goto> to execute the
accessor, so the call to C<set()> itself will not appear in a call stack
trace.

=cut

sub set {
    my $self = shift;
    my $code = $self->{_set} or $self->class->handle_error(
        q{Cannot set attribute '}, $self->name, q{'}
    );
    goto &$code;
}

##############################################################################

=head3 build

  $attr->build($class);

This is a protected method, designed to be called only by the Class::Meta
class or a subclass of Class::Meta. It takes a single argument, the
Class::Meta::Class object for the class in which the attribute was defined,
and generates attribute accessors by calling out to the C<make_attr_get()> and
C<make_attr_set()> methods of Class::Meta::Type as appropriate for the
Class::Meta::Attribute object.

Although you should never call this method directly, subclasses of
Class::Meta::Constructor may need to override its behavior.

=cut

sub build {
    my ($self, $class) = @_;

    # Check to make sure that only Class::Meta or a subclass is building
    # attribute accessors.
    my $caller = caller;
    $self->class->handle_error(
        "Package '$caller' cannot call " . ref($self) . "->build"
    ) unless UNIVERSAL::isa($caller, 'Class::Meta')
          || UNIVERSAL::isa($caller, __PACKAGE__);

    # Get the data type object and build any accessors.
    my $type = Class::Meta::Type->new($self->{type});
    $self->{type} = $type->key;
    my $create = delete $self->{create};
    $type->build($class->{package}, $self, $create)
        if $create != Class::Meta::NONE;

    # Create the attribute object get code reference.
    if ($self->{authz} >= Class::Meta::READ) {
        $self->{_get} = $type->make_attr_get($self);
    }

    # Create the attribute object set code reference.
    if ($self->{authz} >= Class::Meta::WRITE) {
        $self->{_set} = $type->make_attr_set($self);
    }

}

1;
__END__

=head1 SUPPORT

This module is stored in an open repository at the following address:

L<https://svn.kineticode.com/Class-Meta/trunk/>

Patches against Class::Meta are welcome. Please send bug reports to
<bug-class-meta@rt.cpan.org>.

=head1 AUTHOR

David Wheeler <david@kineticode.com>

=head1 SEE ALSO

Other classes of interest within the Class::Meta distribution include:

=over 4

=item L<Class::Meta|Class::Meta>

=item L<Class::Meta::Class|Class::Meta::Class>

=item L<Class::Meta::Method|Class::Meta::Method>

=item L<Class::Meta::Constructor|Class::Meta::Constructor>

=item L<Class::Meta::Type|Class::Meta::Type>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002-2008, David Wheeler. Some Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
