use ExtUtils::MakeMaker;
use Config;
use POSIX qw(uname);
#$Verbose=1;

WriteMakefile(
	NAME		=> 'Algorithm::Cluster',
	DISTNAME	=> 'Algorithm-Cluster',
	AUTHOR		=> 'John Nolan and Michiel de Hoon',
	ABSTRACT	=> 'Perl interface to the C Clustering Library',
	VERSION_FROM	=> 'Cluster.pm',
	PM		=> 
		{
			'Cluster.pm' =>	'$(INST_LIBDIR)/Cluster.pm',
		},
	LIBS		=> '-lm',
	INC		=> '-I../src -I../ranlib/src',
	MYEXTLIB	=> '../src/libcluster$(LIB_EXT)',
);

