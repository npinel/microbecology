#!/usr/bin/perl -w

use strict;

my $ifile = shift;

my %counts = ();

open my $in, '<', $ifile;
for (<$in>) {
    next if (/^\*/);
    chomp;
    my @set = split(/\t/);
    if ($set[0] eq 'sequences') {
	my $length = length($set[1]);
	push(@{$counts{$set[0]}}, $length);
    }
}
close($in);

foreach my $k (keys %counts) {
    @{$counts{$k}} = sort {$a <=> $b} @{$counts{$k}};
}

foreach my $k (sort keys %counts) {
    print $k."\n";
    for (@{$counts{$k}}) {
	print $_."\n";
    }
    print "\n";
} 

exit;
