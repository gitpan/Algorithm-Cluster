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

#include <time.h>
#include <stdlib.h>
#include <math.h>
#include <ranlib.h>
#include <float.h>
#include "cluster.h"
#ifdef WINDOWS
#  include <windows.h>
#endif

#define TOLERANCE 1.0e-12 /* Needed for the Singular Value Decomposition */

/* ************************************************************************ */

#ifdef WINDOWS
/* Then we make a Windows DLL */
int WINAPI
clusterdll_init (HANDLE h, DWORD reason, void* foo)
{
  return 1;
}
#endif

/* ************************************************************************ */

double CALL mean(int n, double x[])
{ double result = 0.;
  int i;
  for (i = 0; i < n; i++) result = result + x[i]; 
  result /= n;
  return result;
}

/* ************************************************************************ */

double CALL median (int n, double x[])   
/*
Find the median of X(1), ... , X(N), using as much of the quicksort
algorithm as is needed to isolate it.
N.B. On exit, the array X is partially ordered.
Based on Alan J. Miller's median.f90 routine.
*/

{ int i, j;
  int nr = n / 2;
  int nl = nr - 1;
  int even = 0;
  /* hi & lo are position limits encompassing the median. */
  int lo = 0;
  int hi = n-1;

  if (n==2*nr) even = 1;
  if (n<3)
  { if (n<1) return 0.;
    if (n == 1) return x[0];
    return 0.5*(x[0]+x[1]);
  }

  /* Find median of 1st, middle & last values. */
  do 
  { int loop;
    int mid = (lo + hi)/2;
    double result = x[mid];
    double xlo = x[lo];
    double xhi = x[hi];
    if (xhi<xlo)
    { double temp = xlo;
      xlo = xhi;
      xhi = temp;
    }
    if (result>xhi) result = xhi;
    else if (result<xlo) result = xlo;
    /* The basic quicksort algorithm to move all values <= the sort key (XMED)
     * to the left-hand end, and all higher values to the other end.
     */
    i = lo;
    j = hi;
    do
    { while (x[i]<result) i++;
      while (x[j]>result) j--;
      loop = 0;
      if (i<j)
      { double temp = x[i];
        x[i] = x[j];
        x[j] = temp;
        i++;
        j--;
        if (i<=j) loop = 1;
      }
    } while (loop); /* Decide which half the median is in. */

    if (even)
    { if (j==nl && i==nr)
        /* Special case, n even, j = n/2 & i = j + 1, so the median is
         * between the two halves of the series.   Find max. of the first
         * half & min. of the second half, then average.
         */
        { int k;
          double xmax = x[0];
          double xmin = x[n-1];
          for (k = lo; k <= j; k++) xmax = max(xmax,x[k]);
          for (k = i; k <= hi; k++) xmin = min(xmin,x[k]);
          return 0.5*(xmin + xmax);
        }
      if (j<nl) lo = i;
      if (i>nr) hi = j;
      if (i==j)
      { if (i==nl) lo = nl;
        if (j==nr) hi = nr;
      }
    }
    else
    { if (j<nr) lo = i;
      if (i>nr) hi = j;
      /* Test whether median has been isolated. */
      if (i==j && i==nr) return result;
    }
  }
  while (lo<hi-1);

  if (even) return (0.5*(x[nl]+x[nr]));
  if (x[lo]>x[hi])
  { double temp = x[lo];
    x[lo] = x[hi];
    x[hi] = temp;
  }
  return x[nr];
}

/* *********************************************************************  */

static
int compare(const void* a, const void* b)
/* Helper function for sort. Previously, this was a nested function under sort,
 * which is not allowed under ANSI C.
 */
{ const double term1 = *(*(double**)a);
  const double term2 = *(*(double**)b);
  if (term1 < term2) return -1;
  if (term1 > term2) return +1;
  return 0;
}

void CALL sort(int n, const double data[], int index[])
/* Sets up an index table given the data, such that data[index[]] is in
 * increasing order. Sorting is done on the pointers, from which the indeces
 * are recalculated. The array data is unchanged.
 */
{ int i;
  const double** p = (const double**)malloc((size_t)n*sizeof(double*));
  const double* start = data;
  for (i = 0; i < n; i++) p[i] = &(data[i]);
  qsort(p, n, sizeof(double*), compare);
  for (i = 0; i < n; i++) index[i] = (int)(p[i]-start);
  free(p);
}

static
void getrank (int n, double data[], double rank[])
/* Calculates the ranks of the elements in the array data. Two elements with the
 * same value get the same rank, equal to the average of the ranks had the
 * elements different values.
 */
{ int i;
  int* index = (int*)malloc((size_t)n*sizeof(int));
  /* Call sort to get an index table */
  sort (n, data, index);
  /* Build a rank table */
  for (i = 0; i < n; i++) rank[index[i]] = i;
  /* Fix for equal ranks */
  i = 0;
  while (i < n)
  { int m;
    double value = data[index[i]];
    int j = i + 1;
    while (j < n && data[index[j]] == value) j++;
    m = j - i; /* number of equal ranks found */
    value = rank[index[i]] + (m-1)/2.;
    for (j = i; j < i + m; j++) rank[index[j]] = value;
    i += m;
  }
  free (index);
  return;
}

/* ********************************************************************* */

void CALL svd (double *U, double *S, double *V, int nRow, int nCol)
/*
Singular Value Decomposition. This routine was copied from Nodelib, which is
covered by the GPL license.
*/
{
  int i, j, k, EstColRank, RotCount, SweepCount, slimit;
  double eps, e2, tol, vt, p, x0, y0, q, r, c0, s0, d1, d2;

  eps = TOLERANCE;
  slimit = nCol / 4;
  if (slimit < 6.0)
    slimit = 6;
  SweepCount = 0;
  e2 = 10.0 * nRow * eps * eps;
  tol = eps * .1;
  EstColRank = nCol;
  if(V)
    for (i = 0; i < nCol; i++)
      for (j = 0; j < nCol; j++) {
        V[nCol * i + j] = 0.0;
        V[nCol * i + i] = 1.0;
      }
  RotCount = EstColRank * (EstColRank - 1) / 2;
  while (RotCount != 0 && SweepCount <= slimit) {
    RotCount = EstColRank * (EstColRank - 1) / 2;
    SweepCount++;
    for (j = 0; j < EstColRank - 1; j++) {
      for (k = j + 1; k < EstColRank; k++) {
        p = q = r = 0.0;
        for (i = 0; i < nRow; i++) {
          x0 = U[nCol * i + j];
          y0 = U[nCol * i + k];
          p += x0 * y0;
          q += x0 * x0;
          r += y0 * y0;
        }
        S[j] = q;
        S[k] = r;
        if (q >= r) {
          if (q <= e2 * S[0] || fabs(p) <= tol * q)
            RotCount--;
          else {
            p /= q;
            r = 1 - r / q;
            vt = sqrt(4 * p * p + r * r);
            c0 = sqrt(fabs(.5 * (1 + r / vt)));
            s0 = p / (vt * c0);
            for (i = 0; i < nRow; i++) {
              d1 = U[nCol * i + j];
              d2 = U[nCol * i + k];
              U[nCol * i + j] = d1 * c0 + d2 * s0;
              U[nCol * i + k] = -d1 * s0 + d2 * c0;
            }
            if(V)
              for (i = 0; i < nCol; i++) {
                d1 = V[nCol * i + j];
                d2 = V[nCol * i + k];
                V[nCol * i + j] = d1 * c0 + d2 * s0;
                V[nCol * i + k] = -d1 * s0 + d2 * c0;
              }
          }
        }
        else {
          p /= r;
          q = q / r - 1;
          vt = sqrt(4 * p * p + q * q);
          s0 = sqrt(fabs(.5 * (1 - q / vt)));
          if (p < 0)
            s0 = -s0;
          c0 = p / (vt * s0);
          for (i = 0; i < nRow; i++) {
            d1 = U[nCol * i + j];
            d2 = U[nCol * i + k];
            U[nCol * i + j] = d1 * c0 + d2 * s0;
            U[nCol * i + k] = -d1 * s0 + d2 * c0;
          }
          if(V)
            for (i = 0; i < nCol; i++) {
              d1 = V[nCol * i + j];
              d2 = V[nCol * i + k];
              V[nCol * i + j] = d1 * c0 + d2 * s0;
              V[nCol * i + k] = -d1 * s0 + d2 * c0;
            }
        }
      }
    }
    while (EstColRank >= 3 && S[(EstColRank - 1)] <= S[0] * tol + tol * tol)
      EstColRank--;
  }
  for(i = 0; i < nCol; i++)
    S[i] = sqrt(S[i]);
  for(i = 0; i < nCol; i++)
    for(j = 0; j < nRow; j++)
      U[nCol * j + i] = U[nCol * j + i] / S[i];
}

/* ********************************************************************* */

static
double euclid (int n, double** data1, double** data2, int** mask1, int** mask2,
  const double weight[], int index1, int index2, int transpose)
 
/*
-- euclid routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
January 3, 2003

Purpose
=======

The euclid routine calculates the weighted Euclidean distance between two
rows or columns in a matrix.

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.

============================================================================
*/
{ double result = 0.;
  double tweight = 0;
  int i;
  if (transpose==0) /* Calculate the distance between two rows */
  { for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { double term = data1[index1][i] - data2[index2][i];
        result = result + weight[i]*term*term;
        tweight += weight[i];
      }
    }
  }
  else
  { for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { double term = data1[i][index1] - data2[i][index2];
        result = result + weight[i]*term*term;
        tweight += weight[i];
      }
    }
  }
  if (!tweight) return 0; /* usually due to empty clusters */
  result /= tweight;
  result *= n;
  return result;
}

/* ********************************************************************* */

static
double harmonic(int n, double** data1, double** data2, int** mask1, int** mask2,
  const double weight[], int index1, int index2, int transpose)
 
/*
-- harmonic routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
August 7, 2002

Purpose
=======

The harmonic routine calculates the weighted Euclidean distance between two
rows or columns in a matrix, adding terms for the different dimensions
harmonically, i.e. summing the inverse and taking the inverse of the total.

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.

============================================================================
*/
{ double result = 0.;
  double tweight = 0;
  int i;
  if (transpose==0) /* Calculate the distance between two rows */
  { for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { const double term = data1[index1][i] - data2[index2][i];
        if (term==0) return 0;
        result = result + weight[i]/(term*term);
        tweight += weight[i];
      }
    }
  }
  else
  { for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { const double term = data1[i][index1] - data2[i][index2];
        if (term==0) return 0;
        result = result + weight[i]/(term*term);
        tweight += weight[i];
      }
    }
  }
  if (!tweight) return 0; /* usually due to empty clusters */
  result /= tweight;
  result *= n;
  result = 1. / result;
  return result;
}

/* ********************************************************************* */

static
double correlation (int n, double** data1, double** data2, int** mask1,
  int** mask2, const double weight[], int index1, int index2, int transpose)
/*
-- correlation routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The correlation routine calculates the weighted Pearson distance between two
rows or columns in a matrix. We define the Pearson distance as one minus the
Pearson correlation.
This definition yields a semi-metric: d(a,b) >= 0, and d(a,b) = 0 iff a = b.
but the triangular inequality d(a,b) + d(b,c) >= d(a,c) does not hold
(e.g., choose b = a + c).

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ double result = 0.;
  double sum1 = 0.;
  double sum2 = 0.;
  double denom1 = 0.;
  double denom2 = 0.;
  double tweight = 0.;
  if (transpose==0) /* Calculate the distance between two rows */
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { double term1 = data1[index1][i];
        double term2 = data2[index2][i];
        double w = weight[i];
        sum1 += w*term1;
        sum2 += w*term2;
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        tweight += w;
      }
    }
  }
  else
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { double term1 = data1[i][index1];
        double term2 = data2[i][index2];
        double w = weight[i];
        sum1 += w*term1;
        sum2 += w*term2;
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        tweight += w;
      }
    }
  }
  if (!tweight) return 0; /* usually due to empty clusters */
  result -= sum1 * sum2 / tweight;
  denom1 -= sum1 * sum1 / tweight;
  denom2 -= sum2 * sum2 / tweight;
  if (denom1 <= 0) return 1; /* include '<' to deal with roundoff errors */
  if (denom2 <= 0) return 1; /* include '<' to deal with roundoff errors */
  result = result / sqrt(denom1*denom2);
  result = 1. - result;
  return result;
}

/* ********************************************************************* */

static
double acorrelation (int n, double** data1, double** data2, int** mask1,
  int** mask2, const double weight[], int index1, int index2, int transpose)
/*
-- acorrelation routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The acorrelation routine calculates the weighted Pearson distance between two
rows or columns, using the absolute value of the correlation.
This definition yields a semi-metric: d(a,b) >= 0, and d(a,b) = 0 iff a = b.
but the triangular inequality d(a,b) + d(b,c) >= d(a,c) does not hold
(e.g., choose b = a + c).

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ double result = 0.;
  double sum1 = 0.;
  double sum2 = 0.;
  double denom1 = 0.;
  double denom2 = 0.;
  double tweight = 0.;
  if (transpose==0) /* Calculate the distance between two rows */
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { double term1 = data1[index1][i];
        double term2 = data2[index2][i];
        double w = weight[i];
        sum1 += w*term1;
        sum2 += w*term2;
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        tweight += w;
      }
    }
  }
  else
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { double term1 = data1[i][index1];
        double term2 = data2[i][index2];
        double w = weight[i];
        sum1 += w*term1;
        sum2 += w*term2;
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        tweight += w;
      }
    }
  }
  if (!tweight) return 0; /* usually due to empty clusters */
  result -= sum1 * sum2 / tweight;
  denom1 -= sum1 * sum1 / tweight;
  denom2 -= sum2 * sum2 / tweight;
  if (denom1 <= 0) return 1; /* include '<' to deal with roundoff errors */
  if (denom2 <= 0) return 1; /* include '<' to deal with roundoff errors */
  result = fabs(result) / sqrt(denom1*denom2);
  result = 1. - result;
  return result;
}

/* ********************************************************************* */

static
double ucorrelation (int n, double** data1, double** data2, int** mask1,
  int** mask2, const double weight[], int index1, int index2, int transpose)
/*
-- ucorrelation routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The ucorrelation routine calculates the weighted Pearson distance between two
rows or columns, using the uncentered version of the Pearson correlation. In the
uncentered Pearson correlation, a zero mean is used for both vectors even if
the actual mean is nonzero.
This definition yields a semi-metric: d(a,b) >= 0, and d(a,b) = 0 iff a = b.
but the triangular inequality d(a,b) + d(b,c) >= d(a,c) does not hold
(e.g., choose b = a + c).

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ double result = 0.;
  double denom1 = 0.;
  double denom2 = 0.;
  int flag = 0;
  /* flag will remain zero if no nonzero combinations of mask1 and mask2 are
   * found.
   */
  if (transpose==0) /* Calculate the distance between two rows */
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { double term1 = data1[index1][i];
        double term2 = data2[index2][i];
        double w = weight[i];
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        flag = 1;
      }
    }
  }
  else
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { double term1 = data1[i][index1];
        double term2 = data2[i][index2];
        double w = weight[i];
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        flag = 1;
      }
    }
  }
  if (!flag) return 0.;
  if (denom1==0.) return 1.;
  if (denom2==0.) return 1.;
  result = result / sqrt(denom1*denom2);
  result = 1. - result;
  return result;
}

/* ********************************************************************* */

static
double uacorrelation (int n, double** data1, double** data2, int** mask1,
  int** mask2, const double weight[], int index1, int index2, int transpose)
/*
-- uacorrelation routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The uacorrelation routine calculates the weighted Pearson distance between two
rows or columns, using the absolute value of the uncentered version of the
Pearson correlation. In the uncentered Pearson correlation, a zero mean is used
for both vectors even if the actual mean is nonzero.
This definition yields a semi-metric: d(a,b) >= 0, and d(a,b) = 0 iff a = b.
but the triangular inequality d(a,b) + d(b,c) >= d(a,c) does not hold
(e.g., choose b = a + c).

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ double result = 0.;
  double denom1 = 0.;
  double denom2 = 0.;
  int flag = 0;
  /* flag will remain zero if no nonzero combinations of mask1 and mask2 are
   * found.
   */
  if (transpose==0) /* Calculate the distance between two rows */
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { double term1 = data1[index1][i];
        double term2 = data2[index2][i];
        double w = weight[i];
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        flag = 1;
      }
    }
  }
  else
  { int i;
    for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { double term1 = data1[i][index1];
        double term2 = data2[i][index2];
        double w = weight[i];
        result += w*term1*term2;
        denom1 += w*term1*term1;
        denom2 += w*term2*term2;
        flag = 1;
      }
    }
  }
  if (!flag) return 0.;
  if (denom1==0.) return 1.;
  if (denom2==0.) return 1.;
  result = fabs(result) / sqrt(denom1*denom2);
  result = 1. - result;
  return result;
}

/* *********************************************************************  */

static
double spearman (int n, double** data1, double** data2, int** mask1,
  int** mask2, const double weight[], int index1, int index2, int transpose)
/*
-- spearman routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The spearman routine calculates the Spearman distance between two rows or
columns. The Spearman distance is defined as one minus the Spearman rank
correlation.

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
These weights are ignored, but included for consistency with other distance
measures.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ double* rank1;
  double* rank2;
  double result = 0.;
  double denom1 = 0.;
  double denom2 = 0.;
  double avgrank;
  double* tdata1 = (double*)malloc((size_t)n*sizeof(double));
  double* tdata2 = (double*)malloc((size_t)n*sizeof(double));
  int i;
  int m = 0;
  if (transpose==0)
  { for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { tdata1[m] = data1[index1][i];
        tdata2[m] = data2[index2][i];
        m++;
      }
    }
  }
  else
  { for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { tdata1[m] = data1[i][index1];
        tdata2[m] = data2[i][index2];
        m++;
      }
    }
  }
  if (m==0) return 0;
  rank1 = (double*)malloc((size_t)m*sizeof(double));
  rank2 = (double*)malloc((size_t)m*sizeof(double));
  getrank(m, tdata1, rank1);
  free(tdata1);
  getrank(m, tdata2, rank2);
  free(tdata2);
  avgrank = 0.5*(m-1); /* Average rank */
  for (i = 0; i < m; i++)
  { double value1 = rank1[i];
    double value2 = rank2[i];
    result += value1 * value2;
    denom1 += value1 * value1;
    denom2 += value2 * value2;
  }
  /* Note: denom1 and denom2 cannot be calculated directly from the number
   * of elements. If two elements have the same rank, the squared sum of
   * their ranks will change.
   */
  free(rank1);
  free(rank2);
  result /= m;
  denom1 /= m;
  denom2 /= m;
  result -= avgrank * avgrank;
  denom1 -= avgrank * avgrank;
  denom2 -= avgrank * avgrank;
  result = result / sqrt(denom1*denom2);
  result = 1. - result;
  return result;
}

/* *********************************************************************  */

static
double kendall (int n, double** data1, double** data2, int** mask1, int** mask2,
  const double weight[], int index1, int index2, int transpose)
/*
-- kendall routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
June 2, 2002

Purpose
=======

The kendall routine calculates the Kendall distance between two
rows or columns. The Kendall distance is defined as one minus Kendall's tau. 

Arguments
=========

n      (input) int
The number of elements in a row or column. If transpose==0, then n is the number
of columns; otherwise, n is the number of rows.

data1  (input) double array
The data array containing the first vector.

data2  (input) double array
The data array containing the second vector.

mask1  (input) int array
This array which elements in data1 are missing. If mask1[i][j]==0, then 
data1[i][j] is missing.

mask2  (input) int array
This array which elements in data2 are missing. If mask2[i][j]==0, then 
data2[i][j] is missing.

weight (input) double array, dimension( n )
These weights are ignored, but included for consistency with other distance
measures.

index1     (input) int
Index of the first row or column.

index2     (input) int
Index of the second row or column.

transpose (input) int
If transpose==0, the distance between two rows in the matrix is calculated.
Otherwise, the distance between two columns in the matrix is calculated.
============================================================================
*/
{ int con = 0;
  int dis = 0;
  int exx = 0;
  int exy = 0;
  int flag = 0;
  /* flag will remain zero if no nonzero combinations of mask1 and mask2 are
   * found.
   */
  double denomx;
  double denomy;
  double tau;
  int i, j;
  if (transpose==0)
  { for (i = 0; i < n; i++)
    { if (mask1[index1][i] && mask2[index2][i])
      { for (j = 0; j < i; j++)
        { if (mask1[index1][j] && mask2[index2][j])
          { double x1 = data1[index1][i];
            double x2 = data1[index1][j];
            double y1 = data2[index2][i];
            double y2 = data2[index2][j];
            if (x1 < x2 && y1 < y2) con++;
            if (x1 > x2 && y1 > y2) con++;
            if (x1 < x2 && y1 > y2) dis++;
            if (x1 > x2 && y1 < y2) dis++;
            if (x1 == x2 && y1 != y2) exx++;
            if (x1 != x2 && y1 == y2) exy++;
            flag = 1;
          }
        }
      }
    }
  }
  else
  { for (i = 0; i < n; i++)
    { if (mask1[i][index1] && mask2[i][index2])
      { for (j = 0; j < i; j++)
        { if (mask1[j][index1] && mask2[j][index2])
          { double x1 = data1[i][index1];
            double x2 = data1[j][index1];
            double y1 = data2[i][index2];
            double y2 = data2[j][index2];
            if (x1 < x2 && y1 < y2) con++;
            if (x1 > x2 && y1 > y2) con++;
            if (x1 < x2 && y1 > y2) dis++;
            if (x1 > x2 && y1 < y2) dis++;
            if (x1 == x2 && y1 != y2) exx++;
            if (x1 != x2 && y1 == y2) exy++;
            flag = 1;
          }
        }
      }
    }
  }
  if (!flag) return 0.;
  denomx = con + dis + exx;
  denomy = con + dis + exy;
  if (denomx==0) return 1;
  if (denomy==0) return 1;
  tau = (con-dis)/sqrt(denomx*denomy);
  return 1.-tau;
}

/* *********************************************************************  */

static
void setmetric (char dist,
  double (**metric)
    (int,double**,double**,int**,int**, const double[],int,int,int) )
{ switch(dist)
  { case ('e'): *metric = &euclid; break;
    case ('h'): *metric = &harmonic; break;
    case ('c'): *metric = &correlation; break;
    case ('a'): *metric = &acorrelation; break;
    case ('u'): *metric = &ucorrelation; break;
    case ('x'): *metric = &uacorrelation; break;
    case ('s'): *metric = &spearman; break;
    case ('k'): *metric = &kendall; break;
    default: *metric = &euclid; break;
  }
  return;
}

/* *********************************************************************  */

void CALL initran(void)
/*
-- initran routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
March 28, 2002

Purpose
=======

The routine initran initializes the random number generator using the current
time. The current epoch time in seconds is used as a seed for the standard C
random number generator. The first two random number generated by the standard
C random number generator are then used to initialize the ranlib random number
generator.

External Subroutines:
time.h:     time
ranlib.h:   setall
============================================================================
*/

{ int initseed = time(0);
  int iseed1, iseed2;
  srand(initseed);
  iseed1 = rand();
  iseed2 = rand();
  setall (iseed1, iseed2);
  return;
}

/* ************************************************************************ */

void CALL randomassign (int nclusters, int nelements, int clusterid[])
/*
-- randomassign routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
March 13, 2002

Purpose
=======

The randomassign routine performs an initial random clustering, needed for
k-means or k-median clustering. Elements (genes or microarrays) are randomly
assigned to clusters. First, nclust elements are randomly chosen to be assigned
to the clusters 0..nclust-1 in order to guarantee that none of the clusters
are empty. The remaining elements are then randomly assigned to a cluster.

Arguments
=========

nclust  (input) int
The number of clusters.

nelements  (input) int
The number of elements to be clustered (i.e., the number of genes or microarrays
to be clustered).

clusterid  (output) int array, dimension( nelements )
The cluster number to which an element was assigned.

External Functions:
ranlib: int genprm
============================================================================
*/

{ int i; 
  long* map = (long*)malloc((size_t)nelements*sizeof(long));
  /* Initialize mapping */
  for (i = 0; i < nelements; i++) map[i] = i;
  /* Create a random permutation of this mapping */
  genprm (map, nelements);

  /* Assign each of the first nclusters elements to a different cluster
   * to avoid empty clusters */
  for (i = 0; i < nclusters; i++) clusterid[map[i]] = i;

  /* Assign other elements randomly to a cluster */
  for (i = nclusters; i < nelements; i++)
    clusterid[map[i]] = ignuin (0,nclusters-1);
  free(map);
  return;
}

/* ********************************************************************* */

void getclustermean(int nclusters, int nrows, int ncolumns,
  double** data, int** mask, int clusterid[], double** cdata, int** cmask,
  int transpose)
/*
-- getclustermean routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
March 13, 2002

Purpose
=======

The getclustermean routine calculates the cluster centroids, given to which
cluster each element belongs. The centroid is defined as the mean over all
elements for each dimension.

Arguments
=========

nclusters  (input) int
The number of clusters.

nrows     (input) int
The number of rows in the gene expression data matrix, equal to the number of
genes.

ncolumns  (input) int
The number of columns in the gene expression data matrix, equal to the number of
microarrays.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the gene expression data.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

clusterid  (output) int array, dimension( nrows or ncolumns )
The cluster number to which each element belongs. If transpose==0, then the
dimension of clusterid is equal to nrows (the number of genes). Otherwise, it
is equal to ncolumns (the number of microarrays).

cdata      (output) double array, dimension( nclusters,ncolumns ) (transpose==0)
                               or dimension( nrows, nclusters) (transpose==1)
On exit of getclustermean, this array contains the cluster centroids.

cmask      (output) int array, dimension( nclusters,ncolumns ) (transpose==0)
                            or dimension( nrows, nclusters) (transpose==1)
This array shows which data values of are missing for each centroid. If
cmask[i][j] == 0, then cdata[i][j] is missing. A data value is missing for a
centroid if the corresponding data values of the cluster members are all
missing.

transpose  (input) int
If transpose==0, clusters of rows (genes) are specified. Otherwise, clusters of
columns (microarrays) are specified.

========================================================================
*/
{ int i, j, k;
  if (transpose==0)
  { int** count = (int**)malloc((size_t)nclusters*sizeof(int*));
    for (i = 0; i < nclusters; i++)
    { count[i] = (int*)malloc((size_t)ncolumns*sizeof(int));
      for (j = 0; j < ncolumns; j++)
      { count[i][j] = 0;
        cdata[i][j] = 0.;
      }
    }
    for (k = 0; k < nrows; k++)
    { i = clusterid[k];
      for (j = 0; j < ncolumns; j++)
        if (mask[k][j] != 0)
        { cdata[i][j] = cdata[i][j] + data[k][j];
          count[i][j] = count[i][j] + 1;
        }
    }
    for (i = 0; i < nclusters; i++)
    { for (j = 0; j < ncolumns; j++)
      { if (count[i][j]>0)
        { cdata[i][j] = cdata[i][j] / count[i][j];
          cmask[i][j] = 1;
        }
        else
          cmask[i][j] = 0;
      }
      free (count[i]);
    }
    free (count);
  }
  else
  { int** count = (int**)malloc((size_t)nrows*sizeof(int*));
    for (i = 0; i < nrows; i++)
    { count[i] = (int*)malloc((size_t)nclusters*sizeof(int));
      for (j = 0; j < nclusters; j++)
      { count[i][j] = 0;
        cdata[i][j] = 0.;
      }
    }
    for (k = 0; k < ncolumns; k++)
    { i = clusterid[k];
      for (j = 0; j < nrows; j++)
      { if (mask[j][k] != 0)
        { cdata[j][i] = cdata[j][i] + data[j][k];
          count[j][i] = count[j][i] + 1;
        }
      }
    }
    for (i = 0; i < nrows; i++)
    { for (j = 0; j < nclusters; j++)
      { if (count[i][j]>0)
        { cdata[i][j] = cdata[i][j] / count[i][j];
          cmask[i][j] = 1;
        }
        else
          cmask[i][j] = 0;
      }
      free (count[i]);
    }
    free (count);
  }
  return;
}

/* ********************************************************************* */

void getclustermedian(int nclusters, int nrows, int ncolumns,
  double** data, int** mask, int clusterid[], double** cdata, int** cmask,
  int transpose)
/*
-- getclustermedian routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
March 13, 2002

Purpose
=======

The getclustermedian routine calculates the cluster centroids, given to which
cluster each element belongs. The centroid is defined as the median over all
elements for each dimension.

Arguments
=========

nclusters  (input) int
The number of clusters.

nrows     (input) int
The number of rows in the gene expression data matrix, equal to the number of
genes.

ncolumns  (input) int
The number of columns in the gene expression data matrix, equal to the number of
microarrays.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the gene expression data.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

clusterid  (output) int array, dimension( nrows or ncolumns )
The cluster number to which each element belongs. If transpose==0, then the
dimension of clusterid is equal to nrows (the number of genes). Otherwise, it
is equal to ncolumns (the number of microarrays).

cdata      (output) double array, dimension( nclusters,ncolumns ) (transpose==0)
                               or dimension( nrows, nclusters) (transpose==1)
On exit of getclustermedian, this array contains the cluster centroids.

cmask      (output) int array, dimension( nclusters,ncolumns ) (transpose==0)
                            or dimension( nrows, nclusters) (transpose==1)
This array shows which data values of are missing for each centroid. If
cmask[i][j] == 0, then cdata[i][j] is missing. A data value is missing for a
centroid if the corresponding data values of the cluster members are all
missing.

transpose  (input) int
If transpose==0, clusters of rows (genes) are specified. Otherwise, clusters of
columns (microarrays) are specified.

========================================================================
*/
{ int i, j, k;
  if (transpose==0)
  { double* temp = (double*)malloc((size_t)nrows*sizeof(double));
    for (i = 0; i < nclusters; i++)
    { for (j = 0; j < ncolumns; j++)
      { int count = 0;
        for (k = 0; k < nrows; k++)
          if (i==clusterid[k] && mask[k][j])
          { temp[count] = data[k][j];
            count++;
          }
        if (count>0)
        { cdata[i][j] = median (count,temp);
          cmask[i][j] = 1;
        }
        else
        { cdata[i][j] = 0.;
          cmask[i][j] = 0;
        }
      }
    }
    free (temp);
  }
  else
  { double* temp = (double*)malloc((size_t)ncolumns*sizeof(double));
    for (i = 0; i < nclusters; i++)
    { for (j = 0; j < nrows; j++)
      { int count = 0;
        for (k = 0; k < ncolumns; k++)
          if (i==clusterid[k] && mask[j][k])
          { temp[count] = data[j][k];
            count++;
          }
        if (count>0)
        { cdata[j][i] = median (count,temp);
          cmask[j][i] = 1;
        }
        else
        { cdata[j][i] = 0.;
          cmask[j][i] = 0;
        }
      }
    }
    free (temp);
  }
  return;
}

/* ********************************************************************* */

static
void emalg (int nclusters, int nrows, int ncolumns,
  double** data, int** mask, double weight[], int transpose,
  void getclustercenter
    (int,int,int,double**,int**,int[],double**,int**,int),
  double metric (int,double**,double**,int**,int**,const double[],int,int,int),
  int clusterid[], double** cdata, int** cmask)

{ const int nobjects = (transpose==0) ? nrows : ncolumns;
  const int ndata = (transpose==0) ? ncolumns : nrows;

  int* cn = (int*)malloc((size_t)nclusters*sizeof(int));
  /* This will contain the number of elements in each cluster. This is needed
   * to check for empty clusters.
   */

  int* savedids = (int*)malloc((size_t)nobjects*sizeof(int));
  /* needed to check for periodic behavior */
  int same;

  int changed;
  int iteration = 0;
  int period = 10;
  long* order = (long*)malloc((size_t)nobjects*sizeof(long));
  int jj;
  for (jj = 0; jj < nobjects; jj++) order[jj] = jj;

  randomassign (nclusters, nobjects, clusterid);

  for (jj = 0; jj < nclusters; jj++) cn[jj] = 0;
  for (jj = 0; jj < nobjects; jj++)
  { int ii = clusterid[jj];
    cn[ii]++;
  }

  /* Start the loop */
  do
  { int ii;
    if (iteration % period == 0)
    { /* save the current clustering solution */
      for (ii = 0; ii < nobjects; ii++) savedids[ii] = clusterid[ii];
      period = period * 2;
    }
    iteration = iteration + 1;

    /* Find the center */
    getclustercenter (nclusters, nrows, ncolumns, data, mask,
                      clusterid, cdata, cmask, transpose);

    /* Create a random order */
    genprm (order, nobjects);

    changed = 0;

    for (ii = 0; ii < nobjects; ii++)
    /* Calculate the distances */
    { int i = order[ii];
      int jnow = clusterid[i];
      if (cn[jnow]>1)
      { /* No reassignment if that would lead to an empty cluster */
        /* Treat the present cluster as a special case */
        double distance =
          metric(ndata,data,cdata,mask,cmask,weight,i,jnow,transpose);
        int j;
        for (j = 0; j < jnow; j++)
        { double tdistance =
            metric(ndata,data,cdata,mask,cmask,weight,i,j,transpose);
          if (tdistance < distance)
          { distance = tdistance;
            cn[clusterid[i]]--;
            clusterid[i] = j;
            cn[j]++;
            changed = 1;
          }
        }
        for (j = jnow+1; j < nclusters; j++)
        { double tdistance =
            metric(ndata,data,cdata,mask,cmask,weight,i,j,transpose);
          if (tdistance < distance)
          { distance = tdistance;
            cn[clusterid[i]]--;
            clusterid[i] = j;
            cn[j]++;
            changed = 1;
          }
        }
      }
    }
    /* compare to the saved clustering solution */
    same = 1;
    for (ii = 0; ii < nobjects; ii++)
    { if (savedids[ii] != clusterid[ii])
      { same = 0;
        break;   /* No point in checking the other ids */
      }
    }
  } while (changed && !same);
  free (savedids);
  free (order);
  free (cn);
  return;
}

/* *********************************************************************** */

void CALL kcluster (int nclusters, int nrows, int ncolumns,
  double** data, int** mask, double weight[], int transpose,
  int npass, char method, char dist,
  int clusterid[], double** cdata, double* error, int* ifound) 
/*
-- kcluster routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
April 12, 2003

Purpose
=======

The kcluster routine performs k-means or k-median clustering on a given set of
elements, using the specified distance measure. The number of clusters is given
by the user. Multiple passes are being made to find the optimal clustering
solution, each time starting from a different initial clustering.


Arguments
=========

nclusters  (input) int
The number of clusters to be found.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the data of the elements to be clustered (i.e., the gene
expression data).

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

nrows     (input) int
The number of rows in the data matrix, equal to the number of genes.

ncolumns  (input) int
The number of columns in the data matrix, equal to the number of microarrays.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

transpose  (input) int
If transpose==0, the rows of the matrix are clustered. Otherwise, columns
of the matrix are clustered.

npass      (input) int
The number of times clustering is performed. Clustering is
performed npass times, each time starting from a different
(random) initial assignment of genes to clusters. The clustering
solution with the lowest inside-cluster sum of distances is chosen.

method     (input) char
Defines whether the arithmic mean (method=='a') or the median
(method=='m') is used to calculate the cluster center.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

clusterid  (output) int array, dimension( nrows or ncolumns )
The cluster number to which a gene or microarray was assigned.

cdata      (output) double array, dimension( nclusters,ncolumns ) (transpose==0)
                               or dimension( nrows, nclusters) (transpose==1)
This array contains the center of each cluster, as defined
as the average of the elements for each cluster (if
method=='a') or as the median (if method=='m').

error      (output) double
The sum of distances to the cluster center of each item in the optimal k-means
clustering solution that was found.

ifound     (output) int
The number of times the optimal clustering solution was
found. The value of ifound is at least 1; its maximum value is npass.

========================================================================
*/
{ const int nobjects = (transpose==0) ? nrows : ncolumns;
  const int ndata = (transpose==0) ? ncolumns : nrows;
  void (*getclustercenter)
    (int,int,int,double**,int**,int[],double**,int**,int);
  double (*metric)
    (int,double**,double**,int**,int**,const double[],int,int,int);
  int i;
  int** cmask;
  int** tcmask;
  double** tcdata;
  int ipass;

  if (nobjects < nclusters)
  { *ifound = 0;
    return;
  }
  /* More clusters asked for than genes available */

  /* First initialize the random number generator */
  initran();

  /* Set the function to find the centroid as indicated by method */
  if (method == 'm') getclustercenter = &getclustermedian;
  else getclustercenter = &getclustermean;

  /* Set the metric function as indicated by dist */
  setmetric (dist, &metric);

  /* Set the result of the first pass as the initial best clustering solution */
  *ifound = 1;

  if (transpose==0)
  { cmask = (int**)malloc((size_t)nclusters*sizeof(int*));
    for (i = 0; i < nclusters; i++)
      cmask[i] = (int*)malloc((size_t)ndata*sizeof(int));
  }
  else
  { cmask = (int**)malloc((size_t)ndata*sizeof(int*));
    for (i = 0; i < ndata; i++)
      cmask[i] = (int*)malloc((size_t)nclusters*sizeof(int));
  }

  *error = 0.;
  emalg(nclusters, nrows, ncolumns, data, mask, weight, transpose,
    getclustercenter, metric, clusterid, cdata, cmask);

  for (i = 0; i < nobjects; i++)
  { int j = clusterid[i];
    *error += metric(ndata, data, cdata, mask, cmask, weight, i, j, transpose);
  }
  if (transpose==0)
    for (i = 0; i < nclusters; i++) free(cmask[i]);
  else 
    for (i = 0; i < ndata; i++) free(cmask[i]);
  free(cmask);

  /* Create temporary space for cluster centroid information */
  if (transpose==0)
  { tcmask = (int**)malloc((size_t)nclusters*sizeof(int*));
    for (i = 0; i < nclusters; i++)
      tcmask[i] = (int*)malloc((size_t)ndata*sizeof(int));
    tcdata = (double**)malloc((size_t)nclusters*sizeof(double*));
    for (i = 0; i < nclusters; i++)
      tcdata[i] = (double*)malloc((size_t)ndata*sizeof(double));
  }
  else
  { tcmask = (int**)malloc((size_t)ndata*sizeof(int*));
    for (i = 0; i < ndata; i++)
      tcmask[i] = (int*)malloc((size_t)nclusters*sizeof(int));
    tcdata = (double**)malloc((size_t)ndata*sizeof(double*));
    for (i = 0; i < ndata; i++)
      tcdata[i] = (double*)malloc((size_t)nclusters*sizeof(double));
  }

  for (ipass = 1; ipass < npass; ipass++)
  { int* tclusterid = (int*)malloc((size_t)nobjects*sizeof(int));
    double tssin = 0.;
    int* mapping = (int*)malloc((size_t)nclusters*sizeof(int));
    int same = 1;

    emalg(nclusters, nrows, ncolumns, data, mask, weight, transpose,
      getclustercenter, metric, tclusterid, tcdata, tcmask);

    for (i = 0; i < nclusters; i++) mapping[i] = -1;
    for (i = 0; i < nobjects; i++)
    { int j = tclusterid[i];
      if (mapping[j] == -1) mapping[j] = clusterid[i];
      else if (mapping[j] != clusterid[i]) same = 0;
      tssin +=
        metric(ndata, data, tcdata, mask, tcmask, weight, i, j, transpose);
    }
    free(mapping);

    if (same) (*ifound)++;
    else if (tssin < *error)
    { int j;
      *ifound = 1;
      *error = tssin;
      for (i = 0; i < nobjects; i++) clusterid[i] = tclusterid[i];
      if (transpose==0)
      { for (i = 0; i < nclusters; i++)
          for (j = 0; j < ndata; j++)
            cdata[i][j] = tcdata[i][j];
      }
      else
      { for (i = 0; i < ndata; i++)
        { for (j = 0; j < nclusters; j++)
            cdata[i][j] = tcdata[i][j];
        }
      }
    }
    free(tclusterid);
  }

  /* Deallocate temporary space used for cluster centroid information */
  if (transpose==0)
  { for (i = 0; i < nclusters; i++)
    { free(tcmask[i]);
      free(tcdata[i]);
    }
  }
  else
  { for (i = 0; i < ndata; i++)
    { free(tcmask[i]);
      free(tcdata[i]);
    }
  }
  free(tcmask);
  free(tcdata);

  return;
}

/* ******************************************************************** */

double** CALL distancematrix (int nrows, int ncolumns, double** data,
  int** mask, double weights[], char dist, int transpose)
              
/*
-- distancematrix routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
May 16, 2002

Purpose
=======

The distancematrix routine calculates the distance matrix between genes or
microarrays using their measured gene expression data. Several distance measures
can be used. The routine returns a pointer to a ragged array containing the
distances between the genes. As the distance matrix is symmetric, with zeros on
the diagonal, only the lower triangular half of the distance matrix is saved.
The distancematrix routine allocates space for the distance matrix. If the
parameter transpose is set to a nonzero value, the distances between the columns
(microarrays) are calculated, otherwise distances between the rows (genes) are
calculated.


Arguments
=========

nrows     (input) int
The number of rows in the gene expression data matrix (i.e., the number of
genes)

ncolumns   (input) int
The number of columns in the gene expression data matrix (i.e., the number of
microarrays)

data       (input) double array, dimension( nrows,ncolumns )
The array containing the gene expression data.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask(i,j) == 0, then data(i,j) is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance. The length of this vector
is equal to the number of columns if the distances between genes are calculated,
or the number of rows if the distances between microarrays are calculated.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

transpose  (input) int
If transpose is equal to zero, the distances between the rows is
calculated. Otherwise, the distances between the columns is calculated.
The former is needed when genes are being clustered; the latter is used
when microarrays are being clustered.

========================================================================
*/
{ /* First determine the size of the distance matrix */
  const int n = (transpose==0) ? nrows : ncolumns;
  const int ndata = (transpose==0) ? ncolumns : nrows;
  int i,j;
  double** matrix;
  double (*metric)
    (int,double**,double**,int**,int**,const double[],int,int,int);

  if (n < 2) return 0;

  /* Set up the ragged array */
  matrix = (double**) malloc((size_t)n*sizeof(double*));
  for (i = 1; i < n; i++)
    matrix[i] = (double*) malloc((size_t)i*sizeof(double));
  /* The zeroth row has zero columns. It was allocates anyway for convenience.*/
  matrix[0] = 0;

  /* Set the metric function as indicated by dist */
  setmetric (dist, &metric);

  /* Calculate the distances and save them in the ragged array */
  for (i = 0; i < n; i++)
    for (j = 0; j < i; j++)
      matrix[i][j]=metric(ndata,data,data,mask,mask,weights,i,j,transpose);
  return matrix;
}


/* ******************************************************************** */

static
double getscale(int nelements, double** distmatrix, char dist)

/*
-- getscale routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
November 8, 2002

Purpose
=======

The getscale routine finds the value by which the distances should be scaled
such that all distances are between zero and two, as in case of the Pearson
distance.


Arguments
=========

nelements     (input) int
The number of elements to be clustered (i.e., the number of genes or
microarrays).

distmatrix (input) double array, ragged
  (number of rows is nelements, number of columns is equal to the row number)
The distance matrix. To save space, the distance matrix is given in the
form of a ragged array. The distance matrix is symmetric and has zeros
on the diagonal. See distancematrix for a description of the content.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, no scaling is done.

========================================================================
*/
{ switch (dist)
  { case 'a':
    case 'x':
      return 0.5;
    case 'e':
    case 'h':
    { int i,j;
      double maxvalue = 0.;
      for (i = 0; i < nelements; i++)
	for (j = 0; j < i; j++)
	  maxvalue = max(distmatrix[i][j], maxvalue);	
      return maxvalue/2.;
    }
  }
  return 1.0;
}

/* ******************************************************************** */

static
void pclcluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], double** distmatrix, char dist, int transpose,
  int result[][2], double linkdist[])

/*

Purpose
=======

The pclcluster routine performs clustering using pairwise centroid-linking
on a given set of gene expression data, using the distance metric given by dist.

Arguments
=========

nrows     (input) int
The number of rows in the gene expression data matrix, equal to the number of
genes.

ncolumns  (input) int
The number of columns in the gene expression data matrix, equal to the number of
microarrays.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the gene expression data.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance. The length of this vector
is ncolumns if genes are being clustered, and nrows if microarrays are being
clustered.

transpose  (input) int
If transpose==0, the rows of the matrix are clustered. Otherwise, columns
of the matrix are clustered.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

distmatrix (input) double**
The distance matrix. This matrix is precalculated by the calling routine
treecluster. The pclcluster routine modifies the contents of distmatrix, but
does not deallocate it.

result  (output) int array, dimension( nelements,2 )
The clustering solution. Each row in the matrix describes one linking event,
with the two columns containing the name of the nodes that were joined.
The original genes are numbered 0..ngenes-1, nodes are numbered 
-1..-(nelements-1), where nelements is nrows or ncolumns depending on whether
genes (rows) or microarrays (columns) are being clustered.

linkdist (output) double array, dimension(nelements-1)
For each node, the distance between the two subnodes that were joined. The
number of nodes (nnodes) is equal to the number of genes minus one if genes are
clustered, or the number of microarrays minus one if microarrays are clustered.

========================================================================
*/
{ double (*metric)
    (int,double**,double**,int**,int**,const double[],int,int,int);
  int i,j;
  const int nelements = (transpose==0) ? nrows : ncolumns;
  int* distid = (int*)malloc((size_t)nelements*sizeof(int));
  double** nodedata;
  int** nodecount;
  int inode;
  const int ndata = transpose ? nrows : ncolumns;
  const int nnodes = nelements - 1;

  /* Set the metric function as indicated by dist */
  setmetric (dist, &metric);

  for (i = 0; i < nelements; i++) distid[i] =i;
  /* To remember which row/column in the distance matrix contains what */

  /* Storage for node data */
  if (transpose)
  { nodedata = (double**)malloc((size_t)ndata*sizeof(double*));
    nodecount = (int**)malloc((size_t)ndata*sizeof(int*));
    for (i = 0; i < ndata; i++)
    { nodedata[i] = (double*)malloc((size_t)nnodes*sizeof(double));
      nodecount[i] = (int*)malloc((size_t)nnodes*sizeof(int));
    }
  }
  else
  { nodedata = (double**)malloc((size_t)nnodes*sizeof(double*));
    nodecount = (int**)malloc((size_t)nnodes*sizeof(int*));
    for (i = 0; i < nnodes; i++)
    { nodedata[i] = (double*)malloc((size_t)ndata*sizeof(double));
      nodecount[i] = (int*)malloc((size_t)ndata*sizeof(int));
    }
  }

  for (inode = 0; inode < nnodes; inode++)
  { /* Find the pair with the shortest distance */
    int isaved = 1;
    int jsaved = 0;
    double distance = distmatrix[1][0];
    for (i = 0; i < nelements-inode; i++)
      for (j = 0; j < i; j++)
      { if (distmatrix[i][j]<distance)
        { distance = distmatrix[i][j];
          isaved = i;
          jsaved = j;
        }
      }
    result[inode][0] = distid[jsaved];
    result[inode][1] = distid[isaved];
    linkdist[inode] = distance;

    /* Make node jsaved the new node */
    if (transpose)
    { for (i = 0; i < ndata; i++)
      { nodedata[i][inode] = 0.;
        nodecount[i][inode] = 0;
        if (distid[isaved]<0)
        { const int nodecolumn = -distid[isaved]-1;
          const int count = nodecount[i][nodecolumn];
          nodecount[i][inode] += count;
          nodedata[i][inode] += nodedata[i][nodecolumn] * count;
        }
        else
        { const int datacolumn = distid[isaved];
          if (mask[i][datacolumn])
          { nodecount[i][inode]++;
            nodedata[i][inode] += data[i][datacolumn];
          }
        }
        if (distid[jsaved]<0)
        { const int nodecolumn = -distid[jsaved]-1;
          const int count = nodecount[i][nodecolumn];
          nodecount[i][inode] += count;
          nodedata[i][inode] += nodedata[i][nodecolumn] * count;
        }
        else
        { const int datacolumn = distid[jsaved];
          if (mask[i][datacolumn])
          { nodecount[i][inode]++;
            nodedata[i][inode] += data[i][datacolumn];
          }
        }
        if (nodecount[i][inode] > 0) nodedata[i][inode] /= nodecount[i][inode];
      }
    }
    else
    { for (i = 0; i < ndata; i++)
      { nodedata[inode][i] = 0.;
        nodecount[inode][i] = 0;
        if (distid[isaved]<0)
        { const int noderow = -distid[isaved]-1;
          const int count = nodecount[noderow][i];
          nodecount[inode][i] += count;
          nodedata[inode][i] += nodedata[noderow][i] * count;
        }
        else
        { const int datarow = distid[isaved];
          if (mask[datarow][i])
          { nodecount[inode][i]++;
            nodedata[inode][i] += data[datarow][i];
          }
        }
        if (distid[jsaved]<0)
        { const int noderow = -distid[jsaved]-1;
          const int count = nodecount[noderow][i];
          nodecount[inode][i] += count;
          nodedata[inode][i] += nodedata[noderow][i] * count;
        }
        else
        { const int datarow = distid[jsaved];
          if (mask[datarow][i])
          { nodecount[inode][i]++;
            nodedata[inode][i] += data[datarow][i];
          }
        }
        if (nodecount[inode][i] > 0) nodedata[inode][i] /= nodecount[inode][i];
      }
    }
  
    /* Fix the distances */
    distid[isaved] = distid[nnodes-inode];
    for (i = 0; i < isaved; i++)
      distmatrix[isaved][i] = distmatrix[nnodes-inode][i];
    for (i = isaved + 1; i < nnodes-inode; i++)
      distmatrix[i][isaved] = distmatrix[nnodes-inode][i];

    distid[jsaved] = -inode-1;
    for (i = 0; i < jsaved; i++)
    { if (distid[i]<0)
      { distmatrix[jsaved][i] = 
          metric(ndata,nodedata,nodedata,nodecount,nodecount,
                 weight,inode,-distid[i]-1,transpose);
      }
      else
      { distmatrix[jsaved][i] =
          metric(ndata,nodedata,data,nodecount,mask,
                 weight,inode,distid[i],transpose);
      }
    }
    for (i = jsaved + 1; i < nnodes-inode; i++)
    { if (distid[i]<0)
      { distmatrix[i][jsaved] =
          metric(ndata,nodedata,nodedata,nodecount,nodecount,
                 weight,inode,-distid[i]-1,transpose);
      }
      else
      { distmatrix[i][jsaved] =
          metric(ndata,nodedata,data,nodecount,mask,
                 weight,inode,distid[i],transpose);
      }
    }
  }

  /* Free temporarily allocated space */
  if (transpose)
  { for (i = 0; i < ndata; i++)
    { free(nodedata[i]);
      free(nodecount[i]);
    }
  }
  else
  { for (i = 0; i < nnodes; i++)
    { free(nodedata[i]);
      free(nodecount[i]);
    }
  }
  free(nodedata);
  free(nodecount);
  free(distid);
 
  return;
}

/* ********************************************************************* */

static
void pslcluster (int nelements, double** distmatrix, int result[][2],
  double linkdist[])
/*

Purpose
=======

The pslcluster routine performs clustering using pairwise single-linking
on the given distance matrix.

Arguments
=========

nelements     (input) int
The number of elements to be clustered.

distmatrix (input) double**
The distance matrix, with nelements rows, each row being filled up to the
diagonal. The elements on the diagonal are not used, as they are assumed to be
zero. The distance matrix will be modified by this routine.

result  (output) int array, dimension( nelements,2 )
The clustering solution. Each row in the matrix describes one linking event,
with the two columns containing the name of the nodes that were joined.
The original elements are numbered 0..nelements-1, nodes are numbered 
-1..-(nelements-1).

linkdist (output) double array, dimension(nelements-1)
For each node, the distance between the two subnodes that were joined. The
number of nodes (nnodes) is equal to the number of genes minus one if genes are
clustered, or the number of microarrays minus one if microarrays are clustered.

========================================================================
*/
{ int i, j;
  int nNodes;

  /* Setup a list specifying to which cluster a gene belongs */
  int* clusterid = (int*)malloc((size_t)nelements*sizeof(int));
  for (i = 0; i < nelements; i++) clusterid[i] = i;

  for (nNodes = nelements; nNodes > 1; nNodes--)
  { int isaved = 1;
    int jsaved = 0;
    double distance = distmatrix[1][0];
    for (i = 0; i < nNodes; i++)
    { for (j = 0; j < i; j++)
      { if (distmatrix[i][j] < distance)
        { isaved = i;
          jsaved = j;
          distance = distmatrix[i][j];
        }
      }
    }
    linkdist[nelements-nNodes] = distance;

    /* Fix the distances */
    for (j = 0; j < jsaved; j++)
      distmatrix[jsaved][j] = min(distmatrix[isaved][j],distmatrix[jsaved][j]);
    for (j = jsaved+1; j < isaved; j++)
      distmatrix[j][jsaved] = min(distmatrix[isaved][j],distmatrix[j][jsaved]);
    for (j = isaved+1; j < nNodes; j++)
      distmatrix[j][jsaved] = min(distmatrix[j][isaved],distmatrix[j][jsaved]);

    for (j = 0; j < isaved; j++)
      distmatrix[isaved][j] = distmatrix[nNodes-1][j];
    for (j = isaved+1; j < nNodes-1; j++)
      distmatrix[j][isaved] = distmatrix[nNodes-1][j];

    /* Update clusterids */
    result[nelements-nNodes][0] = clusterid[isaved];
    result[nelements-nNodes][1] = clusterid[jsaved];
    clusterid[jsaved] = nNodes-nelements-1;
    clusterid[isaved] = clusterid[nNodes-1];
  }
  free(clusterid);
 
  return;
}

/* ******************************************************************** */

static
void pmlcluster (int nelements, double** distmatrix, int result[][2],
  double linkdist[])
/*

Purpose
=======

The pmlcluster routine performs clustering using pairwise maximum- (complete-)
linking on the given distance matrix.

Arguments
=========

nelements     (input) int
The number of elements to be clustered.

distmatrix (input) double**
The distance matrix, with nelements rows, each row being filled up to the
diagonal. The elements on the diagonal are not used, as they are assumed to be
zero. The distance matrix will be modified by this routine.

result  (output) int array, dimension( nelements,2 )
The clustering solution. Each row in the matrix describes one linking event,
with the two columns containing the name of the nodes that were joined.
The original elements are numbered 0..nelements-1, nodes are numbered 
-1..-(nelements-1).

linkdist (output) double array, dimension(nelements-1)
For each node, the distance between the two subnodes that were joined. The
number of nodes (nnodes) is equal to the number of genes minus one if genes are
clustered, or the number of microarrays minus one if microarrays are clustered.

========================================================================
*/
{ int i,j;
  int nNodes;

  /* Setup a list specifying to which cluster a gene belongs */
  int* clusterid = (int*)malloc((size_t)nelements*sizeof(int));
  for (i = 0; i < nelements; i++) clusterid[i] = i;

  for (nNodes = nelements; nNodes > 1; nNodes--)
  { int isaved = 1;
    int jsaved = 0;
    double distance = distmatrix[1][0];
    for (i = 0; i < nNodes; i++)
      for (j = 0; j < i; j++)
      { if (distmatrix[i][j] < distance)
        { isaved = i;
          jsaved = j;
          distance = distmatrix[i][j];
        }
      }
    linkdist[nelements-nNodes] = distance;

    /* Fix the distances */
    for (j = 0; j < jsaved; j++)
      distmatrix[jsaved][j] = max(distmatrix[isaved][j],distmatrix[jsaved][j]);
    for (j = jsaved+1; j < isaved; j++)
      distmatrix[j][jsaved] = max(distmatrix[isaved][j],distmatrix[j][jsaved]);
    for (j = isaved+1; j < nNodes; j++)
      distmatrix[j][jsaved] = max(distmatrix[j][isaved],distmatrix[j][jsaved]);

    for (j = 0; j < isaved; j++)
      distmatrix[isaved][j] = distmatrix[nNodes-1][j];
    for (j = isaved+1; j < nNodes-1; j++)
      distmatrix[j][isaved] = distmatrix[nNodes-1][j];

    /* Update clusterids */
    result[nelements-nNodes][0] = clusterid[isaved];
    result[nelements-nNodes][1] = clusterid[jsaved];
    clusterid[jsaved] = nNodes-nelements-1;
    clusterid[isaved] = clusterid[nNodes-1];
  }
  free(clusterid);

  return;
}

/* ******************************************************************* */

static
void palcluster (int nelements, double** distmatrix, int result[][2],
  double linkdist[])
/*

Purpose
=======

The palcluster routine performs clustering using pairwise average
linking on the given distance matrix.

Arguments
=========

nelements     (input) int
The number of elements to be clustered.

distmatrix (input) double**
The distance matrix, with nelements rows, each row being filled up to the
diagonal. The elements on the diagonal are not used, as they are assumed to be
zero. The distance matrix will be modified by this routine.

result  (output) int array, dimension( nelements,2 )
The clustering solution. Each row in the matrix describes one linking event,
with the two columns containing the name of the nodes that were joined.
The original elements are numbered 0..nelements-1, nodes are numbered 
-1..-(nelements-1).

linkdist (output) double array, dimension(nelements-1)
For each node, the distance between the two subnodes that were joined. The
number of nodes (nnodes) is equal to the number of genes minus one if genes are
clustered, or the number of microarrays minus one if microarrays are clustered.

========================================================================
*/
{ int i,j;
  int nNodes;

  /* Keep track of the number of elements in each cluster
   * (needed to calculate the average) */
  int* number = (int*)malloc((size_t)nelements*sizeof(int));
  /* Setup a list specifying to which cluster a gene belongs */
  int* clusterid = (int*)malloc((size_t)nelements*sizeof(int));
  for (i = 0; i < nelements; i++)
  { number[i] = 1;
    clusterid[i] = i;
  }

  for (nNodes = nelements; nNodes > 1; nNodes--)
  { int sum;
    int isaved = 1;
    int jsaved = 0;
    double distance = distmatrix[1][0];
    for (i = 0; i < nNodes; i++)
      for (j = 0; j < i; j++)
      { if (distmatrix[i][j] < distance)
        { isaved = i;
          jsaved = j;
          distance = distmatrix[i][j];
        }
      }

    /* Save result */
    result[nelements-nNodes][0] = clusterid[isaved];
    result[nelements-nNodes][1] = clusterid[jsaved];
    linkdist[nelements-nNodes] = distance;

    /* Fix the distances */
    sum = number[isaved] + number[jsaved];
    for (j = 0; j < jsaved; j++)
    { distmatrix[jsaved][j] = distmatrix[isaved][j]*number[isaved]
                            + distmatrix[jsaved][j]*number[jsaved];
      distmatrix[jsaved][j] /= sum;
    }
    for (j = jsaved+1; j < isaved; j++)
    { distmatrix[j][jsaved] = distmatrix[isaved][j]*number[isaved]
                            + distmatrix[j][jsaved]*number[jsaved];
      distmatrix[j][jsaved] /= sum;
    }
    for (j = isaved+1; j < nNodes-1; j++)
    { distmatrix[j][jsaved] = distmatrix[j][isaved]*number[isaved]
                            + distmatrix[j][jsaved]*number[jsaved];
      distmatrix[j][jsaved] /= sum;
    }

    for (j = 0; j < isaved; j++)
      distmatrix[isaved][j] = distmatrix[nNodes-1][j];
    for (j = isaved+1; j < nNodes-1; j++)
      distmatrix[j][isaved] = distmatrix[nNodes-1][j];

    /* Update number of elements in the clusters */
    number[jsaved] = sum;
    number[isaved] = number[nNodes-1];

    /* Update clusterids */
    clusterid[jsaved] = nNodes-nelements-1;
    clusterid[isaved] = clusterid[nNodes-1];
  }
  free(clusterid);
  free(number);

  return;
}

/* ******************************************************************* */

void CALL treecluster (int nrows, int ncolumns, double** data, int** mask,
  double weight[], int applyscale, int transpose, char dist, char method,
  int result[][2], double linkdist[], double** distmatrix)
/*

Purpose
=======

The treecluster routine performs hierarchical clustering using pairwise
single-, maximum-, centroid-, or average-linkage, as defined by method, on a
given set of gene expression data, using the distance metric given by dist.

Arguments
=========

nrows     (input) int
The number of rows in the data matrix, equal to the number of genes.

ncolumns  (input) int
The number of columns in the data matrix, equal to the number of microarrays.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the data of the vectors to be clustered.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

weight (input) double array, dimension( n )
The weights that are used to calculate the distance.

applyscale      (input) int
If applyscale is nonzero, then the distances in linkdist are scaled such
that all distances are between zero and two, as in case of the Pearson
distance. Otherwise, no scaling is applied.

transpose  (input) int
If transpose==0, the rows of the matrix are clustered. Otherwise, columns
of the matrix are clustered.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

method     (input) char
Defines which hierarchical clustering method is used:
method=='s': pairwise single-linkage clustering
method=='m': pairwise maximum- (or complete-) linkage clustering
method=='a': pairwise average-linkage clustering
method=='c': pairwise centroid-linkage clustering
For the first three, either the distance matrix or the gene expression data is
sufficient to perform the clustering algorithm. For pairwise centroid-linkage
clustering, however, the gene expression data are always needed, even if the
distance matrix itself is available.

result  (output) int array, dimension( nelements-1,2 )
The clustering solution. Each row in the matrix describes one linking event,
with the two columns containing the name of the nodes that were joined.
The original elements are numbered 0..nelements-1, nodes are numbered 
-1..-(nelements-1), where nelements is nrows or ncolumns depending on whether
genes (rows) or microarrays (columns) are being clustered.

linkdist (output) double array, dimension(nelements-1)
For each node, the distance between the two subnodes that were joined. The
number of nodes (nnodes) is equal to the number of genes minus one if genes are
clustered, or the number of microarrays minus one if microarrays are clustered.

distmatrix (input) double**
The distance matrix. If the distance matrix is zero initially, the distance
matrix will be allocated and calculated from the data by treecluster, and
deallocated before treecluster returns. If the distance matrix is passed by the
calling routine, treecluster will modify the contents of the distance matrix as
part of the clustering algorithm, but will not deallocate it. The calling
routine should deallocate the distance matrix after the return from treecluster.

========================================================================
*/
{ const int nelements = (transpose==0) ? nrows : ncolumns;
  const int ldistmatrix = (distmatrix==0) ? 0 : 1;
  int i;

  if (nelements < 2) return;

  /* Calculate the distance matrix if the user didn't give it */
  if(!ldistmatrix)
    distmatrix = 
      distancematrix (nrows, ncolumns, data, mask, weight, dist, transpose);

  switch(method) 
  { case 's':
      pslcluster(nelements, distmatrix, result, linkdist);
      break;
    case 'm':
      pmlcluster(nelements, distmatrix, result, linkdist);
      break;
    case 'a':
      palcluster(nelements, distmatrix, result, linkdist);
      break;
    case 'c':
      pclcluster(nrows, ncolumns, data, mask, weight, distmatrix, dist,
		transpose, result, linkdist);
      break;
  }

  /* Scale the distances in linkdist if so requested */
  if (applyscale)
  { double scale = getscale(nelements, distmatrix, dist);
    for (i = 0; i < nelements-1; i++) linkdist[i] /= scale;
  }
 
  /* Deallocate space for distance matrix, if it was allocated by treecluster */
  if (!ldistmatrix)
  { for (i = 1; i < nelements; i++) free(distmatrix[i]);
    free (distmatrix);
  }
 
  return;
}

/* ******************************************************************* */

static
void somworker (int nrows, int ncolumns, double** data, int** mask,
  const double weights[], int transpose, int nxgrid, int nygrid,
  double inittau, double*** celldata, int niter, char dist)

{ const int nelements = (transpose==0) ? nrows : ncolumns;
  const int ndata = (transpose==0) ? ncolumns : nrows;
  double (*metric)
    (int,double**,double**,int**,int**,const double[],int,int,int);
  int i, j;
  double* stddata = (double*)malloc((size_t)nelements*sizeof(double));
  int** dummymask;
  int ix, iy;
  long* index;
  int iter;
  /* Maximum radius in which nodes are adjusted */
  double maxradius = sqrt(nxgrid*nxgrid+nygrid*nygrid);

  /* Initialize the random number generator */
  initran();

  /* Set the metric function as indicated by dist */
  setmetric (dist, &metric);

  /* Calculate the standard deviation for each row or column */
  if (transpose==0)
  { for (i = 0; i < nelements; i++)
    { stddata[i] = 0.;
      for (j = 0; j < ndata; j++)
      { double term = data[i][j];
        term = term * term;
        stddata[i] += term;
      }
      stddata[i] = sqrt(stddata[i]);
      if (stddata[i]==0) stddata[i] = 1;
    }
  }
  else
  { for (i = 0; i < nelements; i++)
    { stddata[i] = 0.;
      for (j = 0; j < ndata; j++)
      { double term = data[j][i];
        term = term * term;
        stddata[i] += term;
      }
      stddata[i] = sqrt(stddata[i]);
      if (stddata[i]==0) stddata[i] = 1;
    }
  }

  if (transpose==0)
  { dummymask = (int**)malloc((size_t)nygrid*sizeof(int*));
    for (i = 0; i < nygrid; i++)
      dummymask[i] = (int*)malloc((size_t)ndata*sizeof(int));
    for (i = 0; i < nygrid; i++)
      for (j = 0; j < ndata; j++)
        dummymask[i][j] = 1;
  }
  else
  { dummymask = (int**)malloc((size_t)ndata*sizeof(int*));
    for (i = 0; i < ndata; i++)
    { dummymask[i] = (int*)malloc(sizeof(int));
      dummymask[i][0] = 1;
    }
  }

  /* Randomly initialize the nodes */
  for (ix = 0; ix < nxgrid; ix++)
  { for (iy = 0; iy < nygrid; iy++)
    { double sum = 0.;
      for (i = 0; i < ndata; i++)
      { double term = genunf(-1.,1.);
        celldata[ix][iy][i] = term;
        sum += term * term;
      }
      sum = sqrt(sum);
      for (i = 0; i < ndata; i++) celldata[ix][iy][i] /= sum;
    }
  }

  /* Randomize the order in which genes or arrays will be used */
  index = (long*)malloc((size_t)nelements*sizeof(long));
  for (i = 0; i < nelements; i++) index[i] = i;
  genprm (index, nelements);

  /* Start the iteration */
  for (iter = 0; iter < niter; iter++)
  { int ixbest = 0;
    int iybest = 0;
    long iobject = iter % nelements;
    iobject = index[iobject];
    if (transpose==0)
    { double closest = metric(ndata,data,celldata[ixbest],
        mask,dummymask,weights,iobject,iybest,transpose);
      double radius = maxradius * (1. - ((double)iter)/((double)niter));
      double tau = inittau * (1. - ((double)iter)/((double)niter));

      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { double distance =
            metric (ndata,data,celldata[ix],
              mask,dummymask,weights,iobject,iy,transpose);
          if (distance < closest)
          { ixbest = ix;
            iybest = iy;
            closest = distance;
          }
        }
      }
      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { if (sqrt((ix-ixbest)*(ix-ixbest)+(iy-iybest)*(iy-iybest))<radius)
          { double sum = 0.;
            for (i = 0; i < ndata; i++)
              celldata[ix][iy][i] +=
                tau * (data[iobject][i]/stddata[iobject]-celldata[ix][iy][i]);
            for (i = 0; i < ndata; i++)
            { double term = celldata[ix][iy][i];
              term = term * term;
              sum += term;
            }
            sum = sqrt(sum);
            if (sum>0)
              for (i = 0; i < ndata; i++) celldata[ix][iy][i] /= sum;
          }
        }
      }
    }
    else
    { double closest;
      double** celldatavector =
        (double**)malloc((size_t)ndata*sizeof(double*));
      double radius = maxradius * (1. - ((double)iter)/((double)niter));
      double tau = inittau * (1. - ((double)iter)/((double)niter));

      for (i = 0; i < ndata; i++)
        celldatavector[i] = &(celldata[ixbest][iybest][i]); 
      closest = metric(ndata,data,celldatavector,
        mask,dummymask,weights,iobject,0,transpose);
      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { double distance;
          for (i = 0; i < ndata; i++)
            celldatavector[i] = &(celldata[ixbest][iybest][i]); 
          distance =
            metric (ndata,data,celldatavector,
              mask,dummymask,weights,iobject,0,transpose);
          if (distance < closest)
          { ixbest = ix;
            iybest = iy;
            closest = distance;
          }
        }
      }
      free(celldatavector);
      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { if (sqrt((ix-ixbest)*(ix-ixbest)+(iy-iybest)*(iy-iybest))<radius)
          { double sum = 0.;
            for (i = 0; i < ndata; i++)
              celldata[ix][iy][i] +=
                tau * (data[i][iobject]/stddata[iobject]-celldata[ix][iy][i]);
            for (i = 0; i < ndata; i++)
            { double term = celldata[ix][iy][i];
              term = term * term;
              sum += term;
            }
            sum = sqrt(sum);
            if (sum>0)
              for (i = 0; i < ndata; i++) celldata[ix][iy][i] /= sum;
          }
        }
      }
    }
  }
  if (transpose==0)
    for (i = 0; i < nygrid; i++) free(dummymask[i]);
  else
    for (i = 0; i < ndata; i++) free(dummymask[i]);
  free(dummymask);
  free(stddata);
  free(index);
  return;
}

/* ******************************************************************* */

static
void somassign (int nrows, int ncolumns, double** data, int** mask,
  const double weights[], int transpose, int nxgrid, int nygrid,
  double*** celldata, char dist, int clusterid[][2])
/* Collect clusterids */
{ double (*metric)
    (int,double**,double**,int**,int**, const double[],int,int,int);
  const int ndata = (transpose==0) ? ncolumns : nrows;
  int i,j;

  setmetric (dist, &metric);

  if (transpose==0)
  { int** dummymask = (int**)malloc((size_t)nygrid*sizeof(int*));
    for (i = 0; i < nygrid; i++)
      dummymask[i] = (int*)malloc((size_t)ncolumns*sizeof(int));
    for (i = 0; i < nygrid; i++)
      for (j = 0; j < ncolumns; j++)
        dummymask[i][j] = 1;
    for (i = 0; i < nrows; i++)
    { int ixbest = 0;
      int iybest = 0;
      double closest = metric(ndata,data,celldata[ixbest],
        mask,dummymask,weights,i,iybest,transpose);
      int ix, iy;
      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { double distance =
            metric (ndata,data,celldata[ix],
              mask,dummymask,weights,i,iy,transpose);
          if (distance < closest)
          { ixbest = ix;
            iybest = iy;
            closest = distance;
          }
        }
      }
      clusterid[i][0] = ixbest;
      clusterid[i][1] = iybest;
    }
    for (i = 0; i < nygrid; i++) free(dummymask[i]);
    free(dummymask);
  }
  else
  { double** celldatavector = (double**)malloc((size_t)ndata*sizeof(double*));
    int** dummymask = (int**)malloc((size_t)nrows*sizeof(int*));
    int ixbest = 0;
    int iybest = 0;
    for (i = 0; i < nrows; i++)
    { dummymask[i] = (int*)malloc(sizeof(int));
      dummymask[i][0] = 1;
    }
    for (i = 0; i < ncolumns; i++)
    { double closest;
      int ix, iy;
      for (j = 0; j < ndata; j++)
        celldatavector[j] = &(celldata[ixbest][iybest][j]); 
      closest = metric(ndata,data,celldatavector,
        mask,dummymask,weights,i,0,transpose);
      for (ix = 0; ix < nxgrid; ix++)
      { for (iy = 0; iy < nygrid; iy++)
        { double distance;
          for(j = 0; j < ndata; j++)
            celldatavector[j] = &(celldata[ix][iy][j]); 
          distance = metric(ndata,data,celldatavector,
            mask,dummymask,weights,i,0,transpose);
          if (distance < closest)
          { ixbest = ix;
            iybest = iy;
            closest = distance;
          }
        }
      }
      clusterid[i][0] = ixbest;
      clusterid[i][1] = iybest;
    }
    free(celldatavector);
    for (i = 0; i < nrows; i++) free(dummymask[i]);
    free(dummymask);
  }
  return;
}

/* ******************************************************************* */

void CALL somcluster (int nrows, int ncolumns, double** data, int** mask,
  const double weight[], int transpose, int nxgrid, int nygrid,
  double inittau, int niter, char dist, double*** celldata, int clusterid[][2])
/*

Purpose
=======

The somcluster routine implements a self-organizing map (Kohonen) on a
rectangular grid, using a given set of vectors. The distance measure to be
used to find the similarity between genes and nodes is given by dist.

Arguments
=========

nrows     (input) int
The number of rows in the data matrix, equal to the number of genes.

ncolumns  (input) int
The number of columns in the data matrix, equal to the number of microarrays.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the gene expression data.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask[i][j] == 0, then data[i][j] is missing.

weights    (input) double array, dimension( n )
The weights that are used to calculate the distance. The length of this vector
is ncolumns if genes are being clustered, or nrows if microarrays are being
clustered.

transpose  (input) int
If transpose==0, the rows of the matrix are clustered. Otherwise, columns
of the matrix are clustered.

nxgrid    (input) int
The number of grid cells horizontally in the rectangular topology of clusters.

nygrid    (input) int
The number of grid cells horizontally in the rectangular topology of clusters.

inittau    (input) double
The initial value of tau, representing the neighborhood function.

niter      (input) int
The number of iterations to be performed.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

celldata (output) double array,
  dimension(nxgrid, nygrid, ncolumns) if genes are being clustered
  dimension(nxgrid, nygrid, nrows) if microarrays are being clustered
The gene expression data for each node (cell) in the 2D grid. This can be
interpreted as the centroid for the cluster corresponding to that cell. If
celldata is NULL, then the centroids are not returned. If celldata is not
NULL, enough space should be allocated to store the centroid data before callingsomcluster.

clusterid (output), int[nrows][2] if genes are being clustered
                    int[ncolumns][2] if microarrays are being clustered
For each item (gene or microarray) that is clustered, the coordinates of the
cell in the 2D grid to which the item was assigned. If clusterid is NULL, the
cluster assignments are not returned. If clusterid is not NULL, enough memory
should be allocated to store the clustering information before calling
somcluster.

========================================================================
*/
{ const int nobjects = (transpose==0) ? nrows : ncolumns;
  const int ndata = (transpose==0) ? ncolumns : nrows;
  int i,j;
  const int lcelldata = (celldata==NULL) ? 0 : 1;

  if (nobjects < 2) return;

  if (lcelldata==0)
  { celldata =
      (double***)malloc((size_t)nxgrid*nygrid*ndata*sizeof(double**));
    for (i = 0; i < nxgrid; i++)
      celldata[i] = (double**) malloc((size_t)nygrid*ndata*sizeof(double*));
    for (i = 0; i < nxgrid; i++)
      for (j = 0; j < nygrid; j++)
        celldata[i][j] = (double*) malloc((size_t)ndata*sizeof(double));
  }

  somworker (nrows, ncolumns, data, mask, weight, transpose, nxgrid, nygrid,
    inittau, celldata, niter, dist);
  if (clusterid)
    somassign (nrows, ncolumns, data, mask, weight, transpose,
      nxgrid, nygrid, celldata, dist, clusterid);
  if(lcelldata==0)
  { for (i = 0; i < nxgrid; i++)
      for (j = 0; j < nygrid; j++)
        free(celldata[i][j]);
    for (i = 0; i < nxgrid; i++)
      free(celldata[i]);
    free(celldata);
  }
  return;
}

/* ******************************************************************** */

double CALL clusterdistance (int nrows, int ncolumns, double** data,
  int** mask, double weight[], int n1, int n2, int index1[], int index2[],
  char dist, char method, int transpose)
              
/*
-- clusterdistance routine --
Michiel de Hoon (mdehoon@ims.u-tokyo.ac.jp)
Laboratory of DNA Information Analysis, Human Genome Center
Institute of Medical Science, University of Tokyo
September 3, 2002

Purpose
=======

The clusterdistance routine calculates the distance between two clusters
containing genes or microarrays using the measured gene expression vectors. The
distance between clusters, given the genes/microarrays in each cluster, can be
defined in several ways. Several distance measures can be used.

The routine returns the distance in double precision.
If the parameter transpose is set to a nonzero value, the clusters are
interpreted as clusters of microarrays, otherwise as clusters of gene.

Arguments
=========

nrows     (input) int
The number of rows (i.e., the number of genes) in the gene expression data
matrix.

ncolumns      (input) int
The number of columns (i.e., the number of microarrays) in the gene expression
data matrix.

data       (input) double array, dimension( nrows,ncolumns )
The array containing the data of the vectors.

mask       (input) int array, dimension( nrows,ncolumns )
This array shows which data values are missing. If
mask(i,j) == 0, then data(i,j) is missing.

weight     (input) double array, dimension( n )
The weights that are used to calculate the distance.

n1         (input) int
The number of elements in the first cluster.

n2         (input) int
The number of elements in the second cluster.

index1     (input) int array, dimension ( n1 )
Identifies which genes/microarrays belong to the first cluster.

index2     (input) int array, dimension ( n2 )
Identifies which genes/microarrays belong to the second cluster.

dist       (input) char
Defines which distance measure is used, as given by the table:
dist=='e': Euclidean distance
dist=='h': Harmonically summed Euclidean distance
dist=='c': correlation
dist=='a': absolute value of the correlation
dist=='u': uncentered correlation
dist=='x': absolute uncentered correlation
dist=='s': Spearman's rank correlation
dist=='k': Kendall's tau
For other values of dist, the default (Euclidean distance) is used.

method     (input) char
Defines how the distance between two clusters is defined, given which genes
belong to which cluster:
method=='a': the distance between the arithmic means of the two clusters
method=='m': the distance between the medians of the two clusters
method=='s': the smallest pairwise distance between members of the two clusters
method=='x': the largest pairwise distance between members of the two clusters
method=='v': average of the pairwise distances between members of the clusters

transpose  (input) int
If transpose is equal to zero, the distances between the rows is
calculated. Otherwise, the distances between the columns is calculated.
The former is needed when genes are being clustered; the latter is used
when microarrays are being clustered.

========================================================================
*/
{ double (*metric)
    (int,double**,double**,int**,int**, const double[],int,int,int);
  /* if one or both clusters are empty, return */
  if (n1 < 1 || n2 < 1) return 0;
  /* Check the indeces */
  if (transpose==0)
  { int i;
    for (i = 0; i < n1; i++)
    { int index = index1[i];
      if (index < 0 || index >= nrows) return 0;
    }
    for (i = 0; i < n2; i++)
    { int index = index2[i];
      if (index < 0 || index >= nrows) return 0;
    }
  }
  else
  { int i;
    for (i = 0; i < n1; i++)
    { int index = index1[i];
      if (index < 0 || index >= ncolumns) return 0;
    }
    for (i = 0; i < n2; i++)
    { int index = index2[i];
      if (index < 0 || index >= ncolumns) return 0;
    }
  }
  /* Set the metric function as indicated by dist */
  setmetric (dist, &metric);
  switch (method)
  { case 'a':
    { /* Find the center */
      int i,j,k;
      if (transpose==0)
      { double distance;
        double* cdata[2];
        int* cmask[2];
        int* count[2];
        count[0] = (int*)malloc((size_t)ncolumns*sizeof(int));
        count[1] = (int*)malloc((size_t)ncolumns*sizeof(int));
        cdata[0] = (double*)malloc((size_t)ncolumns*sizeof(double));
        cdata[1] = (double*)malloc((size_t)ncolumns*sizeof(double));
        cmask[0] = (int*)malloc((size_t)ncolumns*sizeof(int));
        cmask[1] = (int*)malloc((size_t)ncolumns*sizeof(int));
        for (i = 0; i < 2; i++)
          for (j = 0; j < ncolumns; j++)
          { count[i][j] = 0;
            cdata[i][j] = 0.;
          }
        for (i = 0; i < n1; i++)
        { k = index1[i];
          for (j = 0; j < ncolumns; j++)
            if (mask[k][j] != 0)
            { cdata[0][j] = cdata[0][j] + data[k][j];
              count[0][j] = count[0][j] + 1;
            }
        }
        for (i = 0; i < n2; i++)
        { k = index2[i];
          for (j = 0; j < ncolumns; j++)
            if (mask[k][j] != 0)
            { cdata[1][j] = cdata[1][j] + data[k][j];
              count[1][j] = count[1][j] + 1;
            }
        }
        for (i = 0; i < 2; i++)
          for (j = 0; j < ncolumns; j++)
          { if (count[i][j]>0)
            { cdata[i][j] = cdata[i][j] / count[i][j];
              cmask[i][j] = 1;
            }
            else
              cmask[i][j] = 0;
          }
        distance =
          metric (ncolumns,cdata,cdata,cmask,cmask,weight,0,1,0);
        for (i = 0; i < 2; i++)
        { free (cdata[i]);
          free (cmask[i]);
          free (count[i]);
        }
        return distance;
      }
      else
      { double distance;
        int** count = (int**)malloc((size_t)nrows*sizeof(int*));
        double** cdata = (double**)malloc((size_t)nrows*sizeof(double*));
        int** cmask = (int**)malloc((size_t)nrows*sizeof(int*));
        for (i = 0; i < nrows; i++)
        { count[i] = (int*)malloc((size_t)2*sizeof(int));
          cdata[i] = (double*)malloc((size_t)2*sizeof(double));
          cmask[i] = (int*)malloc((size_t)2*sizeof(int));
        }
        for (i = 0; i < nrows; i++)
        { for (j = 0; j < 2; j++)
          { count[i][j] = 0;
            cdata[i][j] = 0.;
          }
        }
        for (i = 0; i < n1; i++)
        { k = index1[i];
          for (j = 0; j < nrows; j++)
          { if (mask[j][k] != 0)
            { cdata[j][0] = cdata[j][0] + data[j][k];
              count[j][0] = count[j][0] + 1;
            }
          }
        }
        for (i = 0; i < n2; i++)
        { k = index2[i];
          for (j = 0; j < nrows; j++)
          { if (mask[j][k] != 0)
            { cdata[j][1] = cdata[j][1] + data[j][k];
              count[j][1] = count[j][1] + 1;
            }
          }
        }
        for (i = 0; i < nrows; i++)
          for (j = 0; j < 2; j++)
            if (count[i][j]>0)
            { cdata[i][j] = cdata[i][j] / count[i][j];
              cmask[i][j] = 1;
            }
            else
              cmask[i][j] = 0;
        distance = metric (nrows,cdata,cdata,cmask,cmask,weight,0,1,1);
        for (i = 0; i < nrows; i++)
        { free (count[i]);
          free (cdata[i]);
          free (cmask[i]);
        }
        free (count);
        free (cdata);
        free (cmask);
        return distance;
      }
    }
    case 'm':
    { int i, j, k;
      if (transpose==0)
      { double distance;
        double* temp = (double*)malloc((size_t)nrows*sizeof(double));
        double* cdata[2];
        int* cmask[2];
        for (i = 0; i < 2; i++)
        { cdata[i] = (double*)malloc((size_t)ncolumns*sizeof(double));
          cmask[i] = (int*)malloc((size_t)ncolumns*sizeof(int));
        }
        for (j = 0; j < ncolumns; j++)
        { int count = 0;
          for (k = 0; k < n1; k++)
          { i = index1[k];
            if (mask[i][j])
            { temp[count] = data[i][j];
              count++;
            }
          }
          if (count>0)
          { cdata[0][j] = median (count,temp);
            cmask[0][j] = 1;
          }
          else
          { cdata[0][j] = 0.;
            cmask[0][j] = 0;
          }
        }
        for (j = 0; j < ncolumns; j++)
        { int count = 0;
          for (k = 0; k < n2; k++)
          { i = index2[k];
            if (mask[i][j])
            { temp[count] = data[i][j];
              count++;
            }
          }
          if (count>0)
          { cdata[1][j] = median (count,temp);
            cmask[1][j] = 1;
          }
          else
          { cdata[1][j] = 0.;
            cmask[1][j] = 0;
          }
        }
        distance = metric (ncolumns,cdata,cdata,cmask,cmask,weight,0,1,0);
        for (i = 0; i < 2; i++)
        { free (cdata[i]);
          free (cmask[i]);
        }
        free(temp);
        return distance;
      }
      else
      { double distance;
        double* temp = (double*)malloc((size_t)ncolumns*sizeof(double));
        double** cdata = (double**)malloc((size_t)nrows*sizeof(double*));
        int** cmask = (int**)malloc((size_t)nrows*sizeof(int*));
        for (i = 0; i < nrows; i++)
        { cdata[i] = (double*)malloc((size_t)2*sizeof(double));
          cmask[i] = (int*)malloc((size_t)2*sizeof(int));
        }
        for (j = 0; j < nrows; j++)
        { int count = 0;
          for (k = 0; k < n1; k++)
          { i = index1[k];
            if (mask[j][i])
            { temp[count] = data[j][i];
              count++;
            }
          }
          if (count>0)
          { cdata[j][0] = median (count,temp);
            cmask[j][0] = 1;
          }
          else
          { cdata[j][0] = 0.;
            cmask[j][0] = 0;
          }
        }
        for (j = 0; j < nrows; j++)
        { int count = 0;
          for (k = 0; k < n2; k++)
          { i = index2[k];
            if (mask[j][i])
            { temp[count] = data[j][i];
              count++;
            }
          }
          if (count>0)
          { cdata[j][1] = median (count,temp);
            cmask[j][1] = 1;
          }
          else
          { cdata[j][1] = 0.;
            cmask[j][1] = 0;
          }
        }
        distance = metric (nrows,cdata,cdata,cmask,cmask,weight,0,1,1);
        for (i = 0; i < nrows; i++)
        { free (cdata[i]);
          free (cmask[i]);
        }
        free(cdata);
        free(cmask);
        free(temp);
        return distance;
      }
    }
    case 's':
    { int i1, i2, j1, j2;
      const int n = (transpose==0) ? ncolumns : nrows;
      double mindistance = DBL_MAX;
      for (i1 = 0; i1 < n1; i1++)
        for (i2 = 0; i2 < n2; i2++)
        { double distance;
          j1 = index1[i1];
          j2 = index2[i2];
          distance = metric (n,data,data,mask,mask,weight,j1,j2,transpose);
          if (distance < mindistance) mindistance = distance;
        }
      return mindistance;
    }
    case 'x':
    { int i1, i2, j1, j2;
      const int n = (transpose==0) ? ncolumns : nrows;
      double maxdistance = 0;
      for (i1 = 0; i1 < n1; i1++)
        for (i2 = 0; i2 < n2; i2++)
        { double distance;
          j1 = index1[i1];
          j2 = index2[i2];
          distance = metric (n,data,data,mask,mask,weight,j1,j2,transpose);
          if (distance > maxdistance) maxdistance = distance;
        }
      return maxdistance;
    }
    case 'v':
    { int i1, i2, j1, j2;
      const int n = (transpose==0) ? ncolumns : nrows;
      double distance = 0;
      for (i1 = 0; i1 < n1; i1++)
        for (i2 = 0; i2 < n2; i2++)
        { j1 = index1[i1];
          j2 = index2[i2];
          distance += metric (n,data,data,mask,mask,weight,j1,j2,transpose);
        }
      distance /= (n1*n2);
      return distance;
    }
  }
  /* Never get here */
  return 0;
}
