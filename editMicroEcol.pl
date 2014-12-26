#!/usr/bin/perl -w

use strict;
use DBI;

my @files = (23, 26..57); ## 24 and 25 contain only Neomasticalles sequences, 
                          ## so they were not classified by the current classifier 
                          ## version, and resulted in empty parsed files

for my $num (@files) {

    my $ifile = 'parsed.gbenv/gbenv'.$num.'.parsed';

    my $debug = 0;
    my %pubs = ();
    my $envtype;
    my $counter = 0;
    open my $log, '>>', 'populate.log';


open my $in, '<', $ifile
    || die "cannot access the input file: $!\n";
for (<$in>) {
    if (/^\*/) {
	$counter++;
	$envtype = '';
	next;
    } else {
	chomp;
	my @set = split(/\t/);
	my $key = $set[0];
	my $val = $set[1];
	next if (!$val || $val eq '');
	$val =~ s/\s$//;
	$val =~ s/\,$//;
	$key = 'pmid' if ($key eq 'pubmed');
	$val = substr($val, 0, 3) if ($key eq 'type');
	$val = '0000' if ($key eq 'year' && $val !~ /\d{4}/);
	$val =~ s/\"/\\\"/g if ($key eq 'title');
	if ($key eq 'authors') {
	    $val =~ s/ and /, /;
	    my @authors = split(/\, /,$val);
	    for my $author (@authors) {
		$author =~ s/\.//g;
		$author =~ s/\,/ /;		
	    }
	    $val = join(', ', @authors);
	}
	if ($key eq 'keywords') {
	    $val =~ s/\'//g;
	    $val =~ s/\,$//;
	}
	$key = 'reference' if ($key eq 'location');
	$key = 'community' if ($key eq 'tally');
	if ($key eq 'sequences') {
	    my @seqs = split(/\,/,$val);
	    my $seqcnt = @seqs;
	    $pubs{$counter}{'numseqs'} = $seqcnt;
	    $key = 'accessions';
	}

	$pubs{$counter}{'envtype'}{'terrestrial'} = 1 if ($val =~ /terrestrial|soil|grass|forest|permafrost/i);
	$pubs{$counter}{'envtype'}{'aquatic'} = 1 if ($val =~ /marine|lake|aquatic|freshwater|sea/i);
	$pubs{$counter}{'envtype'}{'biofilm'} = 1 if ($val =~ /biofilm|microbial mat/i);
	$pubs{$counter}{'envtype'}{'host-associated'} = 1 if ($val =~ /symbio|epibiont/i);
	$pubs{$counter}{'envtype'}{'subsurface'} = 1 if ($val =~ /endolithic/i);
	$pubs{$counter}{'redox'} = 'anaerobic' if ($val =~ /anaerobic|anoxic/i);
	$pubs{$counter}{'status'}{'pristine'} = 1 if ($val =~ /pristine/i);
	$pubs{$counter}{'status'}{'polluted'} = 1 if ($val =~ /polluted|contaminated/i);
	$pubs{$counter}{$key} = $val;
    }
}

my $entries = scalar keys %pubs;


my $admin = 'admin';
my $admin_pass = 'm!crob3';

my $dbh = DBI->connect('DBI:mysql:microbial_ecology',"$admin","$admin_pass")
    || die "cannot connect to the Stahl Lab general database: $DBI::errstr\n";

my ($pubstr,$datstr,$seqstr);
for my $k1 (sort keys %pubs) {
    next unless (exists $pubs{$k1}{'community'});

    ## insert into publications
    $pubstr = 'INSERT INTO publications SET ';
    for my $k2 (sort keys %{$pubs{$k1}}) {
	if ($k2 eq 'pmid' || $k2 eq 'year' || $k2 eq 'title' || $k2 eq 'reference' || $k2 eq 'authors' || $k2 eq 'type' || $k2 eq 'keywords') {
	    $pubstr .= qq($k2\="$pubs{$k1}{$k2}"\,);
	}
    }
    $pubstr .= q(contributor="npinel");

    my $sth = $dbh->prepare($pubstr);
    print $log "$pubstr\n" if ($debug == 1);
    $sth->execute()
	|| die "cannot add the new publication: $DBI::errstr\n";
    $sth->finish();

    ## retrieve the last insert
    my $refId = $dbh->last_insert_id(undef,undef,undef,undef);
    print $refId."\n";
#    my $refId = qq(SELECT LAST_INSERT_ID());
#    $sth = $dbh->prepare($refId);
#    $sth-> execute()
#	|| die "cannot recover the id of the last reference: $DBI::errstr\n";

#    while (my @data = $sth->fetchrow_array()) {
#	$refId = $data[0];
#    }
#    $sth->finish();

    ## insert into datasets
    $datstr = qq(INSERT INTO datasets SET pubindex="$refId",dataset="1");
    $datstr .= qq(\,redox="$pubs{$k1}{'redox'}") if (exists $pubs{$k1}{'redox'});
    if (scalar keys %{$pubs{$k1}{'envtype'}} > 0 ) {
	$datstr .= qq(\,type=\(\');
	for my $k2 (sort keys %{$pubs{$k1}{'envtype'}}) {
	    $datstr .= qq($k2\,);
	}
	$datstr =~ s/\,$//;
	$datstr .= qq(\'\));
    }

    if (scalar keys %{$pubs{$k1}{'status'}} > 0 ) {
	$datstr .= qq(\,status=\(\');
	for my $k2 (sort keys %{$pubs{$k1}{'status'}}) {
	    $datstr .= qq($k2\,);
	}
	$datstr =~ s/\,$//;
	$datstr .= qq(\'\));
    }

    $datstr .= qq(\,community=\'$pubs{$k1}{'community'}\');
    $datstr .= qq(\,numseqs=\"$pubs{$k1}{'numseqs'}\");

    $sth = $dbh->prepare($datstr);
    print $log "$datstr\n" if ($debug == 1);
    $sth->execute()
	|| die "cannot add the new publication: $DBI::errstr\n";

    ## insert into sequences
    $seqstr = qq(INSERT INTO sequences SET pubindex="$refId",dataset="1");
    $seqstr .= qq(\,accessions=\"$pubs{$k1}{'accessions'}\");

    $sth = $dbh->prepare($seqstr);
    print $log "$seqstr\n\n" if ($debug == 1);
    $sth->execute()
	|| die "cannot add the new publication: $DBI::errstr\n";

}

$dbh->disconnect();
close($log);

}

exit;
