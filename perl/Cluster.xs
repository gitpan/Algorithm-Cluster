#ifdef __cplusplus
extern "C" {
#endif

#include "Cluster.h"

#ifdef __cplusplus
}
#endif


/* -------------------------------------------------
 * Create a 2D matrix of doubles, initialized to a value
 */
double ** malloc_matrix_dbl(pTHX_ int nrows, int ncols, double val) {

	int i,j;
	double ** matrix;

	matrix = (double **) malloc( (size_t) nrows * sizeof(double*) );
	for (i = 0; i < nrows; ++i) { 
		matrix[i] = (double *) malloc( (size_t) ncols * sizeof(double) );
		for (j = 0; j < ncols; j++) { 
			matrix[i][j] = val;
		}
	}
	return matrix;
}

/* -------------------------------------------------
 * Create a 2D matrix of ints, initialized to a value
 */
int ** malloc_matrix_int(pTHX_ int nrows, int ncols, int val) {

	int i,j;
	int ** matrix;

	matrix = (int **) malloc( (size_t) nrows * sizeof(int*) );
	for (i = 0; i < nrows; ++i) { 
		matrix[i] = (int *) malloc( (size_t) ncols * sizeof(int) );
		for (j = 0; j < ncols; j++) { 
			matrix[i][j] = val;
		}
	}
	return matrix;
}

/* -------------------------------------------------
 * Create a row of doubles, initialized to a value
 */
double * malloc_row_dbl(pTHX_ int ncols, double val) {

	int j;
	double * row;

	row = (double *) malloc( (size_t) ncols * sizeof(double) );
	for (j = 0; j < ncols; j++) { 
		row[j] = val;
	}
	return row;
}


/* -------------------------------------------------
 * Convert a Perl 2D matrix into a 2D matrix of C doubles.
 * NOTE: on errors this function returns a value greater than zero.
 */
int malloc_matrix_perl2c_dbl(pTHX_ SV * matrix_ref, double *** matrix_ptr, 
	int * nrows_ptr, int * ncols_ptr, int ** mask) {

	AV * matrix_av;
	SV * row_ref;
	AV * row_av;
	SV * cell;

	int type, i,ii,j, perl_nrows, nrows, ncols;
	int ncols_in_this_row;
	int error_count = 0;

	double ** matrix;

	/* NOTE -- we will just assume that matrix_ref points to an arrayref,
	 * and that the first item in the array is itself an arrayref.
	 * The calling perl functions must check this before we get this pointer.  
	 * (It's easier to implement these checks in Perl rather than C.)
	 * The value of perl_rows is now fixed. But the value of
	 * rows will be decremented, if we skip any (invalid) Perl rows.
	 */
	matrix_av  = (AV *) SvRV(matrix_ref);
	perl_nrows = (int) av_len(matrix_av) + 1;
	nrows      = perl_nrows;

	if(perl_nrows <= 0) {
		matrix_ptr = NULL;
		return 1;  /* Caller must handle this case!! */
	}

	row_ref  = *(av_fetch(matrix_av, (I32) 0, 0)); 
	row_av   = (AV *) SvRV(row_ref);
	ncols    = (int) av_len(row_av) + 1;

	matrix   = (double **) malloc( (size_t) nrows * sizeof(double *) );


	/* ------------------------------------------------------------ 
	 * Loop once for each row in the Perl matrix, and convert it to C doubles. 
	 * Variable i  increments with each row in the Perl matrix. 
	 * Variable ii increments with each row in the C matrix. 
	 * Some Perl rows may be skipped, so variable ii will sometimes not increment.
	 */
	for (i=0, ii=0; i < perl_nrows; ++i,++ii) { 

		row_ref = *(av_fetch(matrix_av, (I32) i, 0)); 

		if(! SvROK(row_ref) ) {

			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %3d: Wanted array reference, but got "
					"a bare scalar. No row to process ??.\n");
			--ii;
			--nrows;
			error_count++;
			continue;
		}

		type = SvTYPE(SvRV(row_ref)); 
	
		/* Handle unexpected cases */
		if(type != SVt_PVAV ) {

		 	/* Handle the case where this reference doesn't point to an array at all. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %3d: Wanted array reference, but got "
					"a reference to something else (%d)\n", i, type);
			ncols_in_this_row = 0;

		} else {
			/* Handle the case where the matrix is (unexpectedly) ragged, 
			 * by noting the number of items in this row specifically. */
			row_av = (AV *) SvRV(row_ref);
			ncols_in_this_row = (int) av_len(row_av) + 1;
		}

		matrix[ii] = (double *) malloc( (size_t) ncols * sizeof(double) );

		/* Loop once for each cell in the row. */
		for (j=0; j < ncols; ++j) { 
			if(j>=ncols_in_this_row) {
				/* Handle the case where the matrix is (unexpectedly) ragged */
				matrix[ii][j] = 0.0;
				if(mask != NULL) mask[ii][j] = 0;
				error_count++;
				if(warnings_enabled(aTHX))
					Perl_warn(aTHX_ 
						"Row %3d col %3d: Row is too short.  Inserting zero into cell.\n", ii, j);
			} else {
				double num;
				cell = *(av_fetch(row_av, (I32) j, 0)); 
				if(extract_double_from_scalar(aTHX_ cell,&num) > 0) {	
					matrix[ii][j] = num;
				} else {
					if(warnings_enabled(aTHX))
						Perl_warn(aTHX_ 
							"Row %3d col %3d: Value is not a number.  Inserting zero into cell.\n", ii, j);
					matrix[ii][j] = 0.0;
					if(mask != NULL) mask[ii][j] = 0;
					error_count++;
				}
			}

		} /* End for (j=0; j < ncols; j++) */

	} /* End for (i=0, ii=0; i < nrows; i++) */


	/* Return pointer and dimensions to the caller */
	*matrix_ptr  = matrix;
	*nrows_ptr   = nrows;
	*ncols_ptr   = ncols;

	return(error_count);
}


/* -------------------------------------------------
 * Convert a Perl 2D matrix into a 2D matrix of C ints.
 * On errors this function returns a value greater than zero.
 */
int malloc_matrix_perl2c_int (pTHX_ SV * matrix_ref, int *** matrix_ptr, int * nrows_ptr, int * ncols_ptr) {

	AV * matrix_av;
	SV * row_ref;
	AV * row_av;
	SV * cell;

	int type, i,ii,j, perl_nrows, nrows, ncols;
	int ncols_in_this_row;
	int error_count = 0;

	int ** matrix;

	/* NOTE -- we will just assume that matrix_ref points to an arrayref,
	 * and that the first item in the array is itself an arrayref.
	 * The calling perl functions must check this before we get this pointer.  
	 * (It's easier to implement these checks in Perl rather than C.)
	 * The value of perl_rows is now fixed. But the value of
	 * rows will be decremented, if we skip any (invalid) Perl rows.
	 */
	matrix_av = (AV *) SvRV(matrix_ref);
	perl_nrows = (int) av_len(matrix_av) + 1;
	nrows      = perl_nrows;

	if(perl_nrows <= 0) {
		matrix_ptr = NULL;
		return 1;  /* Caller must handle this case!! */
	}

	row_ref   = *(av_fetch(matrix_av, (I32) 0, 0)); 
	row_av    = (AV *) SvRV(row_ref);
	ncols     = (int) av_len(row_av) + 1;

	matrix    = (int **) malloc( (size_t) nrows * sizeof(int *) );


	/* ------------------------------------------------------------ 
	 * Loop once for each row in the Perl matrix, and convert it to C ints. 
	 * Variable i  increments with each row in the Perl matrix. 
	 * Variable ii increments with each row in the C matrix. 
	 * Some Perl rows may be skipped, so variable ii will sometimes not increment.
	 */
	for (i=0, ii=0; i < perl_nrows; ++i,++ii) { 

		row_ref = *(av_fetch(matrix_av, (I32) i, 0)); 

		if(! SvROK(row_ref) ) {

			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %3d: Wanted array reference, but got "
					"a bare scalar. No row to process ??.\n");
			--ii;
			--nrows;
			error_count++;
			continue;
		}

		type = SvTYPE(SvRV(row_ref)); 
	
		/* Handle unexpected cases */
		if(type != SVt_PVAV ) {

		 	/* Handle the case where this reference doesn't point to an array at all. */
			if(warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Row %3d: Wanted array reference, but got "
					"a reference to something else (%d)\n", i, type);
			ncols_in_this_row = 0;

		} else {
			/* Handle the case where the matrix is (unexpectedly) ragged. */
			row_av = (AV *) SvRV(row_ref);
			ncols_in_this_row = (int) av_len(row_av) + 1;
		}

		matrix[ii] = (int *) malloc( (size_t) ncols * sizeof(int) );

		/* Loop once for each cell in the row. */
		for (j=0; j < ncols; ++j) { 
			if(j>=ncols_in_this_row) {
				matrix[ii][j] = 0;
				error_count++;
			} else {
				double num;
				cell = *(av_fetch(row_av, (I32) j, 0)); 
				if(extract_double_from_scalar(aTHX_ cell,&num) > 0) {	
					matrix[ii][j] = (int) num;
				} else {
					if(warnings_enabled(aTHX))
						Perl_warn(aTHX_ "Row %3d col %3d is not a number, setting cell to 0\n", i, j);
					matrix[ii][j] = 0;
					error_count++;
				}
			}

		} /* End for (j=0; j < ncols; j++) */

	} /* End for (i=0, ii=0; i < nrows; i++) */


	/* Return pointer and dimensions to the caller */
	*matrix_ptr  = matrix;
	*nrows_ptr   = nrows;
	*ncols_ptr   = ncols;

	return(error_count);
}


/* -------------------------------------------------
 *
 */
void free_matrix_int(int ** matrix, int nrows) {

	int i;
	for(i = 0; i < nrows; ++i ) {
		free(matrix[i]);
	}

	free(matrix);
}


/* -------------------------------------------------
 *
 */
void free_matrix_dbl(double ** matrix, int nrows) {

	int i;
	for(i = 0; i < nrows; ++i ) {
		free(matrix[i]);
	}

	free(matrix);
}


/* -------------------------------------------------
 * For debugging
 */
void print_row_int(pTHX_ int * row, int columns) {

	int i;

	for (i = 0; i < columns; i++) { 
		printf(" %3d", row[i]);
	}
	printf("\n");
}

/* -------------------------------------------------
 * For debugging
 */
void print_row_dbl(pTHX_ double * row, int columns) {

	int i;

	for (i = 0; i < columns; i++) { 
		printf(" %7.3f", row[i]);
	}
	printf("\n");
}


/* -------------------------------------------------
 * For debugging
 */
void print_matrix_int(pTHX_ int ** matrix, int rows, int columns) {

	int i,j;

	for (i = 0; i < rows; i++) { 
		printf("Row %3d:  ",i);
		for (j = 0; j < columns; j++) { 
			printf(" %3d", matrix[i][j]);
		}
		printf("\n");
	}
}

/* -------------------------------------------------
 * For debugging
 */
void print_matrix_dbl(pTHX_ double ** matrix, int rows, int columns) {

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
SV * format_matrix_dbl(pTHX_ double ** matrix, int rows, int columns) {

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
 * Only coerce to a double if we already know it's 
 * an integer or double, or a string which is actually numeric.
 * Don't blindly run the macro SvNV, because that will coerce 
 * a non-numeric string to be a double of value 0.0, 
 * and we do not want that to happen, because if we test it again, 
 * it will then appear to be a valid double value. 
 */
int extract_double_from_scalar(pTHX_ SV * mysv, double * number) {

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
 * Using the warnings registry, check to see if warnings
 * are enabled for the Algorithm::Cluster module.
 */
int warnings_enabled(pTHX) {

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
 * Convert a Perl array into an array of doubles
 * On errors this function returns a value greater than zero.
 * If there are errors, then the C array will be SHORTER than
 * the original Perl array.
 */
int malloc_row_perl2c_dbl (pTHX_ SV * input, double ** array_ptr, int * array_length_ptr) {

	AV * array;
	int i,ii;
	int array_length,original_array_length;
	double * data;
	int error_count = 0;

	array                 = (AV *) SvRV(input);
	array_length          = (int) av_len(array) + 1;
	original_array_length =  array_length;
	data                  = (double *) malloc( (size_t) original_array_length * sizeof(double) ); 

	/* Loop once for each item in the Perl array, and convert it to a C double. 
	 * Variable i  increments with each item in the Perl array. 
	 * Variable ii increments with each item in the C array. 
	 * Some Perl items may be skipped, so variable ii will sometimes not increment.
	 */
	for (i=0,ii=0; i < original_array_length; ++i,++ii) {
		double num;
		SV * mysv = *(av_fetch(array, (I32) i, (I32) 0));
		if(extract_double_from_scalar(aTHX_ mysv,&num) > 0) {	
			data[ii] = num;
		} else {
			/* Skip any items which are not numeric */
    		if (warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Warning when parsing array: item %d is not a number, skipping\n", i);      
			data[ii] = 0.0;
			--ii;
			--array_length;  
			error_count++;
		}
	}
	*array_ptr        = data;
	*array_length_ptr = array_length;

	return(error_count);
}

/* -------------------------------------------------
 * Convert a Perl array into an array of ints
 * On errors this function returns a value greater than zero.
 * If there are errors, then the C array will be SHORTER than
 * the original Perl array.
 */
int malloc_row_perl2c_int (pTHX_ SV * input, int ** array_ptr, int * array_length_ptr) {

	AV * array;
	int i,ii;
	int array_length,original_array_length;
	int * data;
	int error_count = 0;

	array                 = (AV *) SvRV(input);
	array_length          = (int) av_len(array) + 1;
	original_array_length =  array_length;
	data                  = (int *) malloc( (size_t) original_array_length * sizeof(int) ); 

	/* Loop once for each item in the Perl array, and convert it to a C double. 
	 * Variable i  increments with each item in the Perl array. 
	 * Variable ii increments with each item in the C array. 
	 * Some Perl items may be skipped, so variable ii will sometimes not increment.
	 */
	for (i=0,ii=0; i < original_array_length; ++i,++ii) {
		double num;
		SV * mysv = *(av_fetch(array, (I32) i, (I32) 0));
		if(extract_double_from_scalar(aTHX_ mysv,&num) > 0) {	
			data[ii] = (int) num;
		} else {
			/* Skip any items which are not numeric */
    		if (warnings_enabled(aTHX))
				Perl_warn(aTHX_ 
					"Warning when parsing array: item %d is not a number, skipping\n", i);      
			data[ii] = 0;
			--ii;
			--array_length;  
			error_count++;
		}
	}
	*array_ptr        = data;
	*array_length_ptr = array_length;

	return(error_count);
}

/* -------------------------------------------------
 *
 */
SV * matrix_c_array_2perl_int(pTHX_ int matrix[][2], int nrows, int ncols) {

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
SV * matrix_c2perl_int(pTHX_ int ** matrix, int nrows, int ncols) {

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
SV * matrix_c2perl_dbl(pTHX_ double ** matrix, int nrows, int ncols) {

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
SV * row_c2perl_dbl(pTHX_ double * row, int ncols) {

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
SV * row_c2perl_int(pTHX_ int * row, int ncols) {

	int j;
	AV * row_av = newAV();
	for(j=0; j<ncols; ++j) {
		av_push(row_av, newSVnv(row[j]));
	}
	return ( newRV_noinc( (SV*) row_av ) );
}

/* -------------------------------------------------
 * Convert the 'data' and 'mask' matrices and the 'weight' array
 * from C to Perl.  Also check for errors, and ignore the
 * mask or the weight array if there are any errors. 
 * Print warnings so the user will know what happened. 
 */
int malloc_matrices(pTHX_
	SV *  weight_ref, double  ** weight, int * nweights, 
	SV *  data_ref,   double *** matrix,
	SV *  mask_ref,   int    *** mask,
	int   nrows,      int        ncols
) {

	int error_count;
	int dummy;

	if(SvTYPE(SvRV(mask_ref)) == SVt_PVAV) { 
		error_count = malloc_matrix_perl2c_int(aTHX_ mask_ref, mask, &dummy, &dummy);
		if(error_count > 0) {
			free_matrix_int(*mask, nrows);
			*mask = malloc_matrix_int(aTHX_ nrows,ncols,1);
		}
	} else {
			*mask = malloc_matrix_int(aTHX_ nrows,ncols,1);
	}

	/* We don't check data_ref because we expect the caller to check it 
	 */
	error_count = malloc_matrix_perl2c_dbl(aTHX_ data_ref, matrix, &dummy, &dummy, *mask);
	if (error_count > 0 && warnings_enabled(aTHX)) 
		Perl_warn(aTHX_ "%d errors when parsing input matrix.\n", error_count);      

	if(SvTYPE(SvRV(weight_ref)) == SVt_PVAV) { 
		error_count = malloc_row_perl2c_dbl(aTHX_ weight_ref, weight, nweights);
		if(error_count > 0 || *nweights != ncols) {
			Perl_warn(aTHX_ "Weight array has %d items, should have %d. "
				"%d errors detected.\n", *nweights, ncols, error_count);      
			free(*weight);
			*weight = malloc_row_dbl(aTHX_ ncols,1.0);
			*nweights = ncols;
		}
	} else {
			*weight = malloc_row_dbl(aTHX_ ncols,1.0);
			*nweights = ncols;
	}

	return 0;
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
	int       nrows, ncols;
	double ** matrix;  /* two-dimensional matrix of doubles */

	CODE:
	malloc_matrix_perl2c_dbl(aTHX_ input, &matrix, &nrows, &ncols, NULL);

	if(matrix != NULL) {
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
	int       nrows, ncols;
	double ** matrix;  /* two-dimensional matrix of doubles */

	CODE:
	malloc_matrix_perl2c_dbl(aTHX_ input, &matrix, &nrows, &ncols, NULL);

	if(matrix != NULL) {
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
	double * data;  /* one-dimensinal array of doubles */

	CODE:
	if(SvTYPE(SvRV(input)) != SVt_PVAV) { 
		XSRETURN_UNDEF;
	}

	malloc_row_perl2c_dbl (aTHX_ input, &data, &array_length);

	RETVAL = newSVnv( mean(array_length, data) );

	OUTPUT:
	RETVAL


SV *
_median(input)
	SV * input;

	PREINIT:
	int array_length;
	double * data;  /* one-dimensinal array of doubles */

	CODE:
	if(SvTYPE(SvRV(input)) != SVt_PVAV) { 
		XSRETURN_UNDEF;
	}
	printf("Running median\n");

	malloc_row_perl2c_dbl (aTHX_ input, &data, &array_length);

	RETVAL = newSVnv( median(array_length, data) );

	free(data);

	OUTPUT:
	RETVAL


void
_treecluster(nrows,ncols,data_ref,mask_ref,weight_ref,applyscale,transpose,dist,method)
	int      nrows;
	int      ncols;
	SV *     data_ref;
	SV *     mask_ref;
	SV *     weight_ref;
	int      applyscale;
	int      transpose;
	char *   dist;
	char *   method;

	PREINIT:
	SV   *    result_ref;
	SV   *    linkdist_ref;
	int       (*result)[2];
	double   * linkdist;
	int       nweights;

	double  * weight;
	double ** matrix;
	int    ** mask;

	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most paramters.
	 */

	/* ------------------------
	 * Malloc space for result[][2] and linkdist[]. 
	 * Don't bother to cast the pointer for 'result', because we can't 
	 * cast it to a pointer-to-array anway. 
	 */
	result   =               malloc( (size_t) 2 * (nrows-1) * sizeof(int) );
	linkdist = (double *)    malloc( (size_t)     (nrows-1) * sizeof(double) );

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, &nweights, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* Debugging statements.... */
	/* print_matrix_dbl(aTHX_ matrix,nrows,ncols);  */
	/* print_matrix_int(aTHX_ mask,nrows,ncols);  */
	/* print_row_dbl(aTHX_ weight,nweights);   */
	/* printf("nrows: %d ncols: %d dist: %c method: %c transp: %d applyscale: %d\n", */
	/* 	nrows, ncols, dist[0], method[0], transpose, applyscale); */
	/* printf("Launching library function...\n"); */

	/* ------------------------
	 * Run the library function
	 */
	treecluster( nrows, ncols, matrix, mask, weight, applyscale, 
			transpose, dist[0], method[0], result, linkdist, 0);

	/* Debugging statements.... */
	/* for(i=0; i<nrows-1; ++i) { */
	/*         printf("%2d: %4d %4d   %7.3f\n", i, result[i][0], result[i][1], linkdist[i]); */
	/* } */
	/* printf("Converting results to Perl...\n"); */
	

	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	result_ref   =  matrix_c_array_2perl_int(aTHX_ result,   nrows-1, 2); 
	linkdist_ref =            row_c2perl_dbl(aTHX_ linkdist, nrows-1   ); 

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal( result_ref   ));
	XPUSHs(sv_2mortal( linkdist_ref ));

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
_kcluster(nclusters,nrows,ncols,data_ref,mask_ref,weight_ref,transpose,npass,method,dist)
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

	PREINIT:
	SV  *    centroid_ref;
	SV  *    clusterid_ref;
	int *    clusterid;
	int      nweights;
	double   error;
	int      ifound;

	double  * weight;
	double ** matrix;
	int    ** mask;
	double ** centroid;

	PPCODE:
	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most paramters.
	 */

	/* ------------------------
	 * Malloc space for the return values from the library function
	 */
	centroid  = malloc_matrix_dbl(aTHX_ nclusters,ncols,0.0);
	clusterid = (int *) malloc( (size_t) nrows * sizeof(int*) );

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, &nweights, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* ------------------------
	 * Run the library function
	 */
	kcluster( 
		nclusters, nrows, ncols, 
		matrix, mask, weight,
		transpose, npass, method[0], dist[0], clusterid, 
		centroid, &error, &ifound
	);

	/* ------------------------
	 * Convert generated C matrices to Perl matrices
	 */
	clusterid_ref =    row_c2perl_int(aTHX_ clusterid, nrows           );
	centroid_ref  = matrix_c2perl_dbl(aTHX_ centroid,  nclusters, ncols);

	/* ------------------------
	 * Push the new Perl matrices onto the return stack
	 */
	XPUSHs(sv_2mortal( clusterid_ref   ));
	XPUSHs(sv_2mortal( centroid_ref    ));
	XPUSHs(sv_2mortal( newSViv(ifound) ));

	/* ------------------------
	 * Free what we've malloc'ed 
	 */
	free_matrix_dbl(centroid, nclusters);
	free(clusterid);
	free_matrix_int(mask,     nrows);
	free_matrix_dbl(matrix,   nrows);
	free(weight);

	/* Finished _kcluster() */



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
	int   error_count;
	int   nweights;
	int   dummy;

	int     * cluster1;
	int     * cluster2;

	double  * weight;
	double ** matrix;
	int    ** mask;

	double distance;

	CODE:
	error_count = 0;

	/* ------------------------
	 * Don't check the parameters, because we rely on the Perl
	 * caller to check most paramters.
	 */

	/* ------------------------
	 * Convert cluster index Perl arrays to C arrays
	 */
	error_count += malloc_row_perl2c_int(aTHX_ cluster1_ref, &cluster1, &dummy);
	error_count += malloc_row_perl2c_int(aTHX_ cluster2_ref, &cluster2, &dummy);

	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, &nweights, 
		data_ref,   &matrix,
		mask_ref,   &mask,  
		nrows,      ncols
	);

	/* Debugging statements.... */
	/* print_matrix_dbl(aTHX_ matrix,nrows,ncols); */
	/* print_matrix_int(aTHX_ mask,nrows,ncols); */
	/* print_row_dbl(aTHX_ weight,nweights);  */
	/* printf("c1: %d c2: %d dist: %c method: %c transp: %d \n",  */
	/* 	cluster1_len, cluster2_len, dist[0], method[0], transpose); */


	/* ------------------------
	 * Run the library function
	 */
	distance = clusterdistance( 
		nrows, ncols, 
		matrix, mask, weight,
		cluster1_len, cluster2_len, cluster1, cluster2,
		dist[0], method[0], transpose
	);
	/* printf("Distance is %7.3f\n", distance); */

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
	clusterid  =  malloc( (size_t) 2 * (nrows) * sizeof(int) );
	celldata  =  0;
	/* Don't return celldata, for now at least */


	/* ------------------------
	 * Convert data and mask matrices and the weight array
	 * from C to Perl.  Also check for errors, and ignore the
	 * mask or the weight array if there are any errors. 
	 */
	malloc_matrices( aTHX_
		weight_ref, &weight, &nweights, 
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

