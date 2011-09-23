#!/usr/bin/env perl -w
use strict;

use Test::More;
require_ok 'Class::Rebless';

# Attempt to verify we don't make more visits than we should.

# Makes a binary tree of given depth with nodes blessed into namespaces
# that encode their location.
sub make_struct {
  my ($depth, $tag) = @_;
  die "bad depth: $depth" if $depth > 9;
  $tag ||= 'root';
  my $obj = bless {}, $tag;
  if ($depth > 1) {
    $obj->{left}  = make_struct($depth - 1, $tag . '0');
    $obj->{right} = make_struct($depth - 1, $tag . '1');
  }
  return $obj;
}

{
  package Class::Rebless::Accounting;
  our @ISA = 'Class::Rebless';
  our $CALLS = 0;
  our $TRACE = '';
  sub reset { $CALLS = 0; $TRACE = ''; }
  sub _recurse {
    my $self = shift;
    $CALLS++;
    $TRACE .= ref($_[0]) . ';';
    $self->SUPER::_recurse(@_);
  }
}

{
  Class::Rebless::Accounting->reset();
  my $data = make_struct(6);

  Class::Rebless::Accounting->rebless($data, 'seen');
  is($Class::Rebless::Accounting::CALLS, 2 ** 6 - 1);
}

{
  Class::Rebless::Accounting->reset();
  my $data = make_struct(6);

  Class::Rebless::Accounting->rebase($data, 'seen');
  is($Class::Rebless::Accounting::CALLS, 2 ** 6 - 1);
}

{
  my $calls = 0;
  my $data = make_struct(6);
  Class::Rebless->custom($data, '', { editor => sub {
    my ($obj, $namespace) = @_;
    $calls++;
    return bless $obj, 'seen-' . ref $obj;
  }});
  is($calls, 2 ** 6 - 1);
}

{
  Class::Rebless::Accounting->reset();
  my $data = make_struct(6);
  $data->{right} = $data->{left};
  $data->{left}{left} = $data->{right}{right};

  Class::Rebless::Accounting->rebase($data, 'seen');
  # diag $Class::Rebless::Accounting::TRACE;
  is($Class::Rebless::Accounting::CALLS,
      2 ** 6 - 1      # basic depth-4 tree
      - (2 ** 5 - 1)  # since right isn't redone
      - (2 ** 4 - 1)  # and neither is left->left
      + 2             # however, we do visit their roots to discard them.
  );
}

done_testing;
