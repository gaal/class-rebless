package Class::Rebless;

use strict;
use Carp;
require 5.005;

use vars qw($VERSION $RE_BUILTIN $MAX_RECURSE);

$|++;
$VERSION = '0.01';
$RE_BUILTIN = qr/^(CODE)|(REF)|(GLOB)|(LVALUE)$/o;
$MAX_RECURSE = 1_000;

=pod

=head1 NAME

Class::Rebless - Rebase namespaces, hierarchically

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

Class::Rebless walks scalar, array, and hash references. As of this
early version it assumes all other non-builtin references are objects
with fields implemented as hashrefs and attempts to walk them as such.
This limitation will be addressed in future versions.

=cut

# MODULE INITIALIZATION

my %subs = (
	rebless => sub {
		my ($obj, $class) = @_;
		bless $obj, $class;
	},
	rebase  => sub {
		my ($obj, $class) = @_;
		bless $obj, $class . '::' . ref $obj;
	},
	custom  => undef, # this gets special treatment below
);

for my $method (keys %subs) {
	my $sub;
	if ($method ne 'custom') {
		my $code;           # yay for recursive closures!
		my $editor = $subs{$method};
		$sub = $code = sub {
			my($proto, $obj, $namespace, $opts, $level) = @_;
			$opts ||= {};
			$opts->{code} = $code;
			$opts->{editor} = $editor;
			
			recurse($proto, $obj, $namespace, $opts, $level);
			#goto &recurse; # I wonder why this doesn't work?
		};
	} else {
		my $code;           # yay for recursive closures!
		$sub = $code = sub {
			my($proto, $obj, $namespace, $opts, $level) = @_;
			$opts ||= {};
			$opts->{code} = $code;
			$opts->{editor} or confess "custom reblesser requires an editor";
			
			recurse($proto, $obj, $namespace, $opts, $level);
			#goto &recurse; # I wonder why this doesn't work?
		}
	}
	no strict 'refs';
	*{__PACKAGE__ . "::$method"} = $sub;
}

sub recurse {
	my($proto, $obj, $namespace, $opts, $level) = @_;
	my $class = ref($proto) || $proto;
	$level++;
	die "maximum recursion level exceeded" if $level > $MAX_RECURSE;

	my $recurse = sub {
		my $who = shift;
		#my $who = $_[0];
		#print ">>>> recurse " . Carp::longmess;
		$opts->{code}->($class, $who, $namespace, $opts, $level);
	};

	my $type = ref $obj;
	if      (! $type) {
		; # do nothing
	} elsif ($type eq 'SCALAR') {
		$recurse->($$obj);
	} elsif ($type eq 'ARRAY') {
		for my $elem (@$obj) {
			$recurse->($elem);
		}
	} elsif ($type eq 'HASH') {
		for my $val (values %$obj) {
			$recurse->($val);
		}
	} elsif ($type =~ $RE_BUILTIN) {
		; # do nothing
	} else {
		# TODO: one day we may add prune semantics, and a 'return' based
		# on the result of the following call will be the obvious way to
		# do it. I'm not sure about safety, though. Well, in any case,
		# the possibility of a prune is why the reblessing comes before
		# the recursion.
		$opts->{editor}->($obj, $namespace); # re{bless,base} reference

		# FIXME: the current implementation assumes all classes
		# implement objects as a hashref. This will croak on
		# non-hashref objects!
		for my $val (values %$obj) { # same code as HASH
			$recurse->($val);
		}
	}
	return $obj;
}


=pod

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

=back

=head1 CAVEATS

As mentioned above, the present version assumes any objects it encounters
along the recursion are blessed hashrefs. This will lead to disaster if
a reblessing is attempted on less typical objects.

=head1 TODO

Figure out a way to detect object type.

Add a "prune" feature, most likely by specifying a magic return value
for custom rebless editors.

Make a proper test suite (currently a rudimentary unit test is available
by running "perl Class/Rebless.pm")

=head1 AUTHOR

Gaal Yahas <gaal@forum2.org>

Copyright (c) 2004 Gaal Yahas. All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

if (!caller) {
	require Data::Dumper;
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

	print Data::Dumper::Dumper($beat);
	Class::Rebless->rebase($beat, 'And');

	print Data::Dumper::Dumper($beat);
	Class::Rebless->custom($beat, 'And', {
			editor => sub {
				my ($obj, $class) = @_;
				my $cur = ref $obj;
				bless $obj, "\U$cur";
			},
		});
	print Data::Dumper::Dumper($beat);
}

# sub D { require Data::Dumper; print Data::Dumper::Dumper(@_) }

1;
