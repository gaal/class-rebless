package Class::Rebless;

require 5.005;
use strict;
use Carp;
use Scalar::Util;

use vars qw($VERSION $RE_BUILTIN $MAX_RECURSE);

$VERSION = '0.09';
$MAX_RECURSE = 1_000;


# MODULE INITIALIZATION

my %subs = (
    rebless => sub {
        my($opts) = @_;
        $opts->{editor} = sub {
            my ($obj, $class) = @_;
            bless $obj, $class;
        };
    },
    rebase  => sub {
        my($opts) = @_;
        $opts->{editor} = sub {
            my ($obj, $class) = @_;
            bless $obj, $class . '::' . ref $obj;
        };
    },
    custom  => sub {
        my($opts) = @_;
        $opts->{editor} or confess "custom reblesser requires an editor";
    },
);

while (my($name, $add_editor_to_opts) = each %subs) {
    no strict 'refs';
    *{__PACKAGE__ . "::$name"} = sub {
        my ($proto, $obj, $namespace, $opts) = @_;

        my $class = ref($proto) || $proto;

        $opts ||= {};
        $add_editor_to_opts->($opts);

        my $level = 0;
        my $seen  = {};

        $class->_recurse($obj, $namespace, $opts, $level, $seen);
    };
}

{
    my $prune;
    sub prune {
        $prune = $_[1] if defined $_[1];
        $prune;
    }
    sub need_prune {
        return if not defined $prune;
        return $_[1] eq $prune;
    }
}

sub _recurse {
    my ($class, $obj, $namespace, $opts, $level, $seen) = @_;

    # If MAX_RECURSE is 10, we should be allowed to recurse ten times before
    # throwing an exception.  That means we only throw an exception at #11.
    die "maximum recursion level exceeded" if $level > $MAX_RECURSE;

    $seen ||= {};

    my $recurse = sub {
        my $who = shift;
        #my $who = $_[0];
        #print ">>>> recurse " . Carp::longmess;

        my $refaddr = Scalar::Util::refaddr($who);
        return if defined $refaddr and $seen->{$refaddr};
        local $seen->{ defined $refaddr ? $refaddr : '' } = 1;

        $class->_recurse($who, $namespace, $opts, $level+1, $seen);
    };

    # rebless this node, possibly pruning (skipping recursion
    # over its children)
    if (Scalar::Util::blessed $obj) {
        my $res = $opts->{editor}->($obj, $namespace); # re{bless,base} ref
        return $obj if $class->need_prune($res);
    }

    my $type = Scalar::Util::reftype $obj;
    return $obj unless defined $type;

    if      ($type eq 'SCALAR') {
        $recurse->($$obj);
    } elsif ($type eq 'ARRAY') {
        for my $elem (@$obj) {
            $recurse->($elem);
        }
    } elsif ($type eq 'HASH') {
        for my $val (values %$obj) {
            $recurse->($val);
        }
    } elsif ($type eq 'GLOB') {
        # Filehandles are GLOBs, but they don't have ARRAY slots!
        # Be paranoid, then, and recurse only on defined slots.

        my $slot;

        if (defined ($slot = *$obj{SCALAR})) {
            $recurse->($$slot);                  # a glob has a scalar...
        }
        if (defined ($slot = *$obj{ARRAY})) {
            for my $elem (@$slot) {              # and an array...
                $recurse->($elem);
            }
        }
        if (defined ($slot = *$obj{HASH})) {
            for my $val (values %$slot) {        # ... and a hash.
                $recurse->($val);
            }
        }
    }
    return $obj;
}

1;


__END__

=head1 NAME

Class::Rebless - Rebase deep data structures

=head1 SYNOPSIS

  use Class::Rebless;

  my $beat = bless({
    one => bless({
      hey => 'ho',
    }, 'AOne'),
    two => bless({
      list => [
        bless({ three => 3 }, 'AThree'),
        bless({ four  => 4 }, 'AFour'),
        5,
        "this is just noise",
      ],
    }, 'ATwo'),
    six => {
      seven => bless({ __VALUE__ => 7}, 'ASeven'),
      eight => bless({ __VALUE__ => 8}, 'AnEight'),
    },
  }, 'AOne');

  Class::Rebless->rebase($beat, 'And');

  # $beat now contains objects of type
  # And::AOne, And::ATwo .. And::AnEight!

  Class::Rebless->rebless($beat, 'Beatless');

  # All (blessed) objects in $beat now belong to package
  # Beatless.

=head1 DESCRIPTION

Class::Rebless takes a Perl data structure and recurses through its
hierarchy, reblessing objects that it finds along the way into new
namespaces. This is typically useful when your object belongs to a
package that is too close to the main namespace for your tastes, and
you want to rebless everything down to your project's base namespace.

Class::Rebless walks scalar, array, and hash references. It uses
Scalar::Util::reftype to discover how to walk blessed objects of any type.


=head2 Methods

Class::Rebless defines B<only class methods>. There is no instance
constructor, and when calling these methods you should take care not
to call them in function form by mistake; that would not do at all.

=over 4

=item B<rebless>

    Class::Rebless->rebless($myobj, "New::Namespace");

Finds all blessed objects refered to by $myobj and reblesses them into
New::Namespace. This completely overrides whatever blessing they had
before.

=item B<rebase>

    Class::Rebless->rebase($myobj, "New::Namespace::Root");

Finds all blessed objects refered to by $myobj and reblesses them into
new namespaces relative to New::Namespace::Root. This overrides whatever
blessing they had before, but unlike B<rebless>, it preseves something
of the original name. So if you had an object blessed into "MyClass",
it will now be blessed into "New::Namespace::Root::MyClass".

=item B<custom>

    Class::Rebless->custom($myobj, "MyName", { editor => \&my_editor });

Per each visited object referenced in $myobj, calls my_editor() on it.
The editor routine is passed the current object in the recursion and
the wanted namespace ("MyName" in the code above).  This lets you to
do anything you like with each object, but is (at least nominally)
intended to allow filtering out objects you don't want to rebless. 3rd
party objetcs, for example:

    my $fh      = IO::File->new("data") or die "open:$!";
    my $frobber = Frotz->new({ source => $fh });
    Class::Rebless->custom($frobber, "SuperFrotz", { editor => \&noio });

    sub noio {
        my($obj, $namespace) = @_;
        return if ref($obj) =~ /^IO::/;

        bless $obj, $namespace . '::' . ref $obj;
    }

(A more realistic example might actually use an inclusion filter, not
an inclusion filter.)

=item B<prune>

    Class::Rebless->prune("__PRUNE__");
    Class::Rebless->custom($myobj, "MyName", { editor => \&pruning_editor });

When pruning is turned on, a custom reblesser has the opportunity to prune
(skip) subtrees in the recursion of $myobj. All it needs to do to signal
this is to return the string set in advance with the prune method.

This feature is useful, like custom, for when you don't want to mess
with members belonging to 3rd party classes that your object might be
holding. Using the noio example above, the "return" can be changed to
"return '__PRUNE__'". Anything the IO object refers to will not be
visited by Class::Rebless.

=back

=head1 CAVEATS

Reblessing a tied object may produce unexpected results.

=head1 AUTHOR

Gaal Yahas E<lt>gaal@forum2.orgE<gt>

Gabor Szabo E<lt>szabgab@gmail.comE<gt> has contributed many tests. Thanks!

Ricardo Signes E<lt>rjbs@cpan.orgE<gt> has contributed bugfixes. Thanks!

=head1 COPYRIGHT (The "MIT" License)

Copyright 2004-2011 Gaal Yahas.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

