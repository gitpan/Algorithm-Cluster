use ExtUtils::MakeMaker;
use Config;
#$Verbose=1;

WriteMakefile(
	NAME         => 'libcluster',
	VERSION_FROM => '../perl/Cluster.pm',
	INC          => '-I../ranlib/src -I../ranlib/linpack',
	SKIP         => [qw(all static static_lib dynamic dynamic_lib)],
	C	     => ['cluster.c'],
	H	     => ['cluster.h'],
	OBJECT       => 'cluster.o ../ranlib/src/ranlib.o ../ranlib/src/com.o ../ranlib/linpack/linpack.o',
	MYEXTLIB     => 'libcluster$(LIB_EXT)',
	clean        => {'FILES' => 'libcluster$(LIBEEXT) $(OBJECT)'},
);


sub MY::top_targets {
'
all :: static

pure_all :: static

static :: $(OBJECT) libcluster$(LIB_EXT)

cluster.o :
	$(CC) -c $(INC) $(DEFINE_VERSION) $(XS_DEFINE_VERSION) $(CCFLAGS) -o cluster.o cluster.c

../ranlib/src/ranlib.o :
	$(CC) -c $(INC) $(DEFINE_VERSION) $(XS_DEFINE_VERSION) $(CCFLAGS) -o ../ranlib/src/ranlib.o ../ranlib/src/ranlib.c

../ranlib/src/com.o : 
	$(CC) -c $(INC) $(DEFINE_VERSION) $(XS_DEFINE_VERSION) $(CCFLAGS) -o ../ranlib/src/com.o ../ranlib/src/com.c

../ranlib/linpack/linpack.o :
	$(CC) -c $(INC) $(DEFINE_VERSION) $(XS_DEFINE_VERSION) $(CCFLAGS) -o ../ranlib/linpack/linpack.o ../ranlib/linpack/linpack.c

libcluster$(LIB_EXT): $(O_FILES)
	$(AR) cru libcluster$(LIB_EXT) $(OBJECT)
	$(RANLIB) libcluster$(LIB_EXT)
';
}
