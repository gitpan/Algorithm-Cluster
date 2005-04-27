#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* The Perl include files perl.h redefines malloc and free. Here, we need the
 * usual malloc and free, defined in stdlib.h. So we undefine the ones in
 * perl.h.
 */

#ifdef malloc
#undef malloc
#endif
#ifdef free
#undef free
#endif

#include <stdio.h>
#include <stdlib.h>

#include "../src/cluster.h"


/* -------------------------------------------------
 * Using the warnings registry, check to see if warnings
 * are enabled for the Algorithm::Cluster module.
 */
static int
warnings_enabled(pTHX) {

	dSP;

	I32 count;
	bool isEnabled; 
	SV * mysv;

	ENTER ;
	SAVETMPS;
	PUSHMARK(SP) ;
	XPUSHs(sv_2mortal(newSVpv("Algorithm::Cluster",18)));
	PUTBACK ;

	count = perl_call_pv("warnings::enabled", G_SCALAR) ;

	if (count != 1) croak("No arguments returned from call_pv()\n") ;

	mysv = POPs; 
	isEnabled = (bool) SvTRUE(mysv); 

	PUTBACK ;
	FREETMPS ;
	LEAVE ;

	return isEnabled;
}


/* -------------------------------------------------
 * Create a 2D matrix of doubles, initialized to a value
 */
static double**
malloc_matrix_dbl(pTHX_ int nrows, int ncols, double val) {

	int i,j;
	double ** matrix;

	matrix = malloc(nrows * sizeof(double*) );
	for (i = 0; i < nrows; ++i) { 
		matrix[i] = malloc(ncols * sizeof(double) );
		for (j = 0; j < ncols; j++) { 
			matrix[i][j] = val;
		}
	}
	return matrix;
}

/* -------------------------------------------------
 * Create a 2D matrix of ints, initialized to a value
 */
static int**
malloc_matrix_int(pTHX_ int nrows, int ncols, int val) {

	int i,j;
	int ** matrix;

	matrix = malloc(nrows * sizeof(int*) );
	for (i = 0; i < nrows; ++i) { 
		matrix[i] = malloc(ncols * sizeof(int) );
		for (j = 0; j < ncols; j++) { 
			matrix[i][j] = val;
		}
	}
	return matrix;
}

/* -------------------------------------------------
 * Create a row of doubles, initialized to a value
 */
static double*
malloc_row_dbl(pTHX_ int ncols, double val) {

	int j;
	double * row;

	row = malloc(ncols * sizeof(double) );
	for (j = 0; j < ncols; j++) { 
		row[j] = val;
	}
	return row;
}

/* -------------------------------------------------
 * Only coerce to a double if we already know it's 
 * an integer or double, or a string which is actually numeric.
 * Don't blindly run the macro SvNV, because that will coerce 
 * a non-numeric string to be a double of value 0.0, 
 * and we do not want that to happen, because if we test it again, 
 * it will then appear to be a valid double value. 
 */
static int
extract_double_from_scalar(pTHX_ SV * mysv, double * number) {

	if (SvPOKp(mysv) && SvLEN(mysv)) {  

		/* This function is not in the public perl API */
		if (Perl_looks_like_number(aTHX_ mysv)) {
			*number = SvNV( mysv );
			return 1;
		} else {
			return 0;
		} 
	} else if (SvNIOK(mysv)) {  
		*number = SvNV( mysv );
		return 1;
	} else {
		return 0;
	}
}



/* -------------------------------------------------
 * Convert a Perl 2D matrix into a 2D matrix of C doubles.
 * NOTE: on errors this function returns a value greater than zero.
 */
static double**
parse_data(pTHX_ SV * matrix_ref) {

	AV * matrix_av;
	SV * row_ref;
	AV * row_av;
	SV * cell;

	int type, i, j, nrows, ncols, n;

	double** matrix;

	/* NOTE -- we will just assume that matrix_ref points to an arrayref,
	 * and that the first item in the array is itself an arrayref.
	 * The calling perl functions must check this before we get this pointer.  
	 * (It's easier to implement these checks in Perl rather than C.)
	 * The value of perl_rows is now fixed. But the value of
	 * rows will be decremented, if we skip any (invalid) Perl rows.
	 */
	matrix_av  = (AV *) SvRV(matrix_ref);
	nrows = (int) av_len(matrix_av) + 1;

	if(nrows <= 0) {
		return NULL;  /* Caller must handle this case!! */
	}

	row_ref  = *(av_fetch(matrix_av, (I32) 0, 0)); 
	row_av   = (AV *) SvRV(row_ref);
	ncols    = (int) av_len(row_av) + 1;

	matrix   = malloc(nrows*sizeof(double*));


	/* ------------------------------------------------------------ 
	 * Loop once for each row in the Perl matrix, and convert it to
         * C doubles. 
	 */
	for (i=0; i < nrows; i++) { 

		row_ref = *(av_fetch(matrix_av, (I32) i, 0)); 

		if(! SvROK(row_ref) ) {

			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Wanted array reference, but "
					"got a scalar. No row to process?\n");
			break;
		}

		row_av = (AV *) SvRV(row_ref);
		type = SvTYPE(row_av); 
	
		/* Handle unexpected cases */
		if(type != SVt_PVAV ) {

		 	/* Reference doesn't point to an array at all. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Wanted array reference, but got "
					"a reference to something else (%d)\n",
					i, type);
			break;

		}

		n = (int) av_len(row_av) + 1;
		if (n != ncols) {
			/* All rows in the matrix should have the same
			 * number of columns. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Contains %d columns "
					"(expected %d)\n", i, n, ncols);
			break;
		}

		matrix[i] = malloc(ncols*sizeof(double));

		/* Loop once for each cell in the row. */
		for (j=0; j < ncols; j++) { 
		
			double num;
			cell = *(av_fetch(row_av, (I32) j, 0)); 
			if(extract_double_from_scalar(aTHX_ cell,&num) <= 0) {	
				if(warnings_enabled(aTHX))
					Perl_warn(aTHX_ 
						"Row %d col %d: Value is not "
                                                "a number.\n", i, j);
				free(matrix[i]); /* not included below */
				break;
			}
			matrix[i][j] = num;

		} /* End for (j=0; j < ncols; j++) */
		if (j < ncols) break;

	} /* End for (i=0; i < nrows; i++) */

	if (i < nrows) { /* encountered a break */
		nrows = i;
		for (i = 0; i < nrows; i++) free(matrix[i]);
		free(matrix);
		matrix = NULL;
	}

	return matrix;
}


/* -------------------------------------------------
 * Convert a Perl 2D matrix into a 2D matrix of C ints.
 * On errors this function returns a value greater than zero.
 */
static int**
parse_mask(pTHX_ SV * matrix_ref) {

	AV * matrix_av;
	SV * row_ref;
	AV * row_av;
	SV * cell;

	int type, i, j, nrows, ncols, n;

	int** matrix;

	/* NOTE -- we will just assume that matrix_ref points to an arrayref,
	 * and that the first item in the array is itself an arrayref.
	 * The calling perl functions must check this before we get this pointer.  
	 * (It's easier to implement these checks in Perl rather than C.)
	 * The value of perl_rows is now fixed. But the value of
	 * rows will be decremented, if we skip any (invalid) Perl rows.
	 */
	matrix_av = (AV *) SvRV(matrix_ref);
	nrows = (int) av_len(matrix_av) + 1;

	if(nrows <= 0) {
		return NULL;  /* Caller must handle this case!! */
	}

	row_ref   = *(av_fetch(matrix_av, (I32) 0, 0)); 
	row_av    = (AV *) SvRV(row_ref);
	ncols     = (int) av_len(row_av) + 1;

	matrix    = malloc(nrows * sizeof(int *) );


	/* ------------------------------------------------------------ 
	 * Loop once for each row in the Perl matrix, and convert it to C ints. 
	 */
	for (i=0; i < nrows; i++) { 

		row_ref = *(av_fetch(matrix_av, (I32) i, 0)); 

		if(! SvROK(row_ref) ) {

			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Wanted array reference, but "
					"got a scalar. No row to process?\n");
			break;
		}

		row_av = (AV *) SvRV(row_ref);
		type = SvTYPE(row_av); 
	
		/* Handle unexpected cases */
		if(type != SVt_PVAV ) {

		 	/* Reference doesn't point to an array at all. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Wanted array reference, but got "
					"a reference to something else (%d)\n",
					i, type);
			break;

		}

		n = (int) av_len(row_av) + 1;
		if (n != ncols) {
			/* All rows in the matrix should have the same
			 * number of columns. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %d: Contains %d columns "
					"(expected %d)\n", i, n, ncols);
			break;
		}

		matrix[i] = malloc(ncols * sizeof(int) );

		/* Loop once for each cell in the row. */
		for (j=0; j < ncols; ++j) { 
			double num;
			cell = *(av_fetch(row_av, (I32) j, 0)); 
			if(extract_double_from_scalar(aTHX_ cell,&num) <= 0) {	
				if(warnings_enabled(aTHX))
					Perl_warn(aTHX_
						"Row %d col %d: Value is not "
						"a number.\n", i, j);
				free(matrix[i]); /* not included below */
				break;
			}
			matrix[i][j] = (int) num;

		} /* End for (j=0; j < ncols; j++) */
		if (j < ncols) break;

	} /* End for (i=0; i < nrows; i++) */

	if (i < nrows) { /* break statement encountered */
		nrows = i;
		for (i = 0; i < nrows; i++) free(matrix[i]);
		free(matrix);
		matrix = NULL;
	}

	return matrix;
}


/* -------------------------------------------------
 *
 */
static void
free_matrix_int(int ** matrix, int nrows) {

	int i;
	for(i = 0; i < nrows; ++i ) {
		free(matrix[i]);
	}

	free(matrix);
}


/* -------------------------------------------------
 *
 */
static void
free_matrix_dbl(double ** matrix, int nrows) {

	int i;
	for(i = 0; i < nrows; ++i ) {
		free(matrix[i]);
	}

	free(matrix);
}


/* -------------------------------------------------
 *
 */
static void
free_ragged_matrix_dbl(double ** matrix, int nrows) {

	int i;
	for(i = 1; i < nrows; ++i ) {
		free(matrix[i]);
	}

	free(matrix);
}

/* -------------------------------------------------
 * For debugging
 */
static void
print_matrix_dbl(pTHX_ double ** matrix, int rows, int columns) {

	int i,j;

	for (i = 0; i < rows; i++) { 
		printf("Row %3d:  ",i);
		for (j = 0; j < columns; j++) { 
			printf(" %7.2f", matrix[i][j]);
		}
		printf("\n");
	}
}


/* -------------------------------------------------
 * For debugging
 */
static SV*
format_matrix_dbl(pTHX_ double ** matrix, int rows, int columns) {

	int i,j;
	SV * output = newSVpv("", 0);

	for (i = 0; i < rows; i++) { 
		sv_catpvf(output, "Row %3d:  ", i);
		for (j = 0; j < columns; j++) { 
			sv_catpvf(output, " %7.2f", matrix[i][j]);
		}
		sv_catpvf(output, "\n");
	}

	return(output);
}



/* -------------------------------------------------
 * Convert a Perl array into an array of doubles
 * On error, this function returns NULL.
 */
static double*
malloc_row_perl2c_dbl (pTHX_ SV * input, int* np) {

	int i;
	AV* array    = (AV *) SvRV(input);
	const int n  = (int) av_len(array) + 1;
	double* data = malloc(n * sizeof(double)); 


	/* Loop once for each item in the Perl array, and convert
         * it to a C double. 
	 */
	for (i=0; i < n; i++) {
		double num;
		SV * mysv = *(av_fetch(array, (I32) i, (I32) 0));
		if(extract_double_from_scalar(aTHX_ mysv,&num) > 0) {	
			data[i] = num;
		} else {
			/* Error reading data */
    			if (warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
			"Error parsing array: item %d is not a number\n", i);      
			free(data);
			return NULL;
		}
	}
	if(np) *np = n;
	return data;
}

/* -------------------------------------------------
 * Convert a Perl array into an array of ints
 * On errors this function returns a value greater than zero.
 * If there are errors, then the C array will be SHORTER than
 * the original Perl array.
 */
static int*
malloc_row_perl2c_int (pTHX_ SV * input) {

	int i;

	AV* array = (AV *) SvRV(input);
	const int n = (int) av_len(array) + 1;
	int* data = malloc(n*sizeof(int)); 

	if(!data) return NULL;

	/* Loop once for each item in the Perl array,
         * and convert it to a C double. 
	 */
	for (i=0; i < n; i++) {
		double num;
		SV * mysv = *(av_fetch(array, (I32) i, (I32) 0));
		if(extract_double_from_scalar(aTHX_ mysv,&num) > 0) {	
			data[i] = (int) num;
		} else {
			/* Skip any items which are not numeric */
    			if (warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Error when parsing array: item %d is"
					" not a number, skipping\n", i);      
			break;
		}
	}

	if (i < n) { /* encountered the break statement */
		free(data);
		return NULL;
	}

	return data;
}

/* -------------------------------------------------
 *
 */
static SV*
matrix_c_array_2perl_int(pTHX_ int matrix[][2], int nrows, int ncols) {

	int i,j;
	AV * matrix_av = newAV();
	AV * row_av;
	SV * row_ref;
	for(i=0; i<nrows; ++i) {
		row_av = newAV();
		for(j=0; j<ncols; ++j) {
			av_push(row_av, newSViv(matrix[i][j]));
			/* printf("%d,%d: %d\n",i,j,matrix[i][j]); */
		}
		row_ref = newRV( (SV*) row_av );
		av_push(matrix_av, row_ref);
	}
	return ( newRV_noinc( (SV*) matrix_av ) );
}

/* -------------------------------------------------
 *
 */
static SV *
row_c2perl_dbl(pTHX_ double * row, int ncols) {

	int j;
	AV * row_av = newAV();
	for(j=0; j<ncols; ++j) {
		av_push(row_av, newSVnv(row[j]));
		/* printf("%d: %7.3f\n", j, row[j]); */
	}
	return ( newRV_noinc( (SV*) row_av ) );
}

/* -------------------------------------------------
 *
 */
static SV*
row_c2perl_int(pTHX_ int * row, int ncols) {

	int j;
	AV * row_av = newAV();
	for(j=0; j<ncols; ++j) {
		av_push(row_av, newSVnv(row[j]));
	}
	return ( newRV_noinc( (SV*) row_av ) );
}

/* -------------------------------------------------
 *
 */
static SV*
matrix_c2perl_int(pTHX_ int ** matrix, int nrows, int ncols) {

	int i;
	AV * matrix_av = newAV();
	SV * row_ref;
	for(i=0; i<nrows; ++i) {
		row_ref = row_c2perl_int(aTHX_ matrix[i], ncols);
		av_push(matrix_av, row_ref);
	}
	return ( newRV_noinc( (SV*) matrix_av ) );
}

/* -------------------------------------------------
 *
 */
static SV*
matrix_c2perl_dbl(pTHX_ double ** matrix, int nrows, int ncols) {

	int i;
	AV * matrix_av = newAV();
	SV * row_ref;
	for(i=0; i<nrows; ++i) {
		row_ref = row_c2perl_dbl(aTHX_ matrix[i], ncols);
		av_push(matrix_av, row_ref);
	}
	return ( newRV_noinc( (SV*) matrix_av ) );
}

/* -------------------------------------------------
 *
 */
static SV*
ragged_matrix_c2perl_dbl(pTHX_ double ** matrix, int nobjects) {

	int i;
	AV * matrix_av = newAV();
	SV * row_ref;
	for(i=0; i<nobjects; ++i) {
		row_ref = row_c2perl_dbl(aTHX_ matrix[i], i);
		av_push(matrix_av, row_ref);
	}
	return ( newRV_noinc( (SV*) matrix_av ) );
}

/* -------------------------------------------------
 * Convert the 'data' and 'mask' matrices and the 'weight' array
 * from C to Perl.  Also check for errors, and ignore the
 * mask or the weight array if there are any errors. 
 * Print warnings so the user will know what happened. 
 */
static int
malloc_matrices(pTHX_
	SV *  weight_ref, double  ** weight, int nweights, 
	SV *  data_ref,   double *** matrix,
	SV *  mask_ref,   int    *** mask,
	int   nrows,      int        ncols
) {

	if(SvTYPE(SvRV(mask_ref)) == SVt_PVAV) { 
		*mask = parse_mask(aTHX_ mask_ref);
		if(*mask==NULL) return 0;
	} else {
		*mask = malloc_matrix_int(aTHX_ nrows,ncols,1);
	}

	/* We don't check data_ref because we expect the caller to check it 
	 */
	*matrix = parse_data(aTHX_ data_ref);
	if(*matrix==NULL) {
		if(warnings_enabled(aTHX)) 
			Perl_warn(aTHX_ "Error parsing data matrix.\n");      
		return 0;
	}

	if(SvTYPE(SvRV(weight_ref)) == SVt_PVAV) { 
		*weight = malloc_row_perl2c_dbl(aTHX_ weight_ref, NULL);
		if(!(*weight)) {
			Perl_warn(aTHX_ "Error reading weight array.\n");
			return 0;
		}
	} else {
		*weight = malloc_row_dbl(aTHX_ nweights,1.0);
	}

	return 1;
}

static double**
parse_distance(pTHX_ SV* matrix_ref, int nobjects)
{
	int i,j;

	AV* matrix_av  = (AV *) SvRV(matrix_ref);
	double** matrix = malloc(nobjects*sizeof(double*));

	matrix[0] = NULL;
	for (i=1; i < nobjects; i++) { 
		SV* row_ref = *(av_fetch(matrix_av, (I32) i, 0)); 
		AV* row_av  = (AV *) SvRV(row_ref);
		matrix[i] = malloc(i * sizeof(double));
		/* Loop once for each cell in the row. */
		for (j=0; j < i; j++) { 
			double num;
			SV* cell = *(av_fetch(row_av, (I32) j, 0)); 
			if(extract_double_from_scalar(aTHX_ cell,&num) > 0) {	
				matrix[i][j] = num;
			} else {
				if(warnings_enabled(aTHX))
					Perl_warn(aTHX_ 
						"Row %d col %d: Value is not "
                                                "a number.\n", i, j);
				break;
			}
		}
	}

	if (i < nobjects) {
		nobjects = i+1;
		for (i = 1; i < nobjects; i++) free(matrix[i]);
		free(matrix);
		matrix = NULL;
	}

	return matrix;
}

/******************************************************************************/
/**                                                                          **/
/** XS code begins here                                                      **/
/**                                                                          **/
/******************************************************************************/
/******************************************************************************/

MODULE = Algorithm::Cluster	PACKAGE = Algorithm::Cluster
PROTOTYPES: ENABLE


SV *
_hello()
   CODE:
   printf("Hello, world!\n");
	RETVAL = newSVpv("Hello world!!\n", 0);

	OUTPUT:
	RETVAL

int
_readprint(input)
	SV *      input;
	PREINIT:
	double ** matrix;  /* two-dimensional matrix of doubles */

	CODE:
	matrix = parse_data(aTHX_ input);

	if(matrix != NULL) {
		AV* matrix_av = (AV *) SvRV(input);
		SV * row_ref = *(av_fetch(matrix_av, (I32) 0, 0));
		AV * row_av = (AV *) SvRV(row_ref);
		const int nrows = (int) av_len(matrix_av) + 1;
        	const int ncols = (int) av_len(row_av) + 1;
		print_matrix_dbl(aTHX_ matrix,nrows,ncols);
		free_matrix_dbl(matrix,nrows);
		RETVAL = 1;
	} else {
		RETVAL = 0;
	}

	OUTPUT:
	RETVAL


SV *
_readformat(input)
	SV *      input;
	PREINIT:
	double ** matrix;  /* two-dimensional matrix of doubles */

	CODE:
	matrix = parse_data(aTHX_ input);

	if(matrix != NULL) {
                AV* matrix_av = (AV *) SvRV(input);
                SV * row_ref = *(av_fetch(matrix_av, (I32) 0, 0));
                AV * row_av = (AV *) SvRV(row_ref);
                const int nrows = (int) av_len(matrix_av) + 1;
                const int ncols = (int) av_len(row_av) + 1;
		RETVAL = format_matrix_dbl(aTHX_ matrix,nrows,ncols);
		free_matrix_dbl(matrix,nrows);
	} else {
		RETVAL = newSVpv("",0);
	}

	OUTPUT:
	RETVAL


SV *
_mean(input)
	SV * input;

	PREINIT:
	int array_length;
	double * data;  /* one-dimensional array of doubles */

	CODE:
	if(SvTYPE(SvRV(input)) != SVt_PVAV) { 
		XSRETURN_UNDEF;
	}

	data = malloc_row_perl2c_dbl (aTHX_ input, &array_length);
	if (data) {
		RETVAL = newSVnv( mean(array_length, data) );
		free(data);
	} else {
		RETVAL = newSVnv( 0.0 );
	}

	OUTPUT:
	RETVAL


SV *
_median(input)
	SV * input;

	PREINIT:
	int array_length;
	double * data;  /* one-dimensional array of doubles */

	CODE:
	if(SvTYPE(SvRV(input)) != SVt_PVAV) { 
		XSRETURN_UNDEF;
	}

	data = malloc_row_perl2c_dbl (aTHX_ input, &array_length);
	if(data) {
		RETVAL = newSVnv( median(array_length, data) );
		free(data);
	} else {
		RETVAL = newSVnv( 0.0 );
	}

	OUTPUT:
	RETVAL


void
_treecluster(nrows,ncols,data_ref,mask_ref,weight_ref,transpose,dist,method)
    int      nrows;
    int      ncols;
    SV *     data_ref;
    SV *     mask_ref;
    SV *     weight_ref;
    int      transpose;
    char *   dist;
    char *   method;

    PREINIT:
    SV   *    result_ref;
    SV   *    linkdist_ref;
    int       (*result)[2];
    double   * linkdist;

    double  * weight;
    double ** matrix;
    int    ** mask;
    const int ndata = transpose ? nrows : ncols;
    const int nelements = transpose ? ncols : nrows;
    int       success;

    PPCODE:
    /* ------------------------
     * Don't check the parameters, because we rely on the Perl
     * caller to check most paramters.
     */

    /* ------------------------
     * Malloc space for result[][2] and linkdist[]. 
     * Don't bother to cast the pointer for 'result', because we can't 
     * cast it to a pointer-to-array anyway. 
     */
    result   = malloc(2 * (nelements-1) * sizeof(int) );
    linkdist = malloc(    (nelements-1) * sizeof(double) );

    /* ------------------------
     * Convert data and mask matrices and the weight array
     * from C to Perl.  Also check for errors, and ignore the
     * mask or the weight array if there are any errors. 
     */
    malloc_matrices( aTHX_
	weight_ref, &weight, ndata, 
	data_ref,   &matrix,
	mask_ref,   &mask,  
	nrows,      ncols
    );

    /* ------------------------
     * Run the library function
     */
    success = treecluster( nrows, ncols, matrix, mask, weight, transpose,
                           dist[0], method[0], result, linkdist, 0);

    /* ------------------------
     * Check result to make sure we didn't run into memory problems
     */
    if(!success) {
        /* treecluster failed due to insufficient memory */
	if(warnings_enabled(aTHX))
            Perl_warn(aTHX_ "treecluster failed due to insufficient memory.\n");
    }
    else {

        /* ------------------------
         * Convert generated C matrices to Perl matrices
         */
        if (transpose==0) {
            result_ref   = matrix_c_array_2perl_int(aTHX_ result,   nrows-1, 2);
            linkdist_ref =           row_c2perl_dbl(aTHX_ linkdist, nrows-1   ); 
        } else {
            result_ref   = matrix_c_array_2perl_int(aTHX_ result,   ncols-1, 2);
            linkdist_ref =           row_c2perl_dbl(aTHX_ linkdist, ncols-1   );
        }

        /* ------------------------
         * Push the new Perl matrices onto the return stack
         */
        XPUSHs(sv_2mortal( result_ref   ));
        XPUSHs(sv_2mortal( linkdist_ref ));
    }

    /* ------------------------
     * Free what we've malloc'ed 
     */
    free_matrix_int(mask,     nrows);
    free_matrix_dbl(matrix,   nrows);

    free(weight);
    free(result);
    free(linkdist);

    /* Finished _treecluster() */


void
_kcluster(nclusters,nrows,ncols,data_ref,mask_ref,weight_ref,transpose,npass,method,dist,initialid_ref)
	int      nclusters;
	int      nrows;
	int      ncols;
	SV *     data_ref;
	SV *     mask_ref;
	SV *     weight_ref;
	int      transpose;
	int      npass;
	char *   method;
	char *   dist;
	SV *     initialid_ref;

	PREINIT:
	SV  *    clusterid_ref;
	int *    clusterid;
	int *    initialid;
	int      nobjects;
	int      ndata;
	double   error;
	int      ifound;

	double  * weight;
	double ** matrix;
	int    ** mask;


	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most parameters.
	 */

	/* ------------------------
	 * Malloc space for the return values from the library function
	 */
        if (transpose==0) {
		nobjects = nrows;
		ndata = ncols;
	} else {
		nobjects = ncols;
		ndata = nrows;
	}
        clusterid = malloc(nobjects * sizeof(int) );

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, ndata, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* ------------------------
	 * Copy initialid to clusterid, if needed
	 */

	if (npass==0) {
		int       i;
		initialid = malloc_row_perl2c_int(aTHX_ initialid_ref);
		for (i = 0; i < nobjects; i++) clusterid[i] = initialid[i];
	}

	/* ------------------------
	 * Run the library function
	 */
	kcluster( 
		nclusters, nrows, ncols, 
		matrix, mask, weight, transpose,
		npass, method[0], dist[0], clusterid,  &error, &ifound
		
	);

	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	clusterid_ref =    row_c2perl_int(aTHX_ clusterid, nobjects);

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal( clusterid_ref   ));
	XPUSHs(sv_2mortal( newSVnv(error) ));
	XPUSHs(sv_2mortal( newSViv(ifound) ));

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free(clusterid);
	free_matrix_int(mask,     nrows);
	free_matrix_dbl(matrix,   nrows);
	free(weight);
	if (npass==0) free(initialid);

	/* Finished _kcluster() */



void
_kmedoids(nclusters,nobjects,distancematrix_ref,npass,initialid_ref)
	int      nclusters;
	int      nobjects;
	SV *     distancematrix_ref;
	int      npass;
	SV *     initialid_ref;


	PREINIT:
	double** distancematrix;
	int *    initialid;
	SV  *    clusterid_ref;
	int *    clusterid;
	double   error;
	int      ifound;



	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most parameters.
	 */

	/* ------------------------
	 * Malloc space for the return values from the library function
	 */
	clusterid = malloc(nobjects * sizeof(int) );

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	distancematrix = parse_distance(aTHX_ distancematrix_ref, nobjects);

	/* ------------------------
	 * Copy initialid to clusterid, if needed
	 */

	if (npass==0) {
		int       i;
		initialid = malloc_row_perl2c_int(aTHX_ initialid_ref);
		for (i = 0; i < nobjects; i++) clusterid[i] = initialid[i];
	}

	/* ------------------------
	 * Run the library function
	 */
	kmedoids( 
		nclusters, nobjects, 
		distancematrix, npass, clusterid, 
		&error, &ifound
	);

	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	clusterid_ref =    row_c2perl_int(aTHX_ clusterid, nobjects);

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal( clusterid_ref   ));
	XPUSHs(sv_2mortal( newSVnv(error) ));
	XPUSHs(sv_2mortal( newSViv(ifound) ));

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free(clusterid);
	free_ragged_matrix_dbl(distancematrix, nobjects);
	if (npass==0) free(initialid);

	/* Finished _kmedoids() */



double
_clusterdistance(nrows,ncols,data_ref,mask_ref,weight_ref,cluster1_len,cluster2_len,cluster1_ref,cluster2_ref,dist,method,transpose)
	int      nrows;
	int      ncols;
	SV *     data_ref;
	SV *     mask_ref;
	SV *     weight_ref;
	int      cluster1_len;
	int      cluster2_len;
	SV *     cluster1_ref;
	SV *     cluster2_ref;
	char *   dist;
	char *   method;
	int      transpose;

	PREINIT:
	int   nweights;

	int     * cluster1;
	int     * cluster2;

	double  * weight;
	double ** matrix;
	int    ** mask;

	double distance;

	CODE:

	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most paramters.
	 */

	/* ------------------------
	 * Convert cluster index Perl arrays to C arrays
	 */
	cluster1 = malloc_row_perl2c_int(aTHX_ cluster1_ref);
	cluster2 = malloc_row_perl2c_int(aTHX_ cluster2_ref);

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 * Set nweights to the correct number of weights.
	 */
	nweights = (transpose==0) ? ncols : nrows;
	malloc_matrices( aTHX_
		weight_ref, &weight, nweights, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);


	/* ------------------------
	 * Run the library function
	 */
	distance = clusterdistance( 
		nrows, ncols, 
		matrix, mask, weight,
		cluster1_len, cluster2_len, cluster1, cluster2,
		dist[0], method[0], transpose
	);

	RETVAL = distance;

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free_matrix_int(mask,     nrows);
	free_matrix_dbl(matrix,   nrows);
	free(weight);
	free(cluster1);
	free(cluster2);

	/* Finished _clusterdistance() */

	OUTPUT:
	RETVAL



void
_distancematrix(nrows,ncols,data_ref,mask_ref,weight_ref,transpose,dist)
	int      nrows;
	int      ncols;
	SV *     data_ref;
	SV *     mask_ref;
	SV *     weight_ref;
	int      transpose;
	char *   dist;

	PREINIT:
	SV  *    matrix_ref;
	int      nobjects;
	int      ndata;

	double ** data;
	int    ** mask;
	double  * weight;
	double ** matrix;


	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most parameters.
	 */

	/* ------------------------
	 * Malloc space for the return values from the library function
	 */
        if (transpose==0) {
		nobjects = nrows;
		ndata = ncols;
	} else {
		nobjects = ncols;
		ndata = nrows;
	}

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, ndata, 
		data_ref,   &data,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* ------------------------
	 * Run the library function
	 */
        matrix = distancematrix (nrows,
                                 ncols,
                                 data,
                                 mask,
                                 weight,
                                 dist[0],
                                 transpose);


	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	matrix_ref  = ragged_matrix_c2perl_dbl(aTHX_ matrix,  nobjects);

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal(matrix_ref));

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free_ragged_matrix_dbl(matrix, nobjects);
	free_matrix_int(mask, nrows);
	free_matrix_dbl(data, nrows);
	free(weight);

	/* Finished _distancematrix() */


void
_somcluster(nrows,ncols,data_ref,mask_ref,weight_ref,transpose,nxgrid,nygrid,inittau,niter,dist)
	int      nrows;
	int      ncols;
	SV *     data_ref;
	SV *     mask_ref;
	SV *     weight_ref;
	int      transpose;
	int      nxgrid;
	int      nygrid;
	double   inittau;
	int      niter;
	char *   dist;

	PREINIT:
	int      (*clusterid)[2];
	SV *  clusterid_ref;
	double*** celldata;
	SV *  celldata_ref;

	double  * weight;
	double ** matrix;
	int    ** mask;
	int       nweights;

	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most paramters.
	 */

	/* ------------------------
	 * Allocate space for clusterid[][2]. 
	 * Don't bother to cast the pointer, because we can't cast
	 * it to a pointer-to-array anway. 
	 */
	if (transpose==0) {
		clusterid  =  malloc(2 * (nrows) * sizeof(int) );
	} else {
		clusterid  =  malloc(2 * (ncols) * sizeof(int) );
	}
	celldata  =  0;
	/* Don't return celldata, for now at least */


	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 * Set nweights to the correct number of weights.
	 */
	nweights = (transpose==0) ? ncols : nrows;
	malloc_matrices( aTHX_
		weight_ref, &weight, nweights, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* ------------------------
	 * Run the library function
	 */
	somcluster( 
		nrows, ncols, 
		matrix, mask, weight,
		transpose, nxgrid, nygrid, inittau, niter,
		dist[0], celldata, clusterid
	);

	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	clusterid_ref = matrix_c_array_2perl_int(aTHX_ clusterid, nrows, 2); 

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal( clusterid_ref   ));

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free_matrix_int(mask,     nrows);
	free_matrix_dbl(matrix,   nrows);
	free(weight);
	free(clusterid);

	/* Finished _somcluster() */

