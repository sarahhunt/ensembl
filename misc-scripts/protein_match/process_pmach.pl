use strict;

=head1 Process pmatch

=head1 Description

=head2 Aims
This script aims to run pmatch and postprocess pmatch to map Ensembl peptides to external databases (currently Swissprot and Refseq but may be extented). The first part of the script runs pmatch, the second part gets the percentage of a match of a unique Ensembl peptide which match to an unique external protein. The third part classify each ensembl match as PRIMARY match (the longest one and the one which will be used for the mapping, PSEUDO, DUPLICATE and REPEAT (pretty arbitrary criterias but may be useful for quality control).
NB: All of the intermediary files are written.

=head2 Options
-ens : Ensembl peptide fasta file
-sp : SP, SPTREMBL fasta file
-refseq: Refseq peptide fasta file

=cut  

use Getopt::Long;

my ($ens,$sp,$refseq);

&GetOptions(
            
            'ens:s'=>\$ens,
            'sp:s'=>\$sp,
            'refseq:s'=>\$refseq
            );

&runpmatch();
&postprocesspmatch($sp);
&postprocesspmatch($refseq);
&finalprocess($sp);
&finalprocess($refseq);

sub runpmatch {
    print STDERR "Running pmatch\n";
 
#Run pmatch and store the data in files which will be kept for debugging
    my $pmatch1 = "/nfs/griffin2/rd/bin.ALPHA/pmatch $sp $ens > ens_sp_rawpmatch";
    my $pmatch2 = "/nfs/griffin2/rd/bin.ALPHA/pmatch $refseq $ens > ens_refseq_rawpmatch";
    
    system($pmatch1); # == 0 or die "$0\Error running '$pmatch1' : $!";
    system($pmatch2); #== 0 or die "$0\Error running '$pmatch2' : $!";
}


    
sub postprocesspmatch {
    my ($db) = @_;
    my %hash1;
    
      
#Post process the raw data from pmatch
    if ($db eq $sp) {
	print STDERR "Postprocessing pmatch for SP mapping\n";
	open (OUT, ">ens_sp.processed");
	open (PROC, "ens_sp_rawpmatch");
    }
    
    else {
	print STDERR "Postprocessing pmatch for REFSEQ mapping\n"; 
	open (OUT, ">ens_refseq.processed");
	open (PROC, "ens_refseq_rawpmatch") || die "Can't open file ens_refseq_rawpmatch\n";
    }
    
    while (<PROC>) {
#538     COBP00000033978 1       538     35.3    Q14146  1       538     35.3 
	my ($len,$id,$start,$end,$perc,$query,$qst,$qend,$qperc) = split;

	if ($db eq $refseq) {
	    #Get the refseq ac (NP_\d+) 
	    ($query) = $query =~ /\w+\|\d+\|\w+\|(\w+)/;
	}

	my $uniq = "$id:$query";
	
	$hash1{$uniq} += $perc;
    }



    foreach my $key ( keys %hash1 ) {
	($a,$b) = split(/:/,$key);
	print OUT "$a\t$b\t$hash1{$key}\n";
    }
    close (PROC);
    close (OUT);                               
}

sub finalprocess {
    my ($db) = @_;
    
    if ($db eq $sp) {
	print STDERR "Getting final mapping for SP mapping\n";
	open (PROC, "ens_sp.processed");
	open (OUT, ">ens_sp.final");
    }

    else {
	print STDERR "Getting final mapping for REFSEQ mapping\n";
	open (PROC, "ens_refseq.processed") || die "Can' open file ens_refseq.processed\n";
	open (OUT, ">refseq.final");
    }

    my %hash2;
    while (<PROC>) {
	my ($ens,$known,$perc) = split;
	#if ($perc > 100) {
	 #   print "$ens\t$known\t$perc\n";
	#}
	if( !defined $hash2{$known} ) {
	    $hash2{$known} = [];
	}
	
	my $p= NamePerc->new;
	$p->name($ens);
	$p->perc($perc);
	
	push(@{$hash2{$known}},$p);
    }


    foreach my $know ( keys %hash2 ) {
	my @array = @{$hash2{$know}};
	@array = sort { $b->perc <=> $a->perc } @array;
	
	my $top = shift @array;
	print  OUT "$know\t",$top->name,"\t",$top->perc,"\tPRIMARY\n";
	
	foreach $ens ( @array ) {
	    if( $ens->perc > $top->perc ) {
		die "Not good....";
	    }
	}
	
	if (scalar(@array) >= 20) {
	    foreach my $repeat (@array) {
		print OUT "$know\t",$repeat->name,"\t",$repeat->perc,"\tREPEAT\n";
	    }
	}
	
	if (scalar(@array) < 20) {
	    foreach my $duplicate (@array) {
		if( $duplicate->perc+1 >= $top->perc ) {
		    print OUT "$know\t",$duplicate->name,"\t",$duplicate->perc,"\tDUPLICATE\n";
		}
		else {
		    print OUT "$know\t",$duplicate->name,"\t",$duplicate->perc,"\tPSEUDO\n";
		}
	    } 
	}              
    } 
    close (PROC);
    close (OUT);
}


package NamePerc;


sub new {
    my $class= shift;
    my $self = {};
    bless $self,$class;
    return $self;
}


=head2 name

 Title   : name
 Usage   : $obj->name($newval)
 Function:
 Returns : value of name
 Args    : newvalue (optional)


=cut

sub name{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'name'} = $value;
    }
    return $obj->{'name'};

}

=head2 perc

 Title   : perc
 Usage   : $obj->perc($newval)
 Function:
 Returns : value of perc
 Args    : newvalue (optional)


=cut

sub perc{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'perc'} = $value;
    }
    return $obj->{'perc'};

}                    


