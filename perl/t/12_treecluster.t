
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
	[ 1.1, 1.2 ],
	[ 1.4, 1.3 ],
	[ 1.1, 1.5 ],
	[ 2.0, 1.5 ],
	[ 1.7, 1.9 ],
	[ 1.7, 1.9 ],
	[ 5.7, 5.9 ],
	[ 5.7, 5.9 ],
	[ 3.1, 3.3 ],
	[ 5.4, 5.3 ],
	[ 5.1, 5.5 ],
	[ 5.0, 5.5 ],
	[ 5.1, 5.2 ],
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
  2:   3  -2 162.540
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
  1:  -1   0  36.500
  2:   3  -2 162.540
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

$want = '  0:   2   1  13.000
  1:  -1   0  36.500
  2:   3  -2 162.540
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
  1:  -1   0  36.500
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

$want = '  0:   5   4   0.000
  1:   7   6   0.000
  2:  10  11   0.010
  3:   2   0   0.090
  4:  -3  12   0.095
  5:   1  -4   0.115
  6:  -5   9   0.143
  7:  -1   3   0.250
  8:  -2  -7   0.450
  9:  -8  -6   0.639
 10:   8 -10   5.961
 11:  -9 -11  31.214
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

$want = '  0:   5   4   0.000
  1:   7   6   0.000
  2:  10  11   0.010
  3:   2   0   0.090
  4:  -3  12   0.095
  5:   1  -4   0.115
  6:  -5   9   0.143
  7:  -1   3   0.250
  8:  -2  -7   0.450
  9:  -8  -6   0.639
 10:   8 -10   5.961
 11:  -9 -11  31.214
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

$want = '  0:   5   4   0.000
  1:   7   6   0.000
  2:  10  11   0.010
  3:   2   0   0.090
  4:  -3  12   0.095
  5:   1  -4   0.115
  6:  -5   9   0.143
  7:  -1   3   0.250
  8:  -2  -7   0.450
  9:  -8  -6   0.639
 10:   8 -10   5.961
 11:  -9 -11  31.214
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

$want = '  0:   5   4   0.000
  1:   7   6   0.000
  2:  10  11   0.010
  3:   2   0   0.090
  4:  -3  12   0.095
  5:   1  -4   0.115
  6:  -5   9   0.143
  7:  -1   3   0.250
  8:  -2  -7   0.450
  9:  -8  -6   0.639
 10:   8 -10   5.961
 11:  -9 -11  31.214
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
