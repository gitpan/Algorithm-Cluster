use ExtUtils::MakeMaker;
use Config;
use POSIX qw(uname);
#$Verbose=1;

WriteMakefile(
	NAME		=> 'Algorithm::Cluster',
	VERSION_FROM	=> 'Cluster.pm',
	PM		=> 
		{
			'Cluster.pm' =>	'$(INST_LIBDIR)/Cluster.pm',
		},
	LIBS		=> '-lm',
	INC		=> '-I../src -I../ranlib/src',
	MYEXTLIB	=> '../src/libcluster$(LIB_EXT)',
);

