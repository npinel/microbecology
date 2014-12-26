#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my ($fetch,$unzip);
my $targetDir = '.';

GetOptions('fetch-only' => \$fetch,
	   'unzip-only' => \$unzip,
	   'target-dir=s' => \$targetDir);

$targetDir .= '/' unless ($targetDir =~ /\/$/);

my @files = 1..22;

for (@files) {

    unless ($unzip) {
	my $file = qq(ftp://ftp.ncbi.nih.gov/genbank/gbenv$_\.seq.gz);
	system("wget -P $targetDir -q $file") == 0
	    || die "error retrieving $file: $!\n";
    }

    unless ($fetch) {
	my $resident = $targetDir.'gbenv'.$_.'.seq.gz';
	$resident =~ /(.+)\.gz$/;
	my $ofile = $1;
	system("gzip -df $resident > $ofile") == 0
	    || die "error decompresing $resident: $!\n";
    }

}

exit;
