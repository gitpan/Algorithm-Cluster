
my ($last_test,$loaded);

######################### We start with some black magic to print on failure.
use lib '../blib/lib','../blib/arch';

BEGIN { $last_test = 14; $| = 1; print "1..$last_test\n"; }
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
# Tests
#

my $node;

my $node1 = Algorithm::Cluster::Node->new(1,2,3.1);
my $node2 = Algorithm::Cluster::Node->new(-1,3,5.3);
my $node3 = Algorithm::Cluster::Node->new(4,0,5.9);
my $node4 = Algorithm::Cluster::Node->new(-2,-3,7.8);
my @nodes = [$node1,$node2,$node3,$node4];

my $tree = Algorithm::Cluster::Tree->new(@nodes);
$want = '4';  test q(sprintf "%d", $tree->length);

$node = $tree->get(0);
$want = '1';  test q(sprintf "%d", $node->left);
$want = '2';  test q(sprintf "%d", $node->right);
$want = ' 3.1000';  test q(sprintf "%7.4f", $node->distance);

$node = $tree->get(1);
$want = '-1';  test q(sprintf "%d", $node->left);
$want = '3';  test q(sprintf "%d", $node->right);
$want = ' 5.3000';  test q(sprintf "%7.4f", $node->distance);

$node = $tree->get(2);
$want = '4';  test q(sprintf "%d", $node->left);
$want = '0';  test q(sprintf "%d", $node->right);
$want = ' 5.9000';  test q(sprintf "%7.4f", $node->distance);

$node = $tree->get(3);
$want = '-2';  test q(sprintf "%d", $node->left);
$want = '-3';  test q(sprintf "%d", $node->right);
$want = ' 7.8000';  test q(sprintf "%7.4f", $node->distance);


#------------------------------------------------------
# Test function
# 
sub test {
	$tcounter++;

	my $string = shift;
	my $ret = eval $string;
	$ret = 'undef' if not defined $ret;

        if ("$ret" =~ /^$want$/sm) {

		print "ok $tcounter\n";

	} else {
		print "not ok $tcounter\n",
		"   -- '$string' returned '$ret'\n", 
		"   -- expected =~ /$want/\n"
	}
}
