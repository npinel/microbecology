#!/usr/bin/perl -w

use strict;
use DBI;
use XML::Simple;

## load the taxonomy
my $xml = new XML::Simple;
my $doc = $xml->XMLin('bergeyTaxonomy.xml', KeyAttr => 'taxid');

my %ranks = ('root'=>0,'domain'=>1,'phylum'=>2,'superclass'=>3,
	     'class'=>4,'subclass'=>5,'order'=>6,'suborder'=>7,
	     'family'=>8,'subfamily'=>9,'supergenus'=>10,'genus'=>11);

my %nodes = ();

for my $key (keys (%{$doc->{'TreeNode'}}) ) {
    my $rank = $doc->{'TreeNode'}->{$key}->{'rank'};
    $rank = 'root' if ($rank eq 'no rank');

    my $name = $doc->{'TreeNode'}->{$key}->{'name'};
    $taxa{$name} = {'name' => $name,
		    'rank'  => $rank,
		    'pid'   => $doc->{'TreeNode'}->{$key}->{'parentTaxid'},
		    'taxid' => $key,
		};
    $taxids{$key} = $name;
}

$searchterms =~ s/\,/\_/g;
open my $out, '>', $searchterms.'.txt';

print $out "\# Distribution by submission\n";
print $out "\# Search terms: $keywords\n\n";

## run the query
my (%glo_nodes,%glo_all_counts,%glo_par_counts);
my (%nodes,%all_counts,%par_counts);
my ($totalsubs,$totalseqs);

my $dbh = DBI->connect('DBI:mysql:microbial_ecology','microecologist','READONLY')
    || die "cannot connect to the Microbial Ecology database: $DBI::errstr\n";

my $sth = $dbh->prepare($sql)
    || die "cannot prepare query: $DBI::errstr\n";
$sth->execute()
    || die "cannot execute query: $DBI::errstr\n";

while (my @data = $sth->fetchrow_array()) {

    my $numseqs = $data[6];
    next unless ($numseqs && $numseqs > 3);
    my $community = $data[7];
    next unless ($community);

    ## stats
    $totalseqs += $numseqs;
    $totalsubs++;

    my $citation = $data[5]."\.\n".$data[3]."\.\n".$data[4].".\nNumber of sequences: $numseqs\n\n";
    print $out $citation;

    my %community = split(/[:,]/,$community);

    # this is %H1, containing all the taxa that act as parent ids during the individual parsing
    # it is a HoH, where the value of the keys of the second set of hashes is used mostly for
    # sorting alphabetically
    %nodes = ();
    # this is %H3, which contains all the taxa names as keys, and their corresponding counts as values
    # this value of counts represents ALL the instances, either as a leaf or an internal node, that the
    # taxon is seen; from this, the number of times accounted for by instances of its daughter taxa is
    # substracted, and the difference is interpreted as 'unclassified' instances of the taxon
    %all_counts = ();
    %par_counts = ();
    foreach my $key (keys %community) {

	$key =~ /(\D+)\.(.+)/;
	my $org = $2;
	my $rank = $1;

	my $counts = $community{$key}; # counts inferred from the stored community structure
	$all_counts{$org} = exists $all_counts{$org} ? $all_counts{$org} + $counts : $counts; # load counts for the organism
	$glo_all_counts{$org} = exists $glo_all_counts{$org} ? $glo_all_counts{$org} + $counts : $counts;

	next if ($org eq 'Root');
	# should be a toggle here for number of submissions with unclassifiable sequences

	my $taxon = $org;
	for (my $i = $ranks{$rank}; $i >= 0; $i--) {
	    my $parent = $taxids{ $taxa{$taxon}{'pid'} };
	    $nodes{$parent}{$taxon} = 1;
	    $glo_nodes{$parent}{$taxon} = 1;
	    # add to both counts
	    $all_counts{$parent} = exists $all_counts{$parent} ? $all_counts{$parent} + $counts : $counts;
	    $par_counts{$parent} = exists $par_counts{$parent} ? $par_counts{$parent} + $counts : $counts;
	    $glo_all_counts{$parent} = exists $glo_all_counts{$parent} ? $glo_all_counts{$parent} + $counts : $counts;
	    $glo_par_counts{$parent} = exists $glo_par_counts{$parent} ? $glo_par_counts{$parent} + $counts : $counts;
	    last if ($parent eq 'Root');
	    $taxon = $parent;
	}
    }	
    # print the community for this publication
#    &dumpTree('Root',$numseqs,\%nodes,\%all_counts,\%par_counts);
#    print "\n";
}

$sth->finish();
$dbh->disconnect();
close($out);

my $glo_out = 'newGlobalCommunities.txt';
open my $glo, '>', $glo_out
    || die "cannot create output file for global report: $!\n";
&dumpTree('Root',$totalseqs,\%glo_nodes,\%glo_all_counts,\%glo_par_counts,$glo);
close($glo);

exit;

### subroutines ###
#sub sortTaxa {
#    if ($a eq 'count') {
#	return 1;
#    } elsif ($b eq 'count') {
#	return -1;
#    } else {
#	return $a cmp $b;
#    }
#}

sub percentCalc {
    my ($num,$total) = @_;
    my $percent = sprintf("%.1f",100*($num/$total));
    return $percent;
}

sub dumpTree {
    my ($n,$seqs,$nod,$all,$par,$fh) = @_;
    
    my $rk = $taxa{$n}{'rank'};
    my $depth = $ranks{$rk};
    my $ac = $$all{$n};
    my $per = &percentCalc($ac,$seqs);
    my $pc = $rk eq 'genus' ? $ac : $$par{$n};
    $pc = $pc || $ac;
    my $diff = $ac - $pc;
    unless ($n eq 'Root') {
	print $fh "$rk\:\t";
	print $fh ' ' x $depth;
	print $fh "$n \($ac\; $per\%\)\n";
    }
    my $tg = 1;
    foreach my $d ( sort keys %{${$nod}{$n}} ) {
	if ($tg) {
	    $depth = $ranks{ $taxa{$d}{'rank'} };
	    undef($tg);
	}
	&dumpTree($d,$seqs,$nod,$all,$par,$fh);
    }
    # now print the 'unclassified' remainder
    if ($diff != 0) {
	$per = &percentCalc($diff,$seqs);
	my $str = $n eq 'Root' ? 'sequence(s)' : $n;
	print $fh "\t";
	print $fh ' ' x $depth;
	print $fh "unclassified $str \($diff\; $per\%\)\n";
    }
}
