
my ($last_test,$loaded);

######################### We start with some black magic to print on failure.
use lib '../blib/lib','../blib/arch';

BEGIN { $last_test = 34; $| = 1; print "1..$last_test\n"; }
END   { print "not ok 1  Can't load Algorithm::Cluster\n" unless $loaded; }

use Algorithm::Cluster;
no  warnings 'Algorithm::Cluster';

$loaded = 1;
print "ok 1\n";

######################### End of black magic.

sub test;  # Predeclare the test function (defined below)

my $tcounter = 1;
my $want     = '';


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
my ($clusters, $centroids, $found);
my ($i,$j);

my %params = (

	nclusters =>         3,
	transpose =>         0,
	npass     =>       100,
	method    =>       'a',
	dist      =>       'e',
);

#----------
# test dataset 1
#
($clusters, $centroids, $found) = Algorithm::Cluster::kcluster(

	%params,
	data      =>    $data1,
	mask      =>    $mask1,
	weight    =>  $weight1,
);

#$i=0;$j=0;
#foreach(@{$centroids}) {
#	$j=0;
#	foreach(@{$_}) {
#		printf("%2d,%2d: %7.3f\n",$i,$j++,$_);
#	}
#	++$i;
#}
#
#$i=0;$j=0;
#foreach(@{$clusters}) {
#	printf("%2d: %2d\n",$i++,$_);
#}

#----------
# Make sure that the length of @clusters matches the length of @data
$want = scalar @$data1;       test q( scalar @$clusters );

# Make sure that we got the right number of clusters (in @centroids)
$want = $params{nclusters};       test q( scalar @$centroids );

#----------
# Test the cluster coordinates
$want = '1';       test q( $clusters->[ 0] != $clusters->[ 1] );
$want = '1';       test q( $clusters->[ 1] == $clusters->[ 2] );
$want = '1';       test q( $clusters->[ 2] != $clusters->[ 3] );

$want = '  1.100';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[0] );
$want = '  2.200';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[1] );
$want = '  3.300';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[2] );
$want = '  4.400';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[3] );

$want = '  3.600';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[0] );
$want = '  2.700';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[1] );
$want = '  0.800';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[2] );
$want = '  3.900';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[3] );

$want = ' 12.100';       test q( sprintf "%7.3f", $centroids->[$clusters->[3]]->[0] );
$want = '  2.000';       test q( sprintf "%7.3f", $centroids->[$clusters->[3]]->[1] );
$want = '  0.000';       test q( sprintf "%7.3f", $centroids->[$clusters->[3]]->[2] );
$want = '  5.000';       test q( sprintf "%7.3f", $centroids->[$clusters->[3]]->[3] );


#----------
# test dataset 2
#
$i=0;$j=0;
($clusters, $centroids, $found) = Algorithm::Cluster::kcluster(

	%params,
	data      =>    $data2,
	mask      =>    $mask2,
	weight    =>  $weight2,
);

#$i=0;$j=0;
#foreach(@{$centroids}) {
#	$j=0;
#	foreach(@{$_}) {
#		printf("%2d,%2d: %7.3f\n",$i,$j++,$_);
#	}
#	++$i;
#}
#
#$i=0;$j=0;
#foreach(@{$clusters}) {
#	printf("%2d: %2d\n",$i++,$_);
#}


#----------
# Make sure that the length of @clusters matches the length of @data
$want = scalar @$data2;       test q( scalar @$clusters );

# Make sure that we got the right number of clusters (in @centroids)
$want = $params{nclusters};       test q( scalar @$centroids );

#----------
# Test the cluster coordinates
$want = '1';       test q( $clusters->[ 0] == $clusters->[ 3] );
$want = '1';       test q( $clusters->[ 0] != $clusters->[ 6] );
$want = '1';       test q( $clusters->[ 0] != $clusters->[ 9] );
$want = '1';       test q( $clusters->[11] == $clusters->[12] );

$want = '  1.500';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[0] );
$want = '  1.550';       test q( sprintf "%7.3f", $centroids->[$clusters->[0]]->[1] );
$want = '  1.500';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[0] );
$want = '  1.550';       test q( sprintf "%7.3f", $centroids->[$clusters->[1]]->[1] );

$want = '  5.333';       test q( sprintf "%7.3f", $centroids->[$clusters->[6]]->[0] );
$want = '  5.550';       test q( sprintf "%7.3f", $centroids->[$clusters->[6]]->[1] );
$want = '  5.333';       test q( sprintf "%7.3f", $centroids->[$clusters->[7]]->[0] );
$want = '  5.550';       test q( sprintf "%7.3f", $centroids->[$clusters->[7]]->[1] );

$want = '  3.100';       test q( sprintf "%7.3f", $centroids->[$clusters->[8]]->[0] );
$want = '  3.300';       test q( sprintf "%7.3f", $centroids->[$clusters->[8]]->[1] );



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



