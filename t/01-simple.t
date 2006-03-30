#!/usr/bin/env perl -w                                                                              
use strict;

use Test::More;
use Data::Dumper;

eval "use Test::NoWarnings";
my $tests = 117;
if ($@) {
  diag 'Please consider installing Test::NoWarnings for an additional test';
} else {
  $tests++;
}
plan tests => $tests;


#################### prepare some subs

# how else can one test that the given thing is not blessed?
sub in_sin($;$) {
  my ($obj, $comment) = @_;
  my $t = Test::More->builder;
  $t->unlike($obj, qr/=/, $comment); 
}

sub create_beat { 
  open my $fh, "<", "MANIFEST" or die "Could not open MANIFEST for testing";
  return bless({
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
            func => sub { 100; },
            funcy => bless(sub { 42; }, 'AFunc'),
            deep => bless({
                      deeper => bless({
                                  deepest => bless({ field => "value" }, "Deepest"),
                      }, "Deeper"),
            }, "Deep"),
            #fh => bless $fh, "FileHandler",
         }, 'AOne');
}


################################## Now let's start the tests

require_ok 'Class::Rebless';

{
  # rebase simple HASH
  my $empty = {};
  Class::Rebless->rebase($empty, 'Full');
  ok   ! UNIVERSAL::isa($empty, 'Full'), 'rebasing HASH does not do anything';

  # rebase simple HASH based class
  $empty = bless({}, 'Empty');
  isa_ok $empty, 'Empty', 'Before rebasing Empty';
  Class::Rebless->rebase($empty, 'Not');
  isa_ok $empty, 'Not::Empty', 'After rebasing Empty';
}

# rebasing nonblessed scalar reference
{
  my $foo = "bar";
  my $moo = \$foo;
  is     $foo, "bar";
  isa_ok $moo, "SCALAR";
  in_sin $moo;
  is     $$moo, "bar";

  Class::Rebless->rebase($moo, "And");
  isa_ok $moo, "SCALAR";
  in_sin $moo;
  is     $$moo, "bar";

  Class::Rebless->rebless($moo, "Else");
  isa_ok $moo, "SCALAR";
  in_sin $moo;
  is     $$moo, "bar";
}

# rebasing and reblessing blessed scalar reference
{ 
  my $foo = "Foo";
  my $moo = bless \$foo, "Foo";
  isa_ok $moo, "SCALAR";
  isa_ok $moo, "Foo";
  #is     $$moo, "bar"; #TODO

  Class::Rebless->rebase($moo, "And");
  isa_ok $moo, "SCALAR";
  isa_ok $moo, "And::Foo";
  #is     $$moo, "bar"; #TODO

  Class::Rebless->rebless($moo, "Else");
  isa_ok $moo, "SCALAR";
  isa_ok $moo, "Else";
  #is     $$moo, "bar"; #TODO
}

{
  open my $fh, "<", "MANIFEST" or die;
  bless $fh, "FileHandler";
  isa_ok $fh, "GLOB";
  isa_ok $fh, "FileHandler";

  eval{Class::Rebless->rebase($fh, "And");};
  TODO: {
    local $TODO = "fix the bug";
    ok !$@, "Should not throw exception on rebase call";
  }

  isa_ok $fh, "GLOB";
  isa_ok $fh, "And::FileHandler";

  eval{Class::Rebless->rebless($fh, "NewFileHandler");};
  TODO: {
    local $TODO = "fix the bug";
    ok !$@, "Should not throw exception on rebless call";
  }
  isa_ok $fh, "GLOB";
  isa_ok $fh, "NewFileHandler";
}


{
  my $beat = create_beat();

  # before changing 
  isa_ok $beat, "AOne";
  isa_ok $beat->{one}, "AOne";
  isa_ok $beat->{two}, "ATwo";
  isa_ok $beat->{func}, "CODE";
  in_sin $beat->{func};
  isa_ok $beat->{funcy}, "CODE";
  isa_ok $beat->{funcy}, "AFunc";
  is     $beat->{func}->(), 100, "hundred"; 
  is     $beat->{funcy}->(), 42, "the answer";

  isa_ok $beat->{deep}, "HASH";
  isa_ok $beat->{deep}, "Deep";
  isa_ok $beat->{deep}{deeper}, "HASH";
  isa_ok $beat->{deep}{deeper}, "Deeper";
  isa_ok $beat->{deep}{deeper}{deepest}, "HASH";
  isa_ok $beat->{deep}{deeper}{deepest}, "Deepest";
  is     $beat->{deep}{deeper}{deepest}{field}, "value";
  in_sin $beat->{deep}{deeper}{deepest}{field};

  #isa_ok $beat->{fh}, "GLOB";
  #isa_ok $beat->{fh}, "FileHandler";
  #diag Dumper $beat;

  Class::Rebless->rebase($beat, 'And');
  #diag Dumper $beat;
  isa_ok $beat, "And::AOne";
  isa_ok $beat->{one}, "And::AOne";
  isa_ok $beat->{two}, "And::ATwo";
  in_sin $beat->{two}{list}, "two-list not blessed";

  isa_ok $beat->{two}{list}[0], "And::AThree";
  isa_ok $beat->{two}{list}[1], "And::AFour";
  in_sin $beat->{two}{list}[2], "two list 2 is not blessed";
  in_sin $beat->{two}{list}[3], "two list 3 is not blessed"; 

  in_sin $beat->{six}, "six is not blessed";

  isa_ok $beat->{six}{seven}, "And::ASeven";
  isa_ok $beat->{six}{eight}, "And::AnEight";  

  in_sin $beat->{func};
  isa_ok $beat->{funcy}, "And::AFunc";

  isa_ok $beat->{deep}, "And::Deep";
  isa_ok $beat->{deep}{deeper}, "And::Deeper";
  isa_ok $beat->{deep}{deeper}{deepest}, "And::Deepest";
  in_sin $beat->{deep}{deeper}{deepest}{field};

  is_deeply($beat, create_beat(), "structure is the same");
}

# rebless complex structure
{
  my $beat = create_beat();

  Class::Rebless->rebless($beat, 'Beatless');
  #diag Dumper $beat;
  isa_ok $beat, "Beatless";
  isa_ok $beat->{one}, "Beatless";
  isa_ok $beat->{two}, "Beatless";
  in_sin $beat->{two}{list}, "two-list not blessed";

  isa_ok $beat->{two}{list}[0], "Beatless";
  isa_ok $beat->{two}{list}[1], "Beatless";
  in_sin $beat->{two}{list}[2], "two list 2 is not blessed";
  in_sin $beat->{two}{list}[3], "two list 3 is not blessed"; 

  in_sin $beat->{six}, "six is not blessed";

  isa_ok $beat->{six}{seven}, "Beatless";
  isa_ok $beat->{six}{eight}, "Beatless";  

  in_sin $beat->{func};
  isa_ok $beat->{funcy}, "Beatless";

  isa_ok $beat->{deep}, "Beatless";
  isa_ok $beat->{deep}{deeper}, "Beatless";
  isa_ok $beat->{deep}{deeper}{deepest}, "Beatless";
  in_sin $beat->{deep}{deeper}{deepest}{field};

  is_deeply($beat, create_beat(), "structure is the same");
}

{
  my $beat = create_beat();

  Class::Rebless->custom($beat, 'Custom', { editor => \&my_custom_editor });

  isa_ok $beat, "Custom::AOne";
  isa_ok $beat->{one}, "Custom::AOne";
  isa_ok $beat->{two}, "Custom::ATwo";
  in_sin $beat->{two}{list}, "two-list not blessed";

  isa_ok $beat->{two}{list}[0], "Custom::Three3::AThree";
  isa_ok $beat->{two}{list}[1], "Custom::Four4::AFour";
  in_sin $beat->{two}{list}[2], "two list 2 is not blessed";
  in_sin $beat->{two}{list}[3], "two list 3 is not blessed"; 

  in_sin $beat->{six}, "six is not blessed";

  isa_ok $beat->{six}{seven}, "Custom";
  isa_ok $beat->{six}{eight}, "Custom::AnEight";  

  in_sin $beat->{func};
  isa_ok $beat->{funcy}, "Custom::AFunc";

  isa_ok $beat->{deep}, "Deep"; # PRUNELESS
  isa_ok $beat->{deep}{deeper}, "Custom::Deeper";
  isa_ok $beat->{deep}{deeper}{deepest}, "Custom::Deepest";
  in_sin $beat->{deep}{deeper}{deepest}{field};

  is_deeply($beat, create_beat(), "structure is the same");
}

{
  my $beat = create_beat();

  Class::Rebless->prune("__MYPRUNE__");
  Class::Rebless->custom($beat, 'Custom', { editor => \&my_custom_editor });

  isa_ok $beat, "Custom::AOne";
  isa_ok $beat->{one}, "Custom::AOne";
  isa_ok $beat->{two}, "Custom::ATwo";
  in_sin $beat->{two}{list}, "two-list not blessed";

  isa_ok $beat->{two}{list}[0], "Custom::Three3::AThree";
  isa_ok $beat->{two}{list}[1], "Custom::Four4::AFour";
  in_sin $beat->{two}{list}[2], "two list 2 is not blessed";
  in_sin $beat->{two}{list}[3], "two list 3 is not blessed"; 

  in_sin $beat->{six}, "six is not blessed";

  isa_ok $beat->{six}{seven}, "Custom";
  isa_ok $beat->{six}{eight}, "Custom::AnEight";  

  in_sin $beat->{func};
  isa_ok $beat->{funcy}, "Custom::AFunc";

  # difference from previous because of prune:
  isa_ok $beat->{deep}, "Deep";
  isa_ok $beat->{deep}{deeper}, "Deeper";
  isa_ok $beat->{deep}{deeper}{deepest}, "Deepest";
  in_sin $beat->{deep}{deeper}{deepest}{field};

  is_deeply($beat, create_beat(), "structure is the same");
}


sub my_custom_editor {
  my ($obj, $namespace) = @_;
  return bless $obj, $namespace . '::Three3::' . ref $obj if "AThree" eq ref $obj;
  return bless $obj, $namespace . '::Four4::' . ref $obj if "AFour" eq ref $obj;
  return bless $obj, $namespace if "ASeven" eq ref $obj;
  return "__MYPRUNE__" if "Deep"eq ref $obj;
  return bless $obj, $namespace . '::' . ref $obj;
}

# There seem to be a bug that generates lots of warnings.
# I patched the code but to eliminate the warnings, but I am not sure what is the real fix.

# Currently if prune is not turned on but the custom editor returns some string a plain
# string like "__MYPRUNE__", the specific object is kept as it is.
# see test PRUNELESS



# can prune be turned off once we set it ? 

#GLOB is a filehandle