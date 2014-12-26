#!/usr/bin/perl -w

use strict;
use Bio::SeqIO;

## file numbers
my @files = (24 .. 57);
my $faulty = 0;
my %bergeys = ();
my %namingPatch = ();

for (@files) {
    my $ifile = 'genbank_env/gbenv'.$_.'.seq.gz';
    
    my $str = "starting processing of $ifile on ".localtime()."\n";
    warn("$str");
    
    my $seqin = Bio::SeqIO->new(-file   => "/bin/gunzip -c $ifile |",
				-format => 'GenBank');
    
    my %references = ();
    my $refs = 0;
    open my $out, '>', 'sequences.tmp';
    while ( my $seq_obj = $seqin->next_seq() ) {
	
	my %record = (); # temp hash for storying individual seq information
	# pushed to %references at the end of each iteration
	my $accession = $seq_obj->accession_number;
	my @datesChanged = $seq_obj->get_dates; # use to extract year if unpublished
	$datesChanged[0] =~ /(\d{4})$/;
	my $year = $1;
	my %keywords = (); # derived from fields 'note','isolation source', & 'host'
	# unless the value matches 'unidentified/unclassified'
	
	##
	## get sequence information
	## proceed only if 'product' is 16S ribosomal RNA
	my $nonribosomal = 1;    
	for my $feat_object ($seq_obj->get_SeqFeatures) {
	    for my $tag ($feat_object->get_all_tags) {
		for my $value ($feat_object->get_tag_values($tag)) {
		    if ($tag =~ /isolation_source|note|host/) {
			$keywords{$value} = 1 unless ($value =~ /unidentified|unclassified/i);
		    }
		    $record{$tag} = $value;
		    undef($nonribosomal) if ($nonribosomal && $value eq '16S ribosomal RNA');
		}	    
	    }
	}
	next if ($nonribosomal);
        
	##
	## retrieve referece annotations
	my $annotations = $seq_obj->annotation;
	
	my $index = '';
	for my $key ( $annotations->get_all_annotation_keys ) {
	    
	    my $ref = 0;	
	    my @annotations = $annotations->get_Annotations($key);
	    for my $value ( @annotations ) {
		
		if ($value->tagname eq 'reference') {
		    $ref++;
		    next if ($ref > 1);
		    
		    my $hash_ref = $value->hash_tree;
		    my $type = 'published';
		    my %refHash = ();
		    for my $k2 (keys %{$hash_ref}) {		    
			if ($k2 eq 'authors' || $k2 eq 'location' || $k2 eq 'title' || $k2 eq 'pubmed') {
			    if ($hash_ref->{$k2}) {
				my $val = $hash_ref->{$k2};
				$refHash{$k2} = $val;
				if ($k2 eq 'location') {
				    unless ($val eq 'Unpublished') {
					$val =~ /.+(\((\d{4})\))$/;
					$year = $2;
				    }
				    $type = 'unpublished' if ($val =~ /Unpublished|Published Only/i);
				}
			    }
			}
		    }
		    $refHash{'year'} = $year;
		    $refHash{'type'} = $type;
		    
		    $index = substr($refHash{'authors'},0,25).substr($refHash{'location'},0,50);
		    $index =~ s/\W//g; # cannot use just 'location', since 'Published only in database'
		    # would overwrite records
		    
		    unless (exists $references{$index}) {
			%keywords = (); # vacate keywords hash
			for my $k (keys %refHash) {
			    $references{$index}{$k} = $refHash{$k};
			}
		    } # close unless
		} # close if ('reference')
	    } # close for (@annotations)
	    
	} # close for my $key (get_annotations...)
	
	push(@{$references{$index}{'sequences'}}, \%record);
	for my $k (keys %keywords) {
	    $references{$index}{'keywords'}{$k} = 1;
	}
	
	if ($accession && $accession ne '') {
	    $record{'seqid'} = $accession;
	} elsif ($seq_obj->display_id()) {
	    $record{'seqid'} = $seq_obj->display_id();
	} else {
	    my $faultyid = 'faulty'.++$faulty;
	    warn("a sequence in $index has neither accession nor id; given $faultyid\n");
	}
	
	print $out '>'.$record{'seqid'}."\n";
	print $out $seq_obj->seq()."\n"
	    || warn("$record{'seqid'} did not have a sequence\n");    
    }
    close($out);
    
##
## create sequence bank from all collected sequence
## use bank to create tmp fasta files for classifier input
    $seqin = Bio::SeqIO->new('-file' => 'sequences.tmp',
			     '-format' => 'fasta');
    my %seqBank = ();
    while (my $seq_obj = $seqin->next_seq()) {
	$seqBank{$seq_obj->display_id()} = $seq_obj->seq();
    }
    
    &loadRankedTaxonomy();
    &loadNamingPatch();
    
# my %namingPatchRev = reverse %namingPatch; # not needed on this parsing; will need on the parsing of assembled community data
    
    for my $k (keys %references) {
	open my $tmp, '>', 'classifierIn.tmp'
	    || die "cannot create temporary input for the classifier: $!\n";
	for (my $i = 0; $i < @{$references{$k}{'sequences'}}; $i++) {
	    my $acc = ${$references{$k}{'sequences'}}[$i]{'seqid'};
	    print $tmp qq(\>$acc\n$seqBank{$acc}\n);
	}
	close($tmp);
	
	my $classification = &classify();
	
	$references{$k}{'classification'} = $classification;
    }
    
##
## print output to carrier file
    open $out, '>', $ifile.'.parsed'
	|| die "cannot create final output file: $!\n";
    for my $k1 (sort {$references{$b}{'year'} <=> $references{$a}{'year'}} keys %references) {
	print $out "\*\*\*\n"; # marker to separate publications; for ease of subsequent processing
	
	my %tally = ();
	for my $k2 (sort keys %{$references{$k1}}) {
	    unless ($k2 eq 'sequences' || $k2 eq 'classification' || $k2 eq 'keywords') {
		print $out qq($k2\t$references{$k1}{$k2}\n);
	    }
	}
	print $out "keywords\t";
	for my $k5 (sort keys %{$references{$k1}{'keywords'}}) {
	    print $out "\'".$k5."\'\,";
	}
	print $out "\n";
	print $out "sequences\t";
	for (my $i = 0; $i < @{$references{$k1}{'sequences'}}; $i++) {
	    print $out ${$references{$k1}{'sequences'}}[$i]{'seqid'}.','; # in most cases, the id should be the accession number
	    # but see above for work arounds
	}
	print $out "\n";
	foreach my $k3 (sort keys %{$references{$k1}{'classification'}}) {
	    my $class = $references{$k1}{'classification'}{$k3};
	    $tally{$class} = exists($tally{$class}) ? $tally{$class} + 1 : 1;
	}
	print $out "tally\t";
	foreach my $k4 (sort keys %tally) {
	    print $out $k4.':'.$tally{$k4}.',';
	}
	print $out "\n";
    }
    close($out);
    
    $str = "finished processing $ifile on ".localtime()."\n\n";
    warn("$str");
    
}

exit;

### subroutines ###
#sub sortTaxa {
#    if ($a eq 'sequences') {
#	return 1;
#    } elsif ($b eq 'sequences') {
#	return -1;
#    } else {
#	return $a <=> $b;
#    }
#}

sub loadRankedTaxonomy {
    # no variables passed to this subroutine
    open my $bergeys, '<', 'RankedBergeysTaxonomy.txt'
	|| die "cannot open the Ranked Taxonomy file: $!\n";
    
    for (<$bergeys>) {
	next if (/^\#/ || /^\n/);
	chomp;
	my @s1 = split(/\t/);
	my @s2 = split(/\,/, $s1[1]);
	
	foreach my $s2 (@s2) {
	    push(@{$bergeys{$s1[0]}}, $s2);
	}
	
    }
}

sub loadNamingPatch {
    # no variables passed to this subroutine
    
    open my $patch, '<', 'rdpClassifierNamingPatch'
	|| die "cannot locate the naming patch: $!\n";
    
    for (<$patch>) {
	next if (/^\#/ || /^\n/);
	chomp;
	my @set = split(/\t/);
	$namingPatch{$set[1]} = $set[0];
    }
    
}

sub classify {
    my $command = qq(java -Xmx400m -jar /var/applications/rdp_classifier/rdp_classifier-2.0.jar classifierIn.tmp classifierOut.tmp >& /dev/null);
    system("$command");
    
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
	    my $assigned = '';
	    
	    my $clostridiales = 0;
	    my $bacilliales = 0;
	    for (my $i = 0; $i < @class; $i++) {
		if ($class[$i]) {
		    my $taxon = $class[$i];
		    my $prob = $class[++$i];
		    ## the next two lines should turn off the toggle
		    ## if it has been activated at the order level,
		    ## yet the family is a defined one
		    $clostridiales = 0 if ($taxon !~ /Incertae Sedis/);
		    $bacilliales = 0 if ($taxon !~ /Incertae Sedis/);
		    
		    ## this starts paying attention to whether we'll be dealing
		    ## with the problem childs or not
		    $clostridiales = 1 if ($taxon =~ /Clostridiales/);
		    $bacilliales = 1 if ($taxon =~ /Bacilliales/);
		    
		    unless ($prob < 0.8) {
			$taxon = 'cl.'.$taxon if ($taxon =~ /Incertae Sedis/ && $clostridiales == 1);
			$taxon = 'ba.'.$taxon if ($taxon =~ /Incertae Sedis/ && $bacilliales == 1);
			$taxon = $namingPatch{$taxon} if (exists $namingPatch{$taxon});
			$assigned{$taxon} = exists $assigned{$taxon} ? $assigned{$taxon} + 1 : 0;
			$assigned = ${$bergeys{$taxon}}[$assigned{$taxon}].'.'.$taxon;
#			my $stat = $taxon."\t".$assigned{$taxon}."\t".$assigned."\n";
#			warn("$stat");
		    }
		    
		}
	    }
	    
	    $assign{$seqid} = $assigned;
	}
    }
    close($in);
    
    return \%assign;
}
