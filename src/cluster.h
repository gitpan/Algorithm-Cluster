/******************************************************************************/
/* The C clustering library for cDNA microarray data.
 * Copyright (C) 2002 Michiel Jan Laurens de Hoon.
 *
 * This library was written at the Laboratory of DNA Information Analysis,
 * Human Genome Center, Institute of Medical Science, University of Tokyo,
 * 4-6-1 Shirokanedai, Minato-ku, Tokyo 108-8639, Japan.
 * Contact: mdehoon@ims.u-tokyo.ac.jp
 * 
 * This entire notice should be included in all copies of any software
 * which is or includes a copy or modification of this software and in
 * all copies of the supporting documentation for such software.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef C_CLUSTERING_LIB
#define C_CLUSTERING_LIB

#ifndef CALL 
# define CALL
#endif

#ifndef min
#define min(x, y)	((x) < (y) ? (x) : (y))
#endif
#ifndef max
#define	max(x, y)	((x) > (y) ? (x) : (y))
#endif

#ifdef WINDOWS
#  include <windows.h>
#endif


/* Chapter 2 */
double CALL clusterdistance (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int n1, int n2, int index1[], int index2[], char dist,
  char method, int transpose);

/* Chapter 3 */
void CALL initran(void);

/* Chapter 4 */
double** CALL distancematrix (int ngenes, int ndata, double** data,
  int** mask, double* weight, char dist, int transpose);

/* Chapter 5 */
void CALL randomassign (int nclusters, int ngenes, int clusterid[]);
void getclustermean (int nclusters, int nrows, int ncolumns,
  double** data, int** mask, int clusterid[], double** cdata, int** cmask,
  int transpose);
void getclustermedian (int nclusters, int nrows, int ncolumns,
  double** data, int** mask, int clusterid[], double** cdata, int** cmask,
  int transpose);
void CALL kcluster (int nclusters, int ngenes, int ndata, double** data,
  int** mask, double weight[], int transpose, int npass, char method, char dist,
  int clusterid[], double** cdata, double* error, int* ifound);

/* Chapter 6 */
void CALL treecluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, char method,
  int result[][2], double linkdist[], double** distmatrix);

/* Chapter 7 */
void CALL somcluster (int nrows, int ncolumns, double** data, int** mask,
  const double weight[], int transpose, int nxnodes, int nynodes,
  double inittau, int niter, char dist, double*** celldata,
  int clusterid[][2]);

/* Chapter 8 */
void CALL svd (double *U, double *S, double *V, int nRow, int nCol);

/* Utility routines, currently undocumented */
void CALL sort(int n, const double data[], int index[]);
double CALL mean(int n, double x[]);
double CALL median (int n, double x[]);
#endif
