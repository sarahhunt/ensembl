# EnsEMBL RawContig object
#
# Copyright EMBL-EBI 2001
#
# cared for by:: Arne Stabenau
# Date : 04.12.2001
#


=head1 NAME

Bio::EnsEMBL::RawContig
  Contig object which represents part of an EMBL Clone.Mostly for 
  database usage

=head1 SYNOPSIS

=head1 CONTACT

  Arne Stabenau: stabenau@ebi.ac.uk
  Ewan Birney  : birney@ebi.ac.uk

=head1 APPENDIX

=cut



package Bio::EnsEMBL::RawContig;

use vars qw( @ISA );
use strict;


use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::PrimarySeqI;

@ISA = qw( Bio::EnsEMBL::Root Bio::PrimarySeqI );

=head2 new

  Arg  1    : int dbID
  Arg  2    : Bio::EnsEMBL::DBSQL::RawContigAdaptor adaptor
  Arg  3    : txt contigName
  Arg  4    : Bio::SeqI sequenceContainer
  Arg  5    : int sequenceLength
  Arg  6    : Bio::EnsEMBL::Clone clone
  Arg  7    : int emblCloneBaseOffset
  Arg  7    : int emblCloneContigNumber
  Arg  8    : int emblCloneBaseOffset
  Function  : creates RawContig. Neds either dbID and Adaptor or clone and sequence.
              With dbID its connected to DB, with the other it may be stored. 
  Returntype: Bio::EnsEMBL::RawContig
  Exceptions: none
  Caller    : RawContigAdaptor, Data upload script

=cut


sub new {
  my ( $class, @args ) = @_;

  my $self = {};
  bless $self, $class;
  
  my ( $dbID, $adaptor, $name, $sequence, $length,
       $clone, $offset ) = @args;

  unless (( defined $dbID && defined $adaptor ) ||
	  ( defined $clone && defined $sequence )) {
      $self->throw("Must have at least dbID and adaptor in new!");
      return undef;
  }

  (defined $dbID) && $self->dbID( $dbID );
  (defined $adaptor) && $self->adaptor( $adaptor );
  (defined $clone) && $self->clone( $clone );
  (defined $sequence) && $self->sequence( $sequence );
  (defined $name) && $self->name( $name );
  (defined $length) && $self->length( $length );
  (defined $offset) && $self->embl_offset( $offset );

  return $self;
}




# things to take over from DBSQL/RawContig ?
# fetch - done in DBSQL/RawContigAdaptor
# get_all_Genes - should be in GeneAdaptor
#    How to handle halve off genes?
# get_old_Genes - dead
# get_all_Exons - ExonAdaptor
#   What happens with halve on/off ?
# get_old_Exons - dead
# get_Genes_by_Type - see get_all_Genes
# has_Genes - Gene or ExonAdaptor ...
# primary_seq - seq should do it now
# db_primary_seq - Assume seq does it ?
# perl_primary_seq - and again
# get_all_SeqFeatures - Call the relevant Adaptors
# get_all_SimilarityFeatures_above_score


# Are this used from Pipeline? Web uses StaticContig
# get_MarkerFeatures
# get_landmark_MarkerFeatures


# get_genscan_peptides - should work via above, so deprecated
# get_all_ExternalFeatures - which adaptors provide them??
# get_all_ExternalGenes - again, we need adaptors for them
# cloneid - dead, use clone->dbID or clone->name,embl_name etc
# old_chromosome - ?? I assume unused and dead
# seq_version - Maybe clone->embl_version ?
# embl_accession - Is there one for our contigs ?
# id - should be name
# internal_id - dbID
# dna_id - hidden in seq
# seq_date - hidden in seq

# static_golden_path functionality 
# All things should lie on an Assembly object.
#  get info out by supplying the contig as parameter





############################
#                          #
#  Attribute section       #
#                          #
############################


sub adaptor {
  my $self = shift;
  my $arg = shift;
  
  ( defined $arg ) &&
    ( $self->{_adaptor} = $arg );

  return $self->{_adaptor};
}


sub dbID {
  my $self = shift;
  my $arg = shift;
  
  ( defined $arg ) &&
    ( $self->{_dbID} = $arg );
  
  return $self->{_dbID};
}

    

sub name {
  my $self = shift;
  my $arg = shift;
  
  if( defined $arg ) {
    $self->{_name} = $arg ;
  } else {
    if( ! defined $self->{_name} &&
      defined $self->adaptor() ) {
      $self->adaptor->fetch_attributes( $self );
    }
  }
  
  return $self->{_name};
}


# scp: RawContig->primary_seq is used by the pipeline/bioperl
# (which expects an object to be returned that implements 'id'.
# As RawContig->primary_seq now returns a RawContig, this
# object needs to implement 'id' also.

sub id {
  my ($self) = shift;

  return $self->name || $self->dbID;
}

sub display_id {
  my $self = shift;
  $self->id();
}



sub embl_offset {
  my $self = shift;
  my $arg = shift;
  
  if( defined $arg ) {
    $self->{_embl_offset} = $arg ;
  } else {
    if( ! defined $self->{_embl_offset} &&
      defined $self->adaptor() ) {
      $self->adaptor->fetch_attributes( $self );
    }
  }
  
  return $self->{_embl_offset};
}

sub clone {
  my $self = shift;
  my $arg = shift;
  
  if( defined $arg ) {
    $self->{_clone} = $arg ;
  } else {
    if( ! defined $self->{_clone} &&
      defined $self->adaptor() ) {
      if( !defined $self->_clone_id() ) {
	$self->adaptor->fetch_attributes($self);
      }
      $self->{_clone} = $self->adaptor->db->get_CloneAdaptor->fetch_by_dbID($self->_clone_id());
    }
  }
  
  return $self->{_clone};
}

sub _clone_id {
  my $self = shift;
  my $arg = shift;
  
  if( defined $arg ) {
    $self->{_clone_id} = $arg ;
  }

  return $self->{_clone_id};
}

sub length {
  my $self = shift;
  my $arg = shift;
  
  if( defined $arg ) {
    $self->{_length} = $arg ;
  } else {
    if( ! defined $self->{_length} &&
      defined $self->adaptor() ) {
      $self->adaptor->fetch_attributes( $self );
    }
  }
  
  return $self->{_length};
}

sub sequence {
    my ($self,$arg) = @_;
 
    return $self->seq($arg);
}

sub seq {
  my $self = shift;

  my $seq = $self->adaptor->db->get_SequenceAdaptor->fetch_by_contig_id_start_end_strand($self->dbID, 1, -1, 1);

  return $seq;
}

sub subseq {
  my ($self, $start, $end, $strand) = @_;

  if ( $end < $start ) {
    $self->throw("End coord is less then start coord to call on RawContig subseq.");
  }

  if ( !defined $strand || ( $strand != -1 && $strand != 1 )) {
    #$self->throw("Incorrect strand information set to call on RawContig subseq.");
    $strand = 1;
  }


  my $sub_seq = $self->adaptor->db->get_SequenceAdaptor->fetch_by_contig_id_start_end_strand($self->dbID, $start, $end, $strand);

  #print STDERR "[RawContig subseq method: Strand: " . $strand . "\t";
  #print STDERR "Start: " . $start . "\tEnd: " . $end . "\tContig dbID: " . $self->dbID . "]\n";
  #print STDERR "Subseq: " . $sub_seq . "\n";

  return $sub_seq;
}


sub seq_old {
  my $self = shift;
  my $arg = shift;

#   print STDERR "Sequence with $arg\n";

  if( defined $arg ) {
    $self->{_seq} = $arg ;
  } else {
    if( ! defined $self->{_seq} &&
      defined $self->adaptor() ) {
	 print STDERR "Fetching sequence\n";
      $self->adaptor->fetch_attributes( $self );
    }
  }
#   print STDERR "Returning...\n";
  return $self->{_seq};
}

sub primary_seq {
  my $self = shift;

  $self->warn("Bio::EnsEMBL::RawContig is now a primary seq object use it directly or use the seq method to return a sequence string\n");

  return $self;
}


=head2 get_repeatmasked_seq

  Args      : none
  Function  : Gives back the in memory repeatmasked seq. Will only work with
              Database connection to get repeat features.
  Returntype: Bio::PrimarySeq
  Exceptions: none
  Caller    : RunnableDB::Genscan::fetch_input(), other Pipeline modules.

=cut


sub get_repeatmasked_seq {
    my ($self) = @_;
    my @repeats = $self->get_all_RepeatFeatures();

    my $dna = $self->seq();
    my $masked_dna = $self->_mask_features($dna, @repeats);
    my $masked_seq = Bio::PrimarySeq->new(   '-seq'        => $masked_dna,
                                             '-display_id' => $self->name,
                                             '-primary_id' => $self->name,
                                             '-moltype' => 'dna',
					     );
    return $masked_seq;
}


=head2 _mask_features

  Arg  1    : txt $dna_string
  Arg  2    : list Bio::EnsEMBL::RepeatFeature @repeats
              list of coordinates to replace with N
  Function  : replaces string positions described im the RepeatFeatures
              with Ns. 
  Returntype: txt
  Exceptions: none
  Caller    : get_repeatmasked_seq

=cut


sub _mask_features {
    my ($self, $dnastr,@repeats) = @_;
    my $dnalen = CORE::length($dnastr);
    
  REP:foreach my $f (@repeats) {
      
      my $start    = $f->start;
      my $end	   = $f->end;
      my $length = ($end - $start) + 1;
      
      if ($start < 0 || $start > $dnalen || $end < 0 || $end > $dnalen) {
	  print STDERR "Eeek! Coordinate mismatch - $start or $end not within $dnalen\n";
	  next REP;
      }
      
      $start--;
      
      my $padstr = 'N' x $length;
      
      substr ($dnastr,$start,$length) = $padstr;
  }
    return $dnastr;
}                                       # mask_features



=head2 get_all_RepeatFeatures

  Args      : none
  Function  : connect to database through set adaptor and retrieve the 
              repeatfeatures for this contig.
  Returntype: list Bio::EnsEMBL::RepeatFeature
  Exceptions: none
  Caller    : general, get_repeatmasked_seq()

=cut

sub get_all_RepeatFeatures {
   my $self = shift;

   if( ! defined $self->adaptor() ) {
     $self->warn( "Need db connection for get_all_RepeatFeatures()" );
     return ();
   }

   my @repeats = $self->adaptor()->db()->get_RepeatFeatureAdaptor()->
     fetch_by_RawContig( $self );
   return @repeats;
}

=head2 get_all_SimilarityFeatures

  Args      : none
  Function  : connect to database through set adaptor and retrieve the 
              SimilarityFeatures for this contig.
  Returntype: list Bio::EnsEMBL::FeaturePair
  Exceptions: none
  Caller    : general

=cut

sub get_all_SimilarityFeatures {
  my ($self, $logic_name) = @_;
  
  if( ! defined $self->adaptor() ) {
    $self->warn( "Need db connection for get_all_SimilarityFeatures()" );
    return ();
  }
  
  my @out;
  my $dafa = $self->adaptor->db->get_DnaAlignFeatureAdaptor();
  my $pafa = $self->adaptor->db->get_ProteinAlignFeatureAdaptor();
      

  my @dnaalign = $dafa->fetch_by_contig_id($self->dbID, $logic_name);
  my @pepalign = $pafa->fetch_by_contig_id($self->dbID, $logic_name);
    
  push(@out, @dnaalign);
  push(@out, @pepalign);

  return @out;
}

=head2 get_all_PredictionFeatures

  Args      : none
  Function  : connect to database through set adaptor and retrieve the 
              PredictionFeatures for this contig.
  Returntype: list Bio::EnsEMBL::PredictionTranscript (previously this returned a SeqFeature)
  Exceptions: none
  Caller    : general

=cut

sub get_all_PredictionFeatures {
  my $self = shift;
  
  if( ! defined $self->adaptor() ) {
    $self->warn( "Need db connection for get_all_PredictionFeatures()" );
    return ();
  }
  
  my $pta = $self->adaptor->db->get_PredictionTranscriptAdaptor();
    
  my @pred_feat = $pta->fetch_by_contig_id($self->dbID);

  return @pred_feat;
}


=head2 get_genscan_peptides

  Args      : none
  Function  : retrieves Prediction Transcripts on this RawContig from
              Database connection.
  Returntype: list Bio::EnsEMBL::PredictionTranscript
  Exceptions: Warning when no database connection
  Caller    : Pipeline RunnableDB::BlastGenscanPep

=cut

=head2 get_genscan_peptides

  Arg [1]    : none
  Example    : none
  Description: DEPRECATED use get_PredictionFeatures instead
  Returntype : none
  Exceptions : none
  Caller     : none

=cut

sub get_genscan_peptides {
  my ($self, @args)  = @_;
  
  $self->warn("Use of deprecated method " .
	      "Bio::EnsEMBL::RawContig::get_genscan_peptides. " .
	      "Use get_PreedictionFeatures instead\n" );

  return $self->get_PredictionFeatures(@args);
}




sub get_all_ExternalFeatures {
   my ($self) = @_;

   $self->warn("RawContig::get_all_ExternalFeatures is not currently implemented and will either be implemented or removed at a later date\n");

#   return ();

#   my @out;
#   my $acc;
   
#   $acc = $self->clone->id();

#   my $offset = $self->embl_offset();

#   foreach my $extf ( $self->dbobj->_each_ExternalFeatureFactory ) {

#     if( $extf->can('get_Ensembl_SeqFeatures_contig') ) {
#       my @tmp = $extf->get_Ensembl_SeqFeatures_contig($self->dbID,
#						       $self->clone->embl_version,
#							   1,
#							   $self->length,
#							   $self->id);
#       push(@out,@tmp);
#     }
#     if( $extf->can('get_Ensembl_SeqFeatures_clone') ) {
#       foreach my $sf ( $extf->get_Ensembl_SeqFeatures_clone(
#         $acc,$self->clone->embl_version,$self->embl_offset, $self->embl_offset+$self->length()) )
#       {
#          my $start = $sf->start - $offset+1;
#          my $end   = $sf->end   - $offset+1;
#          $sf->start($start);
#          $sf->end($end);
#          push(@out,$sf);
#       }
#     }
#   }
#   my $id = $self->id();
#   foreach my $f ( @out ) {
#     $f->seqname($id);
#   }

#   return @out;

}



=head2 dbobj

 Title   : dbobj
 Usage   :
 Function:
 Example :
 Returns : The Bio::EnsEMBL::DBSQL::ObjI object
 Args    :


=cut

sub dbobj {
   my ($self,$arg) = @_;

   $self->throw("RawContig::dbobj() is deprecated");

#   if (defined($arg)) {
#        $self->throw("[$arg] is not a Bio::EnsEMBL::DBSQL::Obj") unless ($arg->isa("Bio::EnsEMBL::DBSQL::Obj") || $arg->isa('Bio::EnsEMBL::DBSQL::DBAdaptor'));
#        $self->{'_dbobj'} = $arg;
#   }
#   return $self->{'_dbobj'};

   return undef;
}

sub accession_number {
  my $self = shift;
  
  $self->dbID();
}

sub moltype {
  return "DNA";
}

sub desc {
  return "Contig, no description";
}



1;
