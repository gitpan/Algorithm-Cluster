use ExtUtils::MakeMaker;
use File::Copy;
#use POSIX qw(uname);
#$Verbose=1;

# Check this is a supported OS release
#my ($sys, $rel) = (POSIX::uname())[0,2];

if ($^V lt v5.6) {

   die("Algorithm::Cluster is only supported on Perl 5.6.0 and later.\n" .
   "Your perl version is $].\n");
}

copy("perl/MANIFEST.perl","MANIFEST");

WriteMakefile(
	NAME         => 'Algorithm-Cluster',
	VERSION_FROM => 'perl/Cluster.pm',
	DIR          => [ 
		'src', 
		'perl',
	],
);
