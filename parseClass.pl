#!/usr/bin/perl -w

use strict;

my %bergeys = ();
open my $bergeys, '<', 'RankedBergeysTaxonomy.txt';

for (<$bergeys>) {
    next if (/^\#/ || /^\n/);
    chomp;
    my @s1 = split(/\t/);
    my @s2 = split(/\,/, $s1[1]);

    foreach my $s2 (@s2) {
	push(@{$bergeys{$s1[0]}}, $s2);
    }

}

open my $in, '<', 'classifierOut.tmp';
my %assign = ();
my %class = ();
my $seqid = '';
while (<$in>) {

    if (/^\>/) {
	/(\w+)\s.*/;
	$seqid = $1;
    } else {
	chomp;
	s/\s$//;
	s/\;$//;
	my @class = split(/; /);
	my %assigned = ();
	my $ix = 0;
	my $assigned = '';
	for (my $i = 0; $i < @class; $i++) {
	    if ($class[$i]) {
		my $taxon = $class[$i];
		my $prob  = $class[++$i];
		unless ($taxon eq 'Root') {
		    $assigned{$taxon} = exists $assigned{$taxon} ? $assigned{$taxon} + 1 : 0;
		    $assigned = ${$bergeys{$taxon}}[$assigned{$taxon}].'.'.$taxon;
		    print $assigned."\t".$prob."\n";
		}
	    }
	}

	$assign{$seqid} = $assigned;
    }
}

print "the final assignment is:\n";
for my $k (sort keys %assign) {
    print $k."\t".$assign{$k}."\n";
}

exit;
