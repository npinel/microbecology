#!/usr/bin/perl -w

use strict;
use XML::Simple;

my $xml = new XML::Simple;
my $ifile = shift;

my $doc = $xml->XMLin("$ifile");
my %ranks = ('domain' => 0,
	     'phylum' => 1,
	     'class'  => 2,
	     'order'  => 3,
	     'family' => 4,
	     'genus'  => 5);

my %ranksids = ('0' => 'domain',
		'1' => 'phylum',
		'2' => 'class',
		'3' => 'order',
		'4' => 'family',
		'5' => 'genus');

my @species = ('Vibrionaceae','Vibrio','Enterobacteriales','Rhizobiales','Rhizobiales','Rhizobium','Pseudomonas','Clostridium');

my %taxids = ();
my %taxa = ();
for my $key (keys (%{$doc->{'TreeNode'}}) ) {
    my $rank = $doc->{'TreeNode'}->{$key}->{'rank'};

    if (exists $ranks{$rank}) {
	my $id = $doc->{'TreeNode'}->{$key}->{'taxid'};
	$taxa{$key} = {'taxid' => $id,
		       'rank'  => $rank,
		       'rankid'=> $ranks{$rank},
		       'pid'   => $doc->{'TreeNode'}->{$key}->{'parentTaxid'},
		   };
	$taxids{$id} = {'name' => $key,
			'pid'  => $doc->{'TreeNode'}->{$key}->{'parentTaxid'},
		    };
    }
}

my %all = ();
foreach my $org (@species) {
    my %hash = ();

    my $rank = $taxa{$org}{'rank'};
    my $parentid = $taxa{$org}{'pid'};
    my $rankid = $taxa{$org}{'rankid'};
    if ($rankid < 5 ) {
	my $newrankid = $rankid;
	my $newrank = $ranksids{++$newrankid};
	$hash{$newrank} = 'unclassified_'.$org;
    }

    $hash{$rank} = $org;
    for (my $i = $rankid - 1; $i >= 0; $i--) {
	my $taxon = $taxids{$parentid}{'name'};
        $rank = $taxa{$taxon}{'rank'};
	$hash{$rank} = $taxon;
	$parentid = $taxa{$taxon}{'pid'};
    }

    if (exists $hash{'domain'}) {
	my $dom = $hash{'domain'};
	$all{$dom}{'count'} = exists($all{$dom}{'count'}) ? $all{$dom}{'count'} + 1 : 1;
	if (exists $hash{'class'}) {
	    my $cl = $hash{'class'};
	    $all{$dom}{$cl}{'count'} = exists($all{$dom}{$cl}{'count'}) ? $all{$dom}{$cl}{'count'} + 1 : 1;
	    if (exists $hash{'order'}) {
		my $or = $hash{'order'};
		$all{$dom}{$cl}{$or}{'count'} = exists($all{$dom}{$cl}{$or}{'count'}) ? $all{$dom}{$cl}{$or}{'count'} + 1 : 1;
		if (exists $hash{'family'}) {
		    my $fm = $hash{'family'};
		    $all{$dom}{$cl}{$or}{$fm}{'count'} = exists($all{$dom}{$cl}{$or}{$fm}{'count'}) ? $all{$dom}{$cl}{$or}{$fm}{'count'} + 1 : 1;
		    if (exists $hash{'genus'}) {
			my $gn = $hash{'genus'};
			$all{$dom}{$cl}{$or}{$fm}{$gn}{'count'} = exists($all{$dom}{$cl}{$or}{$fm}{$gn}{'count'}) ? $all{$dom}{$cl}{$or}{$fm}{$gn}{'count'} + 1 : 1;
		    }
		}
	    }
	}
    }
}

foreach my $k1 (sort {&sortTaxa} keys %all) {
    print qq($k1 \($all{$k1}{'count'}\)\n);
    foreach my $k2 (sort {&sortTaxa} keys %{$all{$k1}}) {
	unless ($k2 eq 'count') {
	    print qq(  $k2 \($all{$k1}{$k2}{'count'}\)\n);
	    foreach my $k3 (sort {&sortTaxa} keys %{$all{$k1}{$k2}}) {
		unless ($k3 eq 'count') {
		    print qq(    $k3 \($all{$k1}{$k2}{$k3}{'count'}\)\n);
		    foreach my $k4 (sort {&sortTaxa} keys %{$all{$k1}{$k2}{$k3}}) {
			unless ($k4 eq 'count') {
			    print qq(      $k4 \($all{$k1}{$k2}{$k3}{$k4}{'count'}\)\n);
			    foreach my $k5 (sort {&sortTaxa} keys %{$all{$k1}{$k2}{$k3}{$k4}}) {
				unless ($k5 eq 'count') {
				    print qq(        $k5 \($all{$k1}{$k2}{$k3}{$k4}{$k5}{'count'}\)\n);
				}
			    }
			}
		    }
		}
	    }
	}
    }
}

exit;

### subroutines ###
sub sortTaxa {
    if ($a =~ /^unclassified/) {
	return 1;
    } elsif ($b =~ /^unclassified/) {
	return -1;
    } else {
	return $a cmp $b;
    }
}
