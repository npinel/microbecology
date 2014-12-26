#!/usr/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use XML::Simple;

my ($usr,$pwd,$keywords,$help);
GetOptions('u=s' => \$usr,
	   'p=s' => \$pwd,
	   's=s' => \$keywords,
	   'h=s' => \$help);

chomp($keywords);
$keywords =~ s/\,$//;
my $searchterms = $keywords;
my @keys = split(/\,/,$keywords);

my $min_seqs = 50;

my $sql = qq(SELECT p.pmid,p.type,p.year,p.title,p.reference,p.authors,d.numseqs,d.community,d.pubindex FROM publications p INNER JOIN datasets d USING (pubindex) );
#$sql .= qq(WHERE d.numseqs > $min_seqs );

## searching in BOOLEAN MODE
#$sql .= qq(AND MATCH (p.title,p.keywords) AGAINST ('epilimnion lake -sediment* -Actinobacteria* -soil* -hypersaline -Salt -acidic -biofilm* -deep* -meromictic -leech -gull* -trout -Mussel -sewage -Archipelago -Benthic -endoevaporitic -mat -Pontchartrain -Hypolimnion -Mojave -sponge*' IN BOOLEAN MODE) );

$sql .= qq(WHERE d.pubindex in \(\'6423\',\'7157\',\'1858\',\'6479\',\'5966\',\'6200\',\'5418\',\'6482\',\'5352\',\'5665\',\'4112\',\'6065\',\'4946\',\'5423\',\'5742\',\'5792\',\'2099\',\'5881\',\'3296\',\'3328\',\'4225\',\'1083\',\'2725\',\'2081\',\'2443\',\'2356\',\'1430\',\'226\',\'7363\',\'12119\'\) );

## searching with REGEXP
#$sql .= qq(AND \(p.title REGEXP \'\.\*\();
#$sql .= 'epilimnion|lake'.qq(\)\.\*\' OR p.keywords REGEXP \'\.\*\().'epilimnion|lake';
#$sql .= $keywords.qq(\)\.\*\' OR p.keywords REGEXP \'\.\*\().$keywords;
#$sql .= qq(\)\.\*\'\) );
#$sql .= qq(AND p.title NOT REGEXP \'\.\*\(colitis|oral|skin\)\.\*\' );
#$sql .= qq(AND d.status REGEXP '.*polluted.*' );

$sql .= qq(ORDER BY p.year DESC, p.authors);


## load the taxonomy
my $xml = new XML::Simple;
my $doc = $xml->XMLin('bergeyTaxonomy.xml', KeyAttr => 'taxid');

my %ranks = ('root'=>0,'domain'=>1,'phylum'=>2,'superclass'=>3,
	     'class'=>4,'subclass'=>5,'order'=>6,'suborder'=>7,
	     'family'=>8,'subfamily'=>9,'supergenus'=>10,'genus'=>11);

#my %ranksids = reverse %ranks; # turns the id from value into key

my %taxids = ();
my %taxa = ();

for my $key (keys (%{$doc->{'TreeNode'}}) ) {
    my $rank = $doc->{'TreeNode'}->{$key}->{'rank'};
    $rank = 'root' if ($rank eq 'no rank');

    my $name = $doc->{'TreeNode'}->{$key}->{'name'};
    my $unique = $name.'___'.$rank;
    $taxa{$unique} = {'name' => $name,
		      'rank'  => $rank,
		      'pid'   => $doc->{'TreeNode'}->{$key}->{'parentTaxid'},
		      'taxid' => $key,
		  };
    $taxids{$key} = $unique;
}

$searchterms =~ s/\,/\_/g;
open my $loc, '>', 'submissions-'.$searchterms.'.txt';
print $loc '# '.localtime()."\n";
print $loc "\# Distribution by submission\n";
print $loc "\# Search terms: $keywords\n\n";

## run the query
my (%glo_nodes,%glo_all_counts,%glo_par_counts);
my (%nodes,%all_counts,%par_counts);
my ($totalsubs,$totalseqs);

my $dbh = DBI->connect('DBI:mysql:microbial_ecology',$usr,$pwd)
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

    my $citation = $data[5]."\.\n".$data[3]."\.\n".$data[4].".\nNumber of sequences: $numseqs\nDataset ID: $data[8]\n\n";
    print $loc $citation;

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
	my $taxon = $org.'___'.$rank;

	my $counts = $community{$key}; # counts inferred from the stored community structure
	$all_counts{$taxon} = exists $all_counts{$taxon} ? $all_counts{$taxon} + $counts : $counts; # load counts for the organism
	$glo_all_counts{$taxon} = exists $glo_all_counts{$taxon} ? $glo_all_counts{$taxon} + $counts : $counts;

	next if ($org eq 'Root');
	# should be a toggle here for number of submissions with unclassifiable sequences

	for (my $i = $ranks{$rank}; $i >= 0; $i--) {
	    my $parent = $taxids{ $taxa{$taxon}{'pid'} };
	    $nodes{$parent}{$taxon} = 1;
	    $glo_nodes{$parent}{$taxon} = 1;
	    # add to both counts
	    $all_counts{$parent} = exists $all_counts{$parent} ? $all_counts{$parent} + $counts : $counts;
	    $par_counts{$parent} = exists $par_counts{$parent} ? $par_counts{$parent} + $counts : $counts;
	    $glo_all_counts{$parent} = exists $glo_all_counts{$parent} ? $glo_all_counts{$parent} + $counts : $counts;
	    $glo_par_counts{$parent} = exists $glo_par_counts{$parent} ? $glo_par_counts{$parent} + $counts : $counts;
	    last if ($parent eq 'Root___root');
	    $taxon = $parent;
	}
    }	
    # print the community for this publication
    &dumpTree('Root___root',$numseqs,\%nodes,\%all_counts,\%par_counts,$loc);

    print $loc "\n".'***** ***** ***** ***** *****'."\n\n";

}

$sth->finish();
$dbh->disconnect();
close($loc);

my $glo_out = 'global-'.$searchterms.'.txt';
open my $glo, '>', $glo_out
    || die "cannot create output file for global report: $!\n";
print $glo '# '.localtime()."\n";
print $glo "\# Global Distribution\n";
print $glo "\# Search terms\: $keywords\n";
print $glo "\# Total number of submissions: $totalsubs\n";
print $glo "\# Total number of sequences: $totalseqs\n\#\n";
print $glo "\# Query: $sql\n\#\n";
&dumpTree('Root___root',$totalseqs,\%glo_nodes,\%glo_all_counts,\%glo_par_counts,$glo);
print $glo "\n".'***** ***** ***** ***** *****'."\n\n";
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
    $n =~ /(.+)\_{3}\D+/;
    my $n_pr = $1;

    if ($n_pr ne 'Root') {
	print $fh "$rk\:\t";
	print $fh ' ' x $depth;
	print $fh "$n_pr \($ac\; $per\%\)\n";
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
	my $str = $n_pr eq 'Root' ? 'sequence(s)' : $n_pr;
	print $fh "\t";
	print $fh ' ' x $depth;
	print $fh "unclassified $str \($diff\; $per\%\)\n";
    }
}
