#!/usr/bin/perl -w

use strict;
use XML::Simple;

# this hash is to deal with multiple ranks with identical names
my %ranks = ('domain' => '00domain',
             'phylum' => '01phylum',
             'superclass' => '02superclass',
             'class'  => '03class',
             'subclass'  => '04subclass',
             'order'  => '05order',
             'suborder' => '06suborder',
             'family' => '07family',
             'subfamily' => '08subfamily',
             'supergenus' => '09supergenus',
             'genus'  => '10genus');

## load taxonomy
my $xml = new XML::Simple;
my $doc = $xml->XMLin('bergeyTrainingTree.xml', KeyAttr => 'taxid');

# parse taxonomy, create hash{taxon}=numberedRank
my %taxa = ();
for my $key (keys (%{$doc->{'TreeNode'}}) ) {

    my $rank = $doc->{'TreeNode'}->{$key}->{'rank'};
    next if ($rank eq 'no rank');

    if (exists $ranks{$rank}) {
        my $name = $doc->{'TreeNode'}->{$key}->{'name'};
        push(@{$taxa{$name}}, $ranks{$rank});
    }
}

open my $out1, '>', 'RankedBergeysTaxonomyTraining.txt';
open my $out2, '>', 'MultirankedNames.txt';
foreach my $k (sort keys %taxa) {
    my $print_log = @{$taxa{$k}} > 1 ? 1 : 0;
    @{$taxa{$k}} = sort {$a cmp $b} @{$taxa{$k}};
    my $ranks = '';
    foreach my $r (@{$taxa{$k}}) {
	$r =~ s/^\d{1,2}//;
	$ranks .= $r.',';
    }
    $ranks =~ s/\,$//;
    print $out1 $k."\t".$ranks."\n";
    print $out2 $k."\t".$ranks."\n" if ($print_log == 1);
}
close($out1);
close($out2);

exit;

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
	my $ix = 0;
	for (my $i = 0; $i < @class; $i++) {
	    if ($class[$i]) {
		$class{$ix} = {'taxon' => $class[$i],
			       'prob'  => $class[++$i]}; 
		$ix++;
	    }
	}

	my $class = '';
	foreach my $k (sort keys %class) {
	    $class = $class{$k}{'taxon'} if ($class{$k}{'prob'} >= 0.75);
	}
	
	$assign{$seqid} = $class;
    }
}

for my $k (sort keys %assign) {
    print $k."\t".$assign{$k}."\n";
}

exit;
