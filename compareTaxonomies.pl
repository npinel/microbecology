#!/usr/bin/perl -w

use strict;
use XML::Simple;

my $xml1 = new XML::Simple;
my $bergeyTraining = $xml1->XMLin('bergeyTrainingTree.xml',KeyAttr => 'taxid');

my $xml2 = new XML::Simple;
my $bergeyTaxonomy = $xml2->XMLin('bergeyTaxonomy.xml', KeyAttr => 'taxid');

my %changed = ();
for my $key (keys (%{$bergeyTraining->{'TreeNode'}}) ) {

    if ($bergeyTraining->{'TreeNode'}->{$key}->{'name'} ne $bergeyTaxonomy->{'TreeNode'}->{$key}->{'name'}) {

	$changed{$bergeyTaxonomy->{'TreeNode'}->{$key}->{'name'}} = {'original' => $bergeyTraining->{'TreeNode'}->{$key}->{'name'},
								     'taxid' => $key,
								     'rank' => $bergeyTraining->{'TreeNode'}->{$key}->{'rank'}};
    }
}

open my $out, '>', 'rdp_classifier_namingPatch';
print $out qq(\# custom_name\trdp_name\ttaxid\trank\n);
for my $k (sort keys %changed) {
    print $out $k."\t".$changed{$k}{'original'}."\t".$changed{$k}{'taxid'}."\t".$changed{$k}{'rank'}."\n";
}
close($out);

exit;
