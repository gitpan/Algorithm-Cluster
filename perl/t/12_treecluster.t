
my ($last_test,$loaded);

######################### We start with some black magic to print on failure.
use lib '../blib/lib','../blib/arch';

BEGIN { $last_test = 25; $| = 1; print "1..$last_test\n"; }
END   { print "not ok 1  Can't load Algorithm::Cluster\n" unless $loaded; }

use Algorithm::Cluster;
no  warnings 'Algorithm::Cluster';

$loaded = 1;
print "ok 1\n";

######################### End of black magic.

sub test;  # Predeclare the test function (defined below)

my $tcounter = 1;
my $want     = '';

open(FILE,">/tmp/test.out");

#------------------------------------------------------
# Data for Tests
# 

#----------
# dataset 1
#
my $weight1 =  [ 1,1,1,1,1 ];
my $data1   =  [
        [ 1.1, 2.2, 3.3, 4.4, 5.5, ], 
        [ 3.1, 3.2, 1.3, 2.4, 1.5, ], 
        [ 4.1, 2.2, 0.3, 5.4, 0.5, ], 
        [ 12.1, 2.0, 0.0, 5.0, 0.0, ], 
];
my $mask1 =  [
        [ 1, 1, 1, 1, 1, ], 
        [ 1, 1, 1, 1, 1, ], 
        [ 1, 1, 1, 1, 1, ], 
        [ 1, 1, 1, 1, 1, ], 
];

#----------
# dataset 2
#
my $weight2 =  [ 1,1 ];
my $data2   =  [
	[ 0.8223, 0.9295 ],
	[ 1.4365, 1.3223 ],
	[ 1.1623, 1.5364 ],
	[ 2.1826, 1.1934 ],
	[ 1.7763, 1.9352 ],
	[ 1.7215, 1.9912 ],
	[ 2.1812, 5.9935 ],
	[ 5.3290, 5.9452 ],
	[ 3.1491, 3.3454 ],
	[ 5.1923, 5.3156 ],
	[ 4.7735, 5.4012 ],
	[ 5.1297, 5.5645 ],
	[ 5.3934, 5.1823 ],
];
my $mask2 =  [
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
	[ 1, 1 ],
];


#------------------------------------------------------
# Tests
# 
my ($result, $linkdist, $output);
my ($i);

#----------
# test dataset 1
#

#--------------[PALcluster]-------
my %params = (

	applyscale =>         0,
	transpose  =>         0,
	method     =>       'a',
	dist       =>       'e',
	data       =>    $data1,
	mask       =>    $mask1,
	weight     =>  $weight1,
);

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data1) - 1;       test q( scalar @$result );
$want = scalar(@$data1) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}


$want = '  0:   2   1  13.000
  1:  -1   0  36.500
  2:   3  -2 106.740
';				test q( $output );


#--------------[PSLcluster]-------
$params{method} = 's';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data1) - 1;       test q( scalar @$result );
$want = scalar(@$data1) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   2   1  13.000
  1:  -1   0  29.000
  2:   3  -2  64.540
';				test q( $output );


#--------------[PCLcluster]-------
$params{method} = 'c';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data1) - 1;       test q( scalar @$result );
$want = scalar(@$data1) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   1   2  13.000
  1:   0  -1  33.250
  2:  -2   3  97.184
';				test q( $output );

#--------------[PMLcluster]-------
$params{method} = 'm';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data1) - 1;       test q( scalar @$result );
$want = scalar(@$data1) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   2   1  13.000
  1:  -1   0  44.000
  2:   3  -2 162.540
';				test q( $output );


#----------
# test dataset 2
#

#--------------[PALcluster]-------
my %params = (

	applyscale =>         0,
	transpose  =>         0,
	method     =>       'a',
	dist       =>       'e',
	data       =>    $data2,
	mask       =>    $mask2,
	weight     =>  $weight2,
);

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data2) - 1;       test q( scalar @$result );
$want = scalar(@$data2) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   5   4   0.006
  1:   9  12   0.058
  2:   2   1   0.121
  3:  11  -2   0.141
  4:  -4  10   0.256
  5:   7  -5   0.448
  6:  -3   0   0.508
  7:  -1   3   0.782
  8:  -8  -7   1.065
  9:   8  -9   6.468
 10:  -6   6   9.272
 11: -11 -10  25.483
';				test q( $output );

#print STDERR "\n$want\n\n$output\n";


#--------------[PSLcluster]-------
$params{method} = 's';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data2) - 1;       test q( scalar @$result );
$want = scalar(@$data2) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   5   4   0.006
  1:   9  12   0.058
  2:  11  -2   0.066
  3:   2   1   0.121
  4:  -3  10   0.154
  5:   7  -5   0.185
  6:  -4   0   0.484
  7:  -1  -7   0.491
  8:   3  -8   0.573
  9:   8  -9   3.872
 10:  -6 -10   6.865
 11:   6 -11   7.071
';				test q( $output );


#--------------[PCLcluster]-------
$params{method} = 'c';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data2) - 1;       test q( scalar @$result );
$want = scalar(@$data2) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   4   5   0.006
  1:  12   9   0.058
  2:   1   2   0.121
  3:  -2  11   0.126
  4:  10  -4   0.218
  5:  -5   7   0.378
  6:   0  -3   0.477
  7:   3  -1   0.781
  8:  -7  -8   0.764
  9:  -9   8   6.126
 10:   6  -6   9.156
 11: -10 -11  23.072
';				test q( $output );
print FILE "$want\n$output";


#--------------[PMLcluster]-------
$params{method} = 'm';

($result, $linkdist) = Algorithm::Cluster::treecluster(%params);

# Make sure that @clusters and @centroids are the right length
$want = scalar(@$data2) - 1;       test q( scalar @$result );
$want = scalar(@$data2) - 1;       test q( scalar @$linkdist );

$output = '';
$i=0;
foreach(@{$result}) {
	$output .= sprintf("%3d: %3d %3d %7.3f\n",$i,$_->[0],$_->[1],$linkdist->[$i]);
	++$i
}

$want = '  0:   5   4   0.006
  1:   9  12   0.058
  2:   2   1   0.121
  3:  11  10   0.154
  4:  -2  -4   0.432
  5:  -3   0   0.532
  6:  -5   7   0.605
  7:  -1   3   0.849
  8:  -8  -6   1.936
  9:   8   6   7.949
 10: -10  -7  11.511
 11: -11  -9  45.468
';				test q( $output );
print FILE "$want\n$output";

#------------------------------------------------------
# Test function
# 
sub test {
	$tcounter++;

	my $string = shift;
	my $ret = eval $string;
	$ret = 'undef' if not defined $ret;

	if("$ret" =~ /^$want$/sm) {

		print "ok $tcounter\n";

	} else {
		print "not ok $tcounter\n",
		"   -- '$string' returned '$ret'\n", 
		"   -- expected =~ /$want/\n"
	}
}

__END__
