/******************************************************************************/

#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <stdlib.h>

#include "../src/cluster.h"


int extract_double_from_scalar( pTHX_ SV *, double *);

int warnings_enabled(pTHX);

void print_row_dbl( pTHX_ double *, int);
void print_row_int( pTHX_ int    *, int);

void print_matrix_dbl( pTHX_ double **, int, int);
void print_matrix_int( pTHX_ int    **, int, int);
SV* format_matrix_dbl( pTHX_ double **, int, int);
SV* format_matrix_int( pTHX_ int    **, int, int);

int malloc_matrix_perl2c_dbl( pTHX_ SV *, double ***, int *, int *, int **);
int malloc_matrix_perl2c_int( pTHX_ SV *, int    ***, int *, int *);
int    malloc_row_perl2c_dbl( pTHX_ SV *, double **,  int *       );
int    malloc_row_perl2c_int( pTHX_ SV *, int    **,  int *       );

SV* matrix_c2perl_int( pTHX_ int    **, int, int  );
SV* matrix_c2perl_dbl( pTHX_ double **, int, int  );
SV*    row_c2perl_int( pTHX_ int    *,  int       );
SV*    row_c2perl_dbl( pTHX_ double *,  int       );

SV* matrix_c_array_2perl_int( pTHX_ int[][2], int, int  );

double **  malloc_matrix_dbl( pTHX_ int, int,    double );
int    **  malloc_matrix_int( pTHX_ int, int,    int    );
double *   malloc_row_dbl   ( pTHX_ int, double         );

int malloc_matrices( pTHX_
	SV *,  double **,  int *, 
	SV *,  double ***,
	SV *,  int    ***,
	int,   int
);

void free_matrix(void **, int);


/******************************************************************************/
