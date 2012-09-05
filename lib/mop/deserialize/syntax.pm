package mop::deserialize::syntax;

use 5.014;
use strict;
use warnings;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use Sub::Name 'subname';

use mop::parser;

mop::parser::init_parser_for(__PACKAGE__);

sub setup_for {
    my $class = shift;
    my $pkg   = shift;
    {
        no strict 'refs';
        *{ $pkg . '::class'    } = \&class;
        *{ $pkg . '::role'     } = \&role;
        *{ $pkg . '::method'   } = \&method;
        *{ $pkg . '::has'      } = \&has;
        *{ $pkg . '::BUILD'    } = \&BUILD;
        *{ $pkg . '::DEMOLISH' } = \&DEMOLISH;
        *{ $pkg . '::super'    } = \&super;
    }
}

sub class { }

sub role { }

sub method {
    my ($name, $body) = @_;
    my %methods = %{ get_slot_at($::CLASS, '%methods') };
    set_slot_at($methods{$name}, '$body', \subname($name => $body));
}

sub has {
    my ($name, $ref, $metadata, $default) = @_;
    my %attributes = %{ get_slot_at($::CLASS, '%attributes') };
    set_slot_at(
        $attributes{$name},
        '$initial_value',
        \($default ? \$default : mop::internal::_undef_for_type($name))
    );
}

sub BUILD {
    my ($body) = @_;
    my $method = ${ get_slot_at($::CLASS, '$constructor') };
    set_slot_at($method, '$body', \subname('BUILD' => $body));
}

sub DEMOLISH {
    my ($body) = @_;
    my $method = ${ get_slot_at($::CLASS, '$destructor') };
    set_slot_at($method, '$body', \subname('DEMOLISH' => $body));
}

# this isn't used by the bootstrap anywhere currently, but this may need to be
# figured out if we want to serialize classes in general
sub super { ... }

sub build_class {
    my ($name, $metadata, $caller) = @_;
    no strict 'refs';
    return ${ '::' . $name };
}

sub build_role {
    my ($name, $metadata, $caller) = @_;
    no strict 'refs';
    return ${ '::' . $name };
}

sub finalize_class {
    my ($name, $class, $caller) = @_;

    my $stash = get_stash_for($class);
    my $methods = {
        (map { %{ get_slot_at($_, '%methods') } }
             (${ get_slot_at($class, '$superclass') } || ()),
             @{ get_slot_at($class, '@roles') },
             $class),
    };

    %$stash = ();

    for my $name (keys %$methods) {
        my $method = $methods->{$name};
        $stash->add_method($name => sub { $method->execute(@_) });
    }

    my $attribute_stash = get_stash_for($::Attribute);
    my $method_stash = get_stash_for($::Method);
    for my $attribute (values %{ get_slot_at($class, '%attributes') }) {
        $attribute_stash->bless($attribute);
    }
    for my $method (values %{ get_slot_at($class, '%methods') }) {
        $method_stash->bless($method);
    }

    $stash->add_method(DESTROY => mop::internal::generate_DESTROY());

    mop::internal::_apply_overloading($stash);

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::${name}"} = subname($name => sub () { $class });
    }
}

sub finalize_role {
    my ($name, $role, $caller) = @_;

    my $attribute_stash = get_stash_for($::Attribute);
    my $method_stash = get_stash_for($::Method);
    for my $attribute (values %{ get_slot_at($role, '%attributes') }) {
        $attribute_stash->bless($attribute);
    }
    for my $method (values %{ get_slot_at($role, '%methods') }) {
        $method_stash->bless($method);
    }

    {
        no strict 'refs';
        no warnings 'redefine';
        *{"${caller}::${name}"} = subname($name => sub () { $role });
    }
}

sub get_slot_at   { mop::internal::instance::get_slot_at(@_) }
sub set_slot_at   { mop::internal::instance::set_slot_at(@_) }
sub get_stash_for { mop::internal::get_stash_for(@_) }

1;
