use strict;
use warnings;

use Test::More;

my @mods = qw(
    REST Base
);

my $base = 'Net::Redfish';
foreach my $mod (@mods) {
    my $fmod = $base."::$mod";
    use_ok($fmod);
};

use_ok($base);

done_testing;
