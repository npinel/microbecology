#!/usr/bin/perl -w

=head1 NAME

  parseSeqs.pl - one line description

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR - Nicolás Pinel (January 05, 2013)

=cut

use strict;
use Bio::SeqIO;

my $file = shift;
my $seqin = Bio::SeqIO->new('-file' => $file,
			    '-format' => 'genbank');

while ( my $seqobj = $seqin->next_seq() ) {
    print $seqobj->seq(),"\n";
}

exit;

#### subroutines ###

sub usage {

exit;
}
