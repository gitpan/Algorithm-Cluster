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

double CALL mean(int n, double x[]);
double CALL median (int n, double x[]);
void CALL sort (int n, const double data[], int index[]);
void CALL svd (double *U, double *S, double *V, int nRow, int nCol);
void CALL initran(void);
void CALL randomassign (int nclusters, int ngenes, int clusterid[]);
void CALL kcluster (int nclusters, int ngenes, int ndata, double** data,
  int** mask, double weight[], int transpose, int npass, char method, char dist,
  int clusterid[], double** cdata, int* ifound);
double** CALL distancematrix (int ngenes, int ndata, double** data,
  int** mask, double* weight, char dist, int transpose);
double CALL getscale(int nelements, double** distmatrix, char dist);
void CALL pclworker (int ngenes, int ndata, double** data, int** mask,
  double* weight, double** distmatrix, char dist, int transpose,
  int result[][2], double linkdist[]);
void CALL pclcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, int result[][2],
  double linkdist[]);
void CALL pslworker (int ngenes, double** distmatrix, int result[][2],
  double linkdist[]);
void CALL pslcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, int result[][2],
  double linkdist[]);
void CALL pmlworker (int ngenes, double** distmatrix, int result[][2],
  double linkdist[]);
void CALL pmlcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, int result[][2],
  double linkdist[]);
void CALL palworker (int ngenes, double** distmatrix, int result[][2],
  double linkdist[]);
void CALL palcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, int result[][2],
  double linkdist[]);
void CALL somworker (int ngenes, int ndata, double** data, int** mask,
  double weight[], int transpose, int nxnodes, int nynodes, double inittau,
  double*** nodesdata, int niter, char dist);
void CALL somassign (int ngenes, int ndata, double** data, int** mask,
  double weight[], int transpose, int nxnodes, int nynodes,
  double*** nodesdata, char dist, int clusterid[][2]);
void CALL somcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int transpose, int nxnodes, int nynodes, int niter,
  char dist, int clusterid[][2]);
double CALL clusterdistance (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int n1, int n2, int index1[], int index2[], char dist,
  char method, int transpose);
#endif
