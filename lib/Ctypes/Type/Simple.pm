package Ctypes::Type::Simple;
use strict;
use warnings;
use Carp;
use Ctypes;
use Ctypes::Type qw|&_types &strict_input_all|;
our @ISA = qw|Ctypes::Type|;
use fields qw|alignment name _typecode size
              strict_input val _as_param_|;
use overload '${}' => \&_scalar_overload,
             '0+'  => \&_scalar_overload,
             '""'  => \&_scalar_overload,
             '&{}' => \&_code_overload,
             fallback => 'TRUE';
       # TODO Multiplication will have to be overridden
       # to implement Python's Array contruction with "type * x"???
our $Debug;

=head1 NAME

Ctypes::Type::Simple - The atomic C data types

=head1 SYNOPSIS

    use Ctypes;         # standard c_<type> funcs imported

    my $int = c_int;    # defaults to value 0
    $$c_int++;
    $$c_int += 5;

    my $double = c_double(200000);   # etc...

=head1 ABSTRACT

All the basic C data types are represented by Ctypes::Type::Simple
objects. Their constructors are abstracted through the main Ctypes
module, so you'll rarely want to call Simple->new directly.

=head1 DESCRIPTION

=over

=item c_X<lt>typeX<gt>(x)

=back

The basic Ctypes::Type objects are almost always created with the
correspondingly named functions exported by default from Ctypes.
All basic types are objects of type Ctypes::Type::Simple. You could
call the class constructor directly if you liked, passing a typecode
as the first argument followed by any initialisers, but the named
functions put in the appropriate typecode for you and are normally
more convenient.

A Ctypes::Type object represents a variable of a certain C type. If
uninitialised, the value defaults to zero. Uninitialized instances
are often used as parameters for constructing compound objects.

After creation, you can manipulate the value stored in a Type object
in any of the following ways:

=over

=item $$int = 100;

=item $int->(100);

=item $int->value(100);

=item $int->value = 100;

=back

The 'double-sigil' shown first is perhaps the most convenient, despite
looking a bit unusual. In general, the convention to remember in
Ctypes is that you use B<two> sigils to talk about the B<value> you're
representing, and B<one> sigil to talk about the object you're
representing it with. So $$int returns the value which would be
passed to C, while $int can be used to find out things I<about> the object
itself, like C<$int->name>, C<$int->size>, etc.

In addition to the methods provided by Ctypes::Type, Ctypes::Type::Simple
objects provide the following extra methods.

=cut

sub _num_overload { return shift->{_value}; }

sub _add_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_value} + $y; }
    else { $ret = $y->{_value} + $x; }
  } else {           # += etc.
    $x->{_value} = $x->{_value} + $y;
    $ret = $x;
  }
  return $ret;
}

sub _subtract_overload {
  my( $x, $y, $swap ) = @_;
  my $ret;
  if( defined($swap) ) {
    if( !$swap ) { $ret = $x->{_value} - $y; }
    else { $ret = $x - $y->{_value}; }
  } else {           # -= etc.
    $x->{_value} = $x->{_value} - $y;
    $ret = $x;
  }
  return $ret;
}

sub _scalar_overload {
  my $self = shift;
  return \$self->{_value};
}

sub _code_overload {
  my $self = shift;
  return sub { $self->{_value} = $_[0] }
}


=over

=item new Simple TYPECODE [ARG]

=item new c_I<(class)> [ARG]

The Ctypes::Type::Simple constructor. See the main L<Ctypes|Ctypes/call>
module for an explanation of typecodes. ARG is the optional value
initialisation for your Type. Try to make it something sensible.
Numbers and characters usually go down well.

=cut

sub new {
  my $class = ref($_[0]) || $_[0]; shift;
  my $typecode;
  if ($class eq 'Ctypes::Type::Simple') {
    $typecode = shift;
  } else {
    my ($name) = $class =~ /(c_\w+|)/;
    $typecode = $Ctypes::Type::_defined{$name};
  }
  my $arg = shift;
  print "In Type::Simple constructor: typecode [ $typecode ]",
    $arg ? ", arg [ $arg ]" : '', "\n" if $Debug;
  croak("Ctypes::Type::Simple error: Need typecode") if not defined $typecode;
  my $self = $class->_new( {
    _typecode        => $typecode,
    _name            => Ctypes::Type::_types()->{$typecode}->{name},
    _strict_input    => 0,
  } );
  #for(keys(%{$attrs})) { $self->{$_} = $attrs->{$_}; };
  #bless $self => $class;
  if (defined $arg) {
    $self->{_datasafe} = 0; # force _update_ and validate data
    if( exists $Ctypes::Type::_types->{$typecode}->{hook_in} ) {
      my ($valid, $newarg) = $Ctypes::Type::_types->{$typecode}->{hook_in}->($arg);
      $arg = $newarg unless $valid;
    }
  } else {
    $arg = 0;
  }
  $self->{_value} = $arg;
  $self->{_rawvalue} = tie $self->{_value}, 'Ctypes::Type::Simple::value', $self;
  # $self->{_rawvalue}{VALUE} = \$self->{_value}; # ref to $self->{_value}
  return $self;
}


=item strict_input

Mutator setting and/or returning a flag (1 or 0) indicating how
fuzzy this object should be about values given it to store. Defaults
to 0, meaning Ctypes will do its best to make a sensible value of
the correct type out of any value it gets (although its ability to do
so is not always guaranteed). You'll probably get a warning about it.
Note that even if C<strict_input> is 0 for a particular object, it is
overridden if C<strict_input_all> is set to 1.
See the L<strict_input_all|Ctypes::Type/strict_input_all> class method
in L<Ctypes::Type>.

=cut

sub strict_input {
    my $self = shift;
    my $arg = shift;
    if( @_  or ( defined $arg and $arg != 1 and $arg != 0 ) ) {
      croak("Usage: strict_input(1 or 0)");
    }
    $self->{_strict_input} = $arg if defined $arg;
    $self->{_strict_input};
}

=item copy

Return a copy of the object.

=cut

sub copy {
  print "In Simple::copy\n" if $Debug;
  my $value = $_[0]->value;
  my $tmp = $value;
  $value = $tmp;
  print "    Value is $value\n" if $Debug;
  return Ctypes::Type::Simple->new( $_[0]->typecode, $value );
}

=item value EXPR

=item value

Accessor / mutator for the value of the variable the object
represents. C<value> is an lvalue method, so you can assign to it
directly (all the appropriate type checking will still be done).

=back

=cut

sub value : lvalue {
  $_[0]->{_value} = $_[1] if defined $_[1];
  $_[0]->{_value};
}

=head1 SEE ALSO

L<Ctypes>

=cut

sub data {
  my $self = shift;
  print "In ", $self->{_name}, "'s _DATA_, from ", join(", ",(caller(0))[0..3]), "\n" if $Debug;
  if( defined $self->owner
      or $self->_datasafe == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug;
    $self->_update_;
  }
  if( defined $self->{_data}
      and $self->{_datasafe} == 1 ) {
    print "    asparam already defined\n" if $Debug;
    print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug;
    return \$self->{_data};
  }
  $self->{_data} =
    pack( $self->packcode, $self->{_value} );
  print "    returning ", unpack('b*',$self->{_data}), "\n" if $Debug;
  $self->{_datasafe} = 0;  # used by FETCH
  return \$self->{_data};
}

sub _as_param_ { &data(@_) }

sub _update_ {
  my( $self, $arg ) = @_;
  print "In ", $self->{_name}, "'s _UPDATE_...\n" if $Debug;
  print "    I am pwnd by ", $self->{_owner}->{_name}, "\n" if $self->{_owner} and $Debug;
  if( not defined $arg ) {
    if( $self->{_owner} ) {
      print "    Have owner, getting updated data...\n" if $Debug;
      my $owners_data = ${$self->{_owner}->data};
      print "    Here's where I think I am in my pwner's data:\n" if $Debug;
      print " " x ($self->{_index} * 8), "v\n" if $Debug;
      print "12345678" x length($owners_data), "\n" if $Debug;
      print unpack('b*', $owners_data), "\n" if $Debug;
      print "    My index is ", $self->{_index}, "\n" if $Debug;
      print "    My size is ", $self->size, "\n" if $Debug;
      $self->{_data} = substr( ${$self->{_owner}->data},
                               $self->{_index},
                               $self->size );
      print "    My data is now:\n", unpack('b*', $self->{_data}), "\n" if $Debug;
      print "    Which is ", unpack($self->packcode,$self->{_data}), " as a number\n" if $Debug;
      $self->{_value} = unpack($self->packcode, $self->{_data});
    } else {
      $self->{_data} = pack($self->packcode, $self->{_value});
    }
  } else {
    $self->{_data} = pack($self->packcode, $arg );
    if( $self->owner ) {
      $self->owner->_update_($self->{_data}, $self->{_index});
    }
  }
  $self->{_value} = unpack($self->packcode, $self->{_data});
  print "    VALUE is _update_d to ", $self->{_value}, "\n" if $Debug;
  $self->{_datasafe} = 1;
  return 1;
}

sub _set_undef { $_[0]->{_value} = 0 }

sub size { Ctypes::sizeof($_[0]->sizecode) };
sub sizecode {
  my $t = $Ctypes::Type::_types->{$_[0]->{_typecode}};
  defined $t->{sizecode} ? $t->{sizecode} : $_[0]->{_typecode};
}
sub packcode {
  my $t = $Ctypes::Type::_types->{$_[0]->{_typecode}};
  defined $t->{packcode} ? $t->{packcode} : $_[0]->{_typecode};
}
sub validate {
  my $h = $Ctypes::Type::_types->{$_[0]->{_typecode}}->{hook_in};
  defined $h ? $h->($_[1]) : ("", 1);
}

sub _limcheck {
}

sub hook_in {
  my $self = shift;
  my $arg = shift;
  my $valid = undef;
  my $tc = $self->typecode;
  my $name = $self->name;
  my ($MIN,$MAX) = $self->_minmax();
  print "In hook_in\n" if $Debug;
  return ( "$name: cannot take references", undef )
    if ref($arg);
  if( Ctypes::Type::is_a_number($arg) ) {
    if( $arg !~ /^[+-]?\d+$/ ) {
      $valid = "$name: numeric values must be integers " .
        "$MIN <= x <= $MAX";
      $arg = sprintf("%u",$arg);
    }
    if( $arg < $MIN or $arg > $MAX ) {
      $valid = "$name: numeric values must be integers " .
        "$MIN <= x <= $MAX"
          if not defined $valid;
    }
  } else {
    if( length($arg) == 1 ) {
      print "    1 char long, good\n" if $Debug;
      $arg = ord($arg);
      if( $arg < 0 or $arg > $MAX ) {
        $valid = "$name: character values must be integers " .
          "0 <= ord(x) <= $MAX";
      }
    } else {
      $valid = "$name: single characters only";
      $arg = ord(substr($arg, 0, 1));
      if( $arg < 0 or $arg > $MAX ) {
        $valid .= ", and must be integers " .
          "0 <= ord(x) <= $MAX";
      }
    }
  }
  return ($valid, $arg);
}

# c_char c_wchar c_byte c_ubyte c_short c_ushort c_int c_uint c_long c_ulong
# c_longlong c_ulonglong c_float c_double c_longdouble c_char_p c_wchar_p
# c_size_t c_ssize_t c_bool c_void_p

# c_int8 c_int16 c_int32 c_int64 c_uint8 c_uint16 c_uint32 c_uint64


package Ctypes::Type::c_int;
use base 'Ctypes::Type::Simple';
#sub sizecode{'s'};
sub packcode{'s'};
sub typecode{'h'};
sub _minmax { ( Ctypes::constant('PERL_SHORT_MIN'),
                Ctypes::constant('PERL_SHORT_MAX') ) }

package Ctypes::Type::c_short;
use base 'Ctypes::Type::Simple';

package Ctypes::Type::c_char;
use base 'Ctypes::Type::Simple';

*c_short = *Ctypes::Type::c_short;
*c_char  = *Ctypes::Type::c_char;
*c_int   = *Ctypes::Type::c_int;

package Ctypes::Type::Simple::value;
use strict;
use warnings;
use Carp;
use Scalar::Util qw|blessed|;

sub TIESCALAR {
  my $class = shift;
  my $object = shift;
  my $self = [ $object ];
  return bless $self => $class;
}

sub STORE {
  #croak("STORE must take a value") if scalar @_ != 2;
  my $self = shift;
  my $object = $self->[0];
  my $arg = shift or croak("STORE must take a value");
  print "In ", $object->{_name}, "'s STORE with arg [ ", $arg, " ],\n" if $Debug;
  print "    called from ", (caller(1))[0..3], "\n" if $Debug;
  croak("Simple Types can only be assigned a single value") if @_;
  #my $ref= $object->{_value};

  # The following section may be removed completely to allow different
  # Types full discretion of their own input validation via hook_in().

  if( exists $Ctypes::Type::_types->{$object->{_typecode}}->{hook_in} ) {
    my ($valid, $newarg) = $Ctypes::Type::_types->{$object->{_typecode}}->{hook_in}->($arg);
    $arg = $newarg unless $valid;
  }
  # Deal with being assigned other Type objects and the like...
#    if(my $ref = ref($arg)) {
#      if($ref =~ /^Ctypes::Type::/) {
#        $arg = $arg->{_data};
#      } else {
#        if($arg->can("data")) {
#          $arg = ${$arg->data};
#        } else {
#    # ??? Would you ever want to store an object/reference as the value
#    # of a type? What would get pack()ed in the end?
#          croak("Ctypes Types can only be made from native types or " .
#                "Ctypes compatible objects");
#        }
#      }
#    }

  # Object's Value set to undef: {_val} becomes undef, {_data} filled
  # with null (i.e. numeric zero) , update owners, return early.
  if( not defined $arg ) {
    print "    Assigned undef. All goes null.\n" if $Debug;
    $object->{_datasafe} = 0;
    $object->{_value} = 0;
    $object->{_data} = "\0" x 8 x $object->{_size}; # stay right length
    if( $object->{_owner} ) {
      $object->{_owner}->_update_($object->{_data}, $object->{_index});
    }
    return $object->{_value};
  }

  my $typecode = $object->{_typecode};
  print "    Using typecode $typecode\n" if $Debug;
  print "    1) arg is ", $arg, "\n" if $Debug;
  # return 1 on success, 0 on fail, -1 if (numeric but) out of range
  #my $is_valid = Ctypes::_valid_for_type($arg,$typecode);
  print "    Calling validate...\n" if $Debug;
  my ($invalid, $result) = $object->validate($arg);
  print "    validate() returned ", $invalid ? "'$invalid'\n" : "ok\n" if $Debug;
  if( defined $invalid ) {
    no strict 'refs';
    if( ($object->strict_input == 1)
        or (Ctypes::Type::strict_input_all() == 1)
        or (not defined $result) ) {
      print "Unable to ameliorate input! (strict input or validate couldn't convert)\n" if $Debug;
      croak( $invalid, ' (got ', $arg, ')');
      return undef;
    } else {
      carp( $invalid, ' (got ', $arg, ')');
    }
  }
  print "    2) arg is $result, which is ",
    unpack('b*', $result), " or ", ord($result), "\n" if $Debug;
  $object->{_data} =
    pack( $object->packcode, $result );
  $object->{_value} = unpack( $object->packcode, $object->{_data} );
  $object->{_input} = $arg;
  if( $object->{_owner} ) {
    print "    Have owner, updating with\n",
      unpack('b*', $object->{_data}), "\n    or ",
      unpack($object->{_typecode},$object->{_data}), " to you and me\n" if $Debug;
    $object->{_owner}->_update_($object->{_data}, $object->{_index});
  }
  print "  Returning ok...\n" if $Debug;
  return $object->{_value};
}

sub FETCH {
  my $self = shift;
  my $object = $self->[0];
  print "In ", $object->{_name}, "'s FETCH, from ", (caller(1))[0..3], "\n" if $Debug;
  if ( defined $object->{_owner}
       or $object->{_datasafe} == 0 ) {
    print "    Can't trust data, updating...\n" if $Debug;
    $object->_update_;
  }
  croak("Error updating value!") if $object->{_datasafe} != 1;
  print "    ", $object->name, "'s Fetch returning ", $self->{VALUE}, "\n" if $Debug;
  if( exists $Ctypes::Type::_types->{$object->{_typecode}}->{hook_out} ) {
    return $Ctypes::Type::_types->{$object->{_typecode}}->{hook_out}->($self->{VALUE}, $object);
  } else {
    return $object->{_value};
  }
}

1;
__END__
