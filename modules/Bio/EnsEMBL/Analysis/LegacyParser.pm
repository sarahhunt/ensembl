#
# BioPerl module for Bio::EnsEMBL::Analysis::LegacyParser
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Analysis::LegacyParser - Parses exons/transcripts/genes out of Tim's directory

=head1 SYNOPSIS

    $p = Bio::EnsEMBL::Analysis::LegacyParser->new($gene_file_name,
                                                   $transcript_file_name,$exon_file_name);

    @genes = $p->get_Genes();

=head1 DESCRIPTION

Provides the legacy parsing code for Tim's directories.

=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut

# ~humpub/th/unfinished_ana/unfinished_ana.transcript.lis
# ~humpub/th/unfinished_ana/unfinished_ana.gene.lis
# ~/humpub/blast/confirmed_exon

# Let the code begin...


package Bio::EnsEMBL::Analysis::LegacyParser;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::Object

use Bio::Root::Object;
use Bio::EnsEMBL::Gene;
use Bio::EnsEMBL::Transcript;
use Bio::EnsEMBL::Exon;
use FileHandle;

@ISA = qw(Bio::Root::Object);

# new() is inherited from Bio::Root::Object

# _initialize is where the heavy stuff will happen when new is called

sub _initialize {
  my($self,$genef,$trf,$exonf) = @_;
  
  my $make = $self->SUPER::_initialize;

  if( ! $exonf ) {
      $self->throw("Cannot make Legacy Parser without all 3 files");
  }

  -e $genef || $self->throw("gene file [$genef] does not exist");
  -e $trf   || $self->throw("transcript file [$trf] does not exist");
  -e $exonf || $self->throw("exon file [$exonf] does not exist");

  $self->gene_file($genef);
  $self->trans_file($trf);
  $self->exon_file($exonf);

  $self->{'_trans_hash'} = {};
  $self->{'_gene_hash'} = {};
  $self->{'_exon_hash'} = {};

  # set stuff in self from @args
  return $make; # success - we hope!
}


=head2 get_Genes

 Title   : get_Genes
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub get_Genes{
    my ($self) = @_;

    $self->_parse_gene;
    $self->_parse_trans;
    $self->_parse_exon;
    
    # put them together...
    
    my @genes;

    foreach my $g ( keys %{$self->{'_gene_hash'}} ) {
	my $gene = new Bio::EnsEMBL::Gene;
	push(@genes,$gene);
	$g =~ /HG(\d+)/ || $self->throw("Cannot parse $g as a gene thingy");
	my $gid = "HG" . $1;
	$gene->id($gid);
	
	foreach my $t ( @{$self->{'_gene_hash'}->{$g}} ) {
	    
	    print STDERR "  Doing $t\n";
	    my $trans = new Bio::EnsEMBL::Transcript;
	    
	    $t =~ /HT(\d+)/ || $self->throw("Cannot parse $t as a gene thingy");
	    my $tid = "HT" . $1;
	    $trans->id($tid);
	    
	    $gene->add_Transcript($trans);
	    foreach my $e ( @{$self->{'_trans_hash'}->{$t}} ) {
		if( ! exists $self->{'_exon_hash'}->{$e} ) {
		    $self->warn("No exon of $e!");
		    next;
		}
		
		$trans->add_Exon($self->{'_exon_hash'}->{$e});
	    }
	}
    }
    return @genes;
}


=head2 _dump

 Title   : _dump
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub _dump{
    my ($self,$fh) = @_;
    
    foreach my $g ( keys %{$self->{'_gene_hash'}} ) {
	print $fh "Gene $g\n";
	foreach my $t ( @{$self->{'_gene_hash'}->{$g}} ) {
	    print $fh "  Transcript $t: ";
	    foreach my $e ( @{$self->{'_trans_hash'}->{$t}} ) {
		print "$e,";
	    }
	}
    }
}


=head2 _parse_exon

 Title   : _parse_exon
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub _parse_exon{
    my ($self,$clone) = @_;
    
    $self->warn("Have not calculated phases yet!");
    my $fh = new FileHandle;
    $fh->open($self->exon_file) || $self->throw("Could not open exon file [", $self->exon_file, "]");
    
    my $is = $fh->input_record_separator('>');
    my $dis = <$fh>; # skip first record (dull!)
    while( <$fh> ) {
	if ( /^(\S+)\s(\S+\.\S+):(\d+)-(\d+):(\d+).*(1999-\d\d-\d\d)_[\d:]+\s+(1999-\d\d-\d\d)_[\d:]+.*\n(\S*)/  ) {
	    my $eid = $1;
	    my $contigid = $2;
	    my $start = $3;
	    my $end = $4;
	    my $phase = $5;
	    my $created = $6;
	    my $modified = $7;
	    my $pep = $8;

	    # skip if not from $clone (if defined)
	    next if($clone && $contigid!~/^$clone/);

	    #print STDOUT "Exon $eid - $pep\n";
	    # ok. Get out the Dna sequence object

	    # skipping this for the moment

	    my $exon = Bio::EnsEMBL::Exon->new();
	    $exon->id($eid);
	    $exon->contig_id($contigid);
	    my $cloneid=$contigid;
	    $cloneid=~s/\.\d+$//;
	    $exon->clone_id($cloneid);
	    
	    if( $end < $start ) {
		my $s = $end;
		$end = $start;
		$start = $s;
		$exon->strand(-1);
	    } else {
		$exon->strand(1);
	    }

	    # convert gs-phase to real-phase
	    $phase=&_convert_phase($phase,$start,$end,($exon->strand));

	    $exon->phase($phase);
	    $exon->start($start);
	    $exon->end($end);
	    
	    $exon->created($created);
	    $exon->modified($modified);
	    $self->{'_exon_hash'}->{$eid} = $exon;
	} else {
	    chomp;
	    $self->throw("Yikes. Line with > but not parsed! [$_]");
	}
    }
    $fh->input_record_separator($is);
}


=head2 _convert_phase

 Title   : _convert_phase
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub _convert_phase {
    my ($phase,$start,$end,$strand) = @_;
    if($strand==1){
	$phase=((2+($start%3)-$phase)%3);
    }else{
	$phase=((2+($end%3)-$phase)%3);
    }
    if($phase==2){
	$phase=1;
    }elsif($phase==1){
	$phase=2;
    }
    return $phase;
}


=head2 _parse_trans

 Title   : _parse_trans
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub _parse_trans {
    my ($self) = @_;
    
    my $fh = new FileHandle;
    $fh->open($self->trans_file) || 
	$self->throw("Could not open transcript file [", $self->trans_file, "]");
    while( <$fh> ) {
	my ($trans,$elist) = split;
	if( exists $self->{'_trans_hash'}->{$trans} ) {
	    $self->warn("$trans is already listed in transcript file!");
	}
	$self->{'_trans_hash'}->{$trans} = [];
	my @exons = split(/:/,$elist);
	foreach my $t ( @exons ) {
	    push(@{$self->{'_trans_hash'}->{$trans}},$t);
	}
    }
    $fh->close();
}


=head2 _parse_gene

 Title   : _parse_gene
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :

=cut

sub _parse_gene{
    my ($self) = @_;

    my $fh = new FileHandle;
    $fh->open($self->gene_file) || 
	$self->throw("Could not open gene file [", $self->gene_file, "]");
    while( <$fh> ) {
	my ($gene,$tlist) = split;
	if( exists $self->{'_gene_hash'}->{$gene} ) {
	    $self->warn("$gene is already listed in gene file!");
	}
	$self->{'_gene_hash'}->{$gene} = [];
	my @trans = split(/:/,$tlist);
	foreach my $t ( @trans ) {
	    push(@{$self->{'_gene_hash'}->{$gene}},$t);
	}
    }
    
    $fh->close();
}


=head2 list_exons

 Title   : list_exons
 Usage   : $self->list_exons
 Function: 
 Example : 
 Returns : list of exon objects
 Args    : 


=cut

sub list_exons{
    my($self) = @_;
    return values %{$self->{'_exon_hash'}};
}


=head2 map_all

 Title   : list_exons
 Usage   : $self->map_all(object_hash)
 Function: 
 Example : 
 Returns : adds hashs to object, mapping contig2exon etc
 Args    : 


=cut

sub map_all{
    my($self,$obj,$clone) = @_;
    $self->_parse_exon($clone);
    $self->_parse_trans;
    $self->_parse_gene;

    # contig->exons
    my %contig2exon;
    foreach my $exon (values %{$self->{'_exon_hash'}}){
	my $contig_id=$exon->contig_id;
	# mapping of contig->exon(s)
	push(@{$contig2exon{$contig_id}},$exon);
    }
    # DEBUG
    print STDERR scalar(keys %contig2exon)." contigs have exons\n";
    $obj->{'_contig2exon'}=\%contig2exon;

    # exons->transcripts
    my %exon2transcript;
    my %transcripts;
    my $missed_exons;
    my $n_missed_exons;
    foreach my $t (keys %{$self->{'_trans_hash'}}){
	my $transcript=new Bio::EnsEMBL::Transcript;
	$t =~ /HT(\d+)/ || $self->throw("Cannot parse $t as a gene thingy");
	my $transcript_id = "HT" . $1;
	$transcript->id($transcript_id);
	foreach my $exon_id (@{$self->{'_trans_hash'}->{$transcript_id}}){
	    if(!exists $self->{'_exon_hash'}->{$exon_id} ) {
		$missed_exons.=' '.$exon_id;
		$n_missed_exons++;
		next;
	    }
	    $transcripts{$transcript_id}=$transcript;
	    $transcript->add_Exon($self->{'_exon_hash'}->{$exon_id});
	    push(@{$exon2transcript{$exon_id}},$transcript);
	}
	if(scalar($transcript->each_Exon())){
	    $transcript->sort();
	}
    }
    # report missing exons
    if($n_missed_exons && !$clone){
	$self->warn("$n_missed_exons exons missing: $missed_exons");
    }
    # DEBUG
    print STDERR scalar(keys %exon2transcript)." exons have transcripts\n";
    $obj->{'_exon2transcript'}=\%exon2transcript;
    
    # transcript2gene
    my %transcript2gene;
    foreach my $g (keys %{$self->{'_gene_hash'}}){
	my $gene=new Bio::EnsEMBL::Gene;
	$g =~ /HG(\d+)/ || $self->throw("Cannot parse $g as a gene thingy");
	my $gene_id = "HG" . $1;
	$gene->id($gene_id);
	foreach my $transcript_id (@{$self->{'_gene_hash'}->{$gene_id}}){
	    if(!exists $transcripts{$transcript_id}){
		next;
	    }
	    $gene->add_Transcript($transcripts{$transcript_id});
	    push(@{$transcript2gene{$transcript_id}},$gene);
	}
    }
    # DEBUG
    print STDERR scalar(keys %transcript2gene)." transcripts have genes\n";
    $obj->{'_transcript2gene'}=\%transcript2gene;
}


=head2 gene_file

 Title   : gene_file
 Usage   : $obj->gene_file($newval)
 Function: 
 Example : 
 Returns : value of gene_file
 Args    : newvalue (optional)

=cut

sub gene_file{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'gene_file'} = $value;
    }
    return $self->{'gene_file'};
}


=head2 exon_file

 Title   : exon_file
 Usage   : $self->exon_file($newval)
 Function: 
 Example : 
 Returns : value of exon_file
 Args    : newvalue (optional)

=cut

sub exon_file{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'exon_file'} = $value;
    }
    return $self->{'exon_file'};
}


=head2 trans_file

 Title   : trans_file
 Usage   : $self->trans_file($newval)
 Function: 
 Example : 
 Returns : value of trans_file
 Args    : newvalue (optional)

=cut

sub trans_file{
    my ($self,$value) = @_;
    if( defined $value) {
	$self->{'trans_file'} = $value;
    }
    return $self->{'trans_file'};
}


1;
