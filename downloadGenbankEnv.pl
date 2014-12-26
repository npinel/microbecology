#!/usr/bin/perl -w

=head1 NAME

  downloadGenbankEnv.pl - one line description

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Nicolás Pinel (December 21, 2012)

=cut

use strict;

my $gb_ftp = 'ftp://ftp.ncbi.nih.gov/genbank';
my $gb_dir = '/var/stahllab/backups/genbank';

my ($release,$release_date) = &getReleaseStats();

print qq(\n>>> The latest Genbank release is: $release\n);
print qq(>>> Release date: $release_date\n);

my ($files_gb,$num_files_gb) = &getGBFileIndex();
my ($files_lc,$num_files_lc) = &getLCFileIndex();


print qq(\n>>> The current release contains $num_files_gb 'env' files.\n);

&compareFileLists();
my $files_to_download = scalar keys %{$files_gb};

if ($files_to_download == 0) {

    print qq(>>> All the files seem to have been downloaded already. Exiting now!\n\n);
    exit;

} else {

    my $plural = $files_to_download > 1 ? 's' : '';
    print qq(>>> Will download the missing $files_to_download file$plural, and save them to:\n\n\t$gb_dir\n\n);
    my $download_count = 0;

    foreach my $gb (sort keys %{$files_gb}) {
	print qq(>>> Starting download of $gb\.\.\.\n\n);
	my $of = $gb_dir.'/'.$gb;
	system("wget -O $of $$files_gb{$gb}");
	++$download_count;
    }
    
    print qq(>>> All downloads have finished.\n\n);
}

exit;

### subroutines ###

sub getReleaseStats {
    my $fetch = qq(wget -q -O - $gb_ftp\/README.genbank | head -n 15);
    my ($rel,$rel_d);
    open my $cmd, '-|', $fetch;
    while (<$cmd>) {
	if (/Release\s+(\d+\.?\d?)/i) { $rel = $1; }
	if (/Release Date:(\s+|\t+)(\w+ \d+\, \d+)/i) { $rel_d = $2; last; }
    }
    $rel = $rel ? $rel : 'not available';
    $rel_d = $rel_d ? $rel_d : 'not available';
    return ($rel,$rel_d);
}

sub getGBFileIndex {
    my $fetch = qq(wget -q -O - $gb_ftp\/ \| grep gbenv);
    open my $cmd, '-|', $fetch;

    my %files_gb = ();
    while (<$cmd>) {
	$_ =~ /\<a href=\"(.+)\"\>(.+)\<\/a\>/;
	$files_gb{$2} = $1;
    }
    return (\%files_gb, scalar keys %files_gb);
}

sub getLCFileIndex {
    my @files_lc = <$gb_dir/gbenv*.seq.gz>;
    my %files_lc = ();
    foreach my $f (@files_lc) {
	chomp(my $file = `basename $f`);
	$files_lc{$file} = 1;
    }
    return (\%files_lc, scalar keys %files_lc);
}

sub compareFileLists {
    foreach my $lc (keys %{$files_lc}) {
	delete ($$files_gb{$lc}) if ($$files_gb{$lc});
    }
}
