#!/usr/bin/perl -w

use strict;

my $file = shift;

my $total = 4925;
open my $in, '<', $file;
my $line = 0;
for (<$in>) {
    $line++;
    if (/Number of sequences\: (\d+)/) {
	my $seqs = $1;
	my $per = sprintf("%.1f",100*($seqs/$total));
	print qq($line\t$seqs\t$per\n);
    }
}

exit;
