#---------------------------------------------------------------------------

package Algorithm::Cluster;

#---------------------------------------------------------------------------
# Copyright (c) 2003 John Nolan. All rights reserved.
# This program is free software.  You may modify and/or
# distribute it under the same terms as Perl itself.
# This copyright notice must remain attached to the file.
#
# Algorithm::Cluster is a set of Perl wrappers around the
# C Clustering library.
#
#---------------------------------------------------------------------------
# The C clustering library for cDNA microarray data.
# Copyright (C) 2002 Michiel Jan Laurens de Hoon.
#
# This library was written at the Laboratory of DNA Information Analysis,
# Human Genome Center, Institute of Medical Science, University of Tokyo,
# 4-6-1 Shirokanedai, Minato-ku, Tokyo 108-8639, Japan.
# Contact: mdehoon@ims.u-tokyo.ac.jp
# 
# The Algorithm::Cluster module for Perl was released under the same terms
# as the Perl Artistic license. See the file artistic.txt for details.
#---------------------------------------------------------------------------


use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS @EXPORT);
use vars qw( $DEBUG );
use strict;
use DynaLoader;

require Exporter;

$VERSION     = '1.26';
$DEBUG       = 1;
@ISA         = qw(DynaLoader Exporter);

@EXPORT_OK = qw(

	mean 
	median 
	kcluster 
	somcluster 
	treecluster
	clusterdistance 
);

use warnings::register;

bootstrap Algorithm::Cluster $VERSION;


#-------------------------------------------------------------
# Debugging functions
#
sub hello  {

	return _hello();
}

sub readformat  {

	return unless data_is_valid_matrix($_[0]);
	return _readformat($_[0]) ;
}

sub readprint  {

	return unless data_is_valid_matrix($_[0]);
	return _readprint($_[0]) ;
}



#-------------------------------------------------------------
# Wrapper for printing warnings
#
sub module_warn {

	return unless warnings::enabled();
	warnings::warn("Algorithm::Cluster", join '', @_);
}

#-------------------------------------------------------------
# Make sure that the first parameter is a reference-to-array,
# whose first member is itself a reference-to-array, 
# and that that array has at least one member.
#
sub data_is_valid_matrix {

	unless (ref($_[0]) eq 'ARRAY') {
		module_warn( "Wanted array reference, but got a reference to ",
				ref($_[0]), ". Cannot parse matrix");
		return;
	}

	my $nrows = scalar @{ $_[0] };

	unless ($nrows > 0) {
		module_warn("Matrix has zero rows.  Cannot parse matrix");
		return;
	}

	my $firstrow =  $_[0]->[0];

	unless (defined $firstrow) {
		module_warn( "First row in matrix is undef scalar (?).",
				". Cannot parse matrix",);
		return;
	}

	unless (ref($firstrow) eq 'ARRAY') {
		module_warn( "Wanted array reference, but got a reference to ",
				ref($firstrow), ". Cannot parse matrix");
		return;
	}

	my $ncols = scalar @{ $_[0]->[0] };

	unless ($ncols > 0) {
		module_warn("Row has zero columns. Cannot parse matrix");
		return;
	}

	unless (defined($_[0]->[0]->[0])) {
		module_warn("Cell [0,0] is undefined. Cannot parse matrix");
		return;
	}

	return 1;
}



#-------------------------------------------------------------
# Wrapper for the mean() function
#
sub mean  {

	if(ref $_[0] eq 'ARRAY') {
		return _mean($_[0]);
	} else {
		return _mean([@_]) ;
	}
}

#-------------------------------------------------------------
# Wrapper for the median() function
#
sub median  {

	if(ref $_[0] eq 'ARRAY') {
		return _median($_[0]);
	} else {
		return _median([@_]) ;
	}
}


#------------------------------------------------------
# This function is called by the wrappers for library functions.
# It checks the dimensions of the data, mask and weight parameters.
#
# Return false if any errors are found in the data matrix. 
#
# Detect the dimension (nrows x ncols) of the data matrix,
# and set values in the parameter hash. 
#
# Also check the mask matrix and weight arrays, and set
# the parameters to default values if we find any errors, 
# however, we still return true if we find errors.
#
sub check_matrix_dimensions  {

	my ($param, $default) = @_;

	#----------------------------------
	# Check the data matrix
	#
	return unless data_is_valid_matrix($param->{data});

	#----------------------------------
	# Remember the dimensions of the weight array
	#
	$param->{nrows}   = scalar @{ $param->{data}      };
	$param->{ncols}   = scalar @{ $param->{data}->[0] };

	#----------------------------------
	# Check the mask matrix
	#
	unless (data_is_valid_matrix($param->{mask})) {
		module_warn("Parameter 'mask' is not a valid matrix, ignoring it.");
		$param->{mask}      = $default->{mask}     
	} else {

		my $mask_nrows    = scalar @{ $param->{mask}      };
		my $mask_ncols    = scalar @{ $param->{mask}->[0] };

		unless ($param->{nrows} == $mask_nrows and $param->{ncols} == $mask_ncols ) {
			module_warn("Data matrix is $param->{nrows}x$param->{ncols}, but mask matrix" .
				" is ${mask_nrows}x${mask_ncols}.\nIgnoring the mask.");
			$param->{mask}      = $default->{mask}     ;
		}
	}

	#----------------------------------
	# Check the weight array
	#
	unless(ref $param->{weight} eq 'ARRAY') {
			module_warn("Parameter 'weight' does not point to an array, ignoring it.");
			$param->{weight} = $default->{weight};
	} else {
		my $weight_length    = scalar @{ $param->{weight} };
		if ($param->{transpose} eq 0) {
			unless ($param->{ncols} == $weight_length) {
				module_warn("Data matrix has $param->{ncols} columns, but weight " .
					"array has $weight_length items.\nIgnoring the weight array.");
				$param->{weight}      = $default->{weight}     
			}
		}
		else {
			unless ($param->{nrows} == $weight_length) {
				module_warn("Data matrix has $param->{nrows} rows, but weight " .
					"array has $weight_length items.\nIgnoring the weight array.");
				$param->{weight}      = $default->{weight}     
			}
		}
	}

	return 1;
}



#-------------------------------------------------------------
# Wrapper for the kcluster() function
#
sub kcluster  {

	#----------------------------------
	# Define default parameters
	#
	my %default = (

		nclusters =>     3,
		data      =>  [[]],
		mask      =>    '',
		weight    =>    '',
		transpose =>     0,
		npass     =>    10,
		method    =>   'a',
		dist      =>   'e',
	);

	#----------------------------------
	# Accept parameters from caller
	#
	my %param;
	if(ref($_[0]) eq 'HASH') {
		%param = (%default, %{$_[0]});
	} else {
		%param = (%default, @_);
	}


	#----------------------------------
	# Check the data, matrix and weight parameters
	#
	return unless check_matrix_dimensions(\%param, \%default);


	#----------------------------------
	# Check the other parameters
	#
	unless($param{transpose} =~ /^[01]$/) {
		module_warn("Parameter 'transpose' must be either 0 or 1 (got '$param{transpose}')");
		return;
	}

	unless($param{npass}     =~ /^\d+$/ and $param{npass} > 0) {
		module_warn("Parameter 'npass' must be a positive integer (got '$param{npass}')");
		return;
	}

	unless($param{method}    =~ /^[am]$/) {
		module_warn("Parameter 'method' must be either 'a' or 'm' (got '$param{method}')");
		return;
	}

	unless($param{dist}      =~ /^[cauxskehb]$/) {
		module_warn("Parameter 'dist' must be one of: [cauxskehb] (got '$param{dist}')");
		return;
	}


	#----------------------------------
	# Invoke the library function
	#
	return _kcluster( @param{
		qw/nclusters nrows ncols data mask weight transpose npass method dist/
	} );
}

#-------------------------------------------------------------
# treecluster(): Wrapper for the library functions
# pslcluster(), pmlcluster(), palcluster() and pclcluster().
#
sub treecluster  {

	#----------------------------------
	# Define default parameters
	#
	my %default = (

		data       =>  [[]],
		mask       =>    '',
		weight     =>    '',
		applyscale =>     0,
		transpose  =>     0,
		dist       =>   'e',
		method     =>   's',
	);

	#----------------------------------
	# Accept parameters from caller
	#
	my %param;
	if(ref($_[0]) eq 'HASH') {
		%param = (%default, %{$_[0]});
	} else {
		%param = (%default, @_);
	}


	#----------------------------------
	# Check the data, matrix and weight parameters
	#
	return unless check_matrix_dimensions(\%param, \%default);


	#----------------------------------
	# Check the other parameters
	#
	unless($param{applyscale} =~ /^[01]$/) {
		module_warn("Parameter 'applyscale' must be either 0 or 1 (got '$param{applyscale}')");
		return;
	}

	unless($param{transpose} =~ /^[01]$/) {
		module_warn("Parameter 'transpose' must be either 0 or 1 (got '$param{transpose}')");
		return;
	}

	unless($param{method}    =~ /^[smca]$/) {
		module_warn("Parameter 'method' must be one of [smca] (got '$param{method}')");
		return;
	}

	unless($param{dist}      =~ /^[cauxskehb]$/) {
		module_warn("Parameter 'dist' must be one of: [cauxskehb] (got '$param{dist}')");
		return;
	}


	#----------------------------------
	# Invoke the library function
	#
	return _treecluster( @param{
		qw/nrows ncols data mask weight applyscale transpose dist method/
	} );
}



#-------------------------------------------------------------
# Wrapper for the clusterdistance() function
#
sub clusterdistance  {

	#----------------------------------
	# Define default parameters
	#
	my %default = (

		data      =>  [[]],
		mask      =>    '',
		weight    =>    '',
		cluster1  =>    [],
		cluster2  =>    [],
		dist      =>   'e',
		method    =>   'a',
		transpose =>     0,
	);

	#----------------------------------
	# Accept parameters from caller
	#
	my %param;
	if(ref($_[0]) eq 'HASH') {
		%param = (%default, %{$_[0]});
	} else {
		%param = (%default, @_);
	}

	#----------------------------------
	# Check the cluster1 and cluster2 arrays
	#
	if(ref $param{cluster1} ne 'ARRAY') {
		module_warn("Parameter 'cluster1' does not point to an array. Cannot compute distance.");
		return;
	} elsif(@{ $param{cluster1}} <= 0) {
		module_warn("Parameter 'cluster1' points to an empty array. Cannot compute distance.");
		return;
	} elsif (ref $param{cluster2} ne 'ARRAY') {
		module_warn("Parameter 'cluster2' does not point to an array. Cannot compute distance.");
		return;
	} elsif(@{ $param{cluster2}} <= 0) {
		module_warn("Parameter 'cluster2' points to an empty array. Cannot compute distance.");
		return;
	} 
	$param{cluster1_len} = @{ $param{cluster1}};
	$param{cluster2_len} = @{ $param{cluster2}};

	#----------------------------------
	# Check the data, matrix and weight parameters
	#
	return unless check_matrix_dimensions(\%param, \%default);


	#----------------------------------
	# Check the other parameters
	#
	unless($param{transpose} =~ /^[01]$/) {
		module_warn("Parameter 'transpose' must be either 0 or 1 (got '$param{transpose}')");
		return;
	}

	unless($param{method}    =~ /^[am]$/) {
		module_warn("Parameter 'method' must be either 'a' or 'm' (got '$param{method}')");
		return;
	}

	unless($param{dist}      =~ /^[cauxskehb]$/) {
		module_warn("Parameter 'dist' must be one of: [cauxskehb] (got '$param{dist}')");
		return;
	}


	#----------------------------------
	# Invoke the library function
	#
	return _clusterdistance( @param{
		qw/nrows ncols data mask weight cluster1_len cluster2_len 
		cluster1 cluster2 dist method transpose/
	} );
}


#-------------------------------------------------------------
# Wrapper for the somcluster() function
#
sub somcluster  {

	#----------------------------------
	# Define default parameters
	#
	my %default = (

		data      =>  [[]],
		mask      =>    '',
		weight    =>    '',
		transpose =>     0,
		nxgrid    =>    10,
		nygrid    =>    10,
		inittau   =>  0.02,
		niter     =>   100,
		dist      =>   'e',
	);

	#----------------------------------
	# Accept parameters from caller
	#
	my %param;
	if(ref($_[0]) eq 'HASH') {
		%param = (%default, %{$_[0]});
	} else {
		%param = (%default, @_);
	}


	#----------------------------------
	# Check the data, matrix and weight parameters
	#
	return unless check_matrix_dimensions(\%param, \%default);


	#----------------------------------
	# Check the other parameters
	#
	unless($param{transpose} =~ /^[01]$/) {
		module_warn("Parameter 'transpose' must be either 0 or 1 (got '$param{transpose}')");
		return;
	}

	unless($param{nxgrid}     =~ /^\d+$/ and $param{nxgrid} > 0) {
		module_warn("Parameter 'nxgrid' must be a positive integer (got '$param{nxgrid}')");
		return;
	}

	unless($param{nygrid}     =~ /^\d+$/ and $param{nygrid} > 0) {
		module_warn("Parameter 'nygrid' must be a positive integer (got '$param{nygrid}')");
		return;
	}

	unless($param{inittau}     =~ /^\d+.\d+$/ and $param{inittau} >= 0.0) {
		module_warn("Parameter 'inittau' must be a non-negative number (got '$param{inittau}')");
		return;
	}

	unless($param{niter}     =~ /^\d+$/ and $param{niter} > 0) {
		module_warn("Parameter 'niter' must be a positive integer (got '$param{niter}')");
		return;
	}

	unless($param{dist}      =~ /^[cauxskehb]$/) {
		module_warn("Parameter 'dist' must be one of: [cauxskehb] (got '$param{dist}')");
		return;
	}

	#----------------------------------
	# Invoke the library function
	#
	return _somcluster( @param{
		qw/nrows ncols data mask weight transpose nxgrid nygrid inittau niter dist/
	} );
}



1;

__END__


=head1 NAME

Algorithm::Cluster - perl interface to Michiel Jan Laurens de Hoon's
C clustering library


=head1 DESCRIPTION

This module is an interface to the C Clustering Library,
a general purpose library implementing functions for hierarchical 
clustering (pairwise simple, complete, average, and centroid linkage), 
along with k-means and k-medians clustering, and 2D self-organizing 
maps.  The library is distributed along 
with Cluster 3.0, an enhanced version of the famous 
Cluster program originally written by Michael Eisen 
while at Stanford University.  The C clustering library 
was written by Michiel de Hoon.

=head1 EXAMPLES

See the scripts in the examples subdirectory of the package.

=head1 CHANGES

=over 4

=item * Version 0.12

	First version.

=head1 TO DO

=over

=item *  Win32 package

Create a PPM package for Win32 systems.

=head1 THANKS

Thanks to Michiel de Hoon for making the C Clustering library
available, and for his kind assistance with this module.
Thanks also to Michael Eisen, for creating the software packages
Cluster and TreeView. 

=head1 AUTHOR

John Nolan jpnolan@sonic.net 2003.  
A copyright statment is contained in the source code itself. 

This module is a Perl wrapper for the C clustering library for 
cDNA microarray data, Copyright (C) 2002 Michiel Jan Laurens de Hoon.

See the source of Cluster.pm for a full copyright statement. 

=cut

1;
