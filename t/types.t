#!perl

use strict;
use warnings;
use Test::More tests => 26;
use Ctypes;
use utf8;

my $number_seven = c_int(7);
ok( defined $number_seven, 'c_int returned object');
# XXX Py ctypes has this behaviour: valuable?
# don't know if c_int will default to different type on
# this system so do inspecific check:
like( ref($number_seven), qr/Ctypes::Type/, 'c_int created Type object' );

is( $$number_seven, 7, "\$\$obj: " . $$number_seven );

my $number_twelve = $number_seven;

is_deeply( $number_twelve, $number_seven, "Assignment copies object" );

$$number_seven = 15;
is( $$number_seven, 15, "Assign value with \$\$obj = x" );

$number_seven->value = 17;
is( $$number_seven, 17, "Assign value with \$obj->value = x" );

$number_seven->value(19);
is( $$number_seven, 19, "Assign value with \$obj->value(x)" );

$number_seven->(15);
is( $$number_seven, 15, "Assign value with \$obj->(x)" );

$$number_seven = 15.5972;
is( $$number_seven, 15, "Ints rounded" );

$$number_seven += 3;
is( $$number_seven, 18, '$obj += <num>' );
$$number_seven--;
is( $$number_seven, 17, '$obj -= <num>' );

is( $number_seven->typecode, 'i', "->typecode getter" );
is( $number_seven->typecode('p'), 'i', "typecode cannot be set" );

is( ${$number_seven->data}, pack('i', 17), "->_data getter" );

$number_seven = 20;
is(ref($number_seven), '', '$obj = <num> squashes object');

my $no_value = c_int;
ok( ref($no_value) =~ /Ctypes::Type/, 'Created object without initializer' );
is( $$no_value, 0, 'Default initialization to 0' );
$$no_value = 10;
is( $$no_value, 10, 'Set to valid number' );
$$no_value = undef;
is( $$no_value, 0, 'Setting undef means zero' );

my $number_y = c_int('y'); #20
is( $$number_y, 121, 'c_int casts from non-numeric ASCII character' );

my $number_ryu = c_int('龍'); #21
is( $$number_ryu, 40845, 'c_int converts from UTF-8 character' );
# TODO: implement this for other numeric types!

# Exceeding range on _signed_ variables is undefined in the standard,
# so these tests can't really be any better.
my $overflower = c_int16(32768); # i.e. c_short
subtest 'Overflows' => sub {
  plan tests => 6;
  is(ref $overflower, 'Ctypes::Type::c_short');
  isnt( $$overflower, 32768);
  ok( $$overflower <= Ctypes::constant('PERL_SHORT_MAX'),
      'Cannot exceed SHORT_MAX');
  $$overflower = -32769;
  is(ref $overflower, 'Ctypes::Type::c_short');
  isnt( $$overflower,-32769);
  ok( $$overflower >= Ctypes::constant('PERL_SHORT_MIN'),
      'Cannot go below SHORT_MIN');
};
$$overflower = 5;
$overflower->strict_input(0);
$$overflower = 32768;

TODO: {
  local $TODO = 'overflow with strict_input';
  is($$overflower, 5, 'Disallow overflow per-object');
  $overflower->strict_input(1);
  Ctypes::Type::strict_input_all(0);
  $overflower = c_int16(32768);
  is($overflower, undef, 'Can strict_input_all(0)');
}

#local $TODO = 'chars are integers - need Perl-side hooks for displaying as chars';
my $charar = c_char('P');
is( $$charar, 'P', 'c_char shows as 1-char strings in Perl' );
my $ret_as_char = c_char(89);
is( $$ret_as_char, 'Y', 'c_char converts from numbers' );

my $ushort = c_uint(691693896);
my $charptr = Pointer( c_char, $ushort );
diag( join(" ",@$charptr) );
