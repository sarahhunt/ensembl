

#
# BioPerl module for Bio::EnsEMBL::DBSQL::SimpleFeatureAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::SimpleFeatureAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Simple Feature Adaptor - database access for simple features 

=head1 AUTHOR - Ewan Birney

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::DBSQL::SimpleFeatureAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::SimpleFeature;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Function:
 Returns : 
 Args    :


=cut

sub fetch_by_dbID{
   my ($self,$id) = @_;

   if( !defined $id ) {
       $self->throw("fetch_by_dbID must have an id");
   }

   my $sth = $self->prepare("SELECT s.contig_id, s.contig_start, s.contig_end,
                                    s.contig_strand, s.display_label,
                                    s.analysis_id 
                             FROM simple_feature s 
                             WHERE s.simple_feature_id = $id");
   $sth->execute();

   my ($contig_id,$start,$end,$strand,$display,$analysis_id) = 
     $sth->fetchrow_array();

   if( !defined $contig_id ) {
       $self->throw("No simple feature with id $id");
   }

   my $contig = $self->db->get_RawContigAdaptor->fetch_by_dbID($contig_id); 
   my $ana = $self->db->get_AnalysisAdaptor->fetch_by_dbID($analysis_id);

   unless(defined $ana && $ana->dbID()) {
     $self->warn("No Analysis exists with analysis_id=$analysis_id\n");
     return ();
   }

   my $out = $self->_new_feature($start, $end, $strand, $display, $ana, 
				 $contig->id, $contig->seq);
   
   return $out;
}

=head2 fetch_by_contig_id_constraint

 Title   : fetch_by_contig_id_constraint
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_contig_id_constraint{
   my ($self,$cid, $constraint) = @_;

   if( !defined $cid ) {
       $self->throw("fetch_by_contig_id must have an contig id");
   }

   my $sql = "SELECT s.contig_id, s.contig_start, s.contig_end, 
                     s.contig_strand, s.display_label, s.analysis_id 
              FROM simple_feature s 
              WHERE s.contig_id = $cid";

   if($constraint){
     $sql .= " and $constraint";
   }
   my $sth = $self->prepare($sql);
   $sth->execute();

   my ($contig_id,$start,$end,$strand,$display,$analysis_id);
   $sth->bind_columns(undef, \$contig_id, \$start, \$end, \$strand,
                      \$display,\$analysis_id);

   my @f = ();
   my $contig = $self->db->get_RawContigAdaptor->fetch_by_dbID($cid);
   
   my $analysis_adaptor = $self->db()->get_AnalysisAdaptor();

   while( $sth->fetch ) {
     # caching of analysis objects performed internally by analysis adaptor
     my $analysis = $analysis_adaptor->fetch_by_dbID($analysis_id);

     next unless( defined $analysis && $analysis->dbId() );

     my $out = $self->_new_feature($start, $end, $strand, $display, $analysis,
				   $contig->dbID, $contig);
      
     push(@f,$out);
   }
   
   return @f;
}

sub fetch_by_contig_id{
  my($self, $cid, $logic_name) = @_;
  
  my $constraint;

  if($logic_name){
    my $analysis = 
      $self->db->get_AnalysisAdaptor->fetch_by_logic_name($logic_name);

   unless(defined $analysis && $analysis->dbID()) {
     $self->warn("No Analysis exists with logic_name=$logic_name\n");
     return ();
   }

    $constraint .= " s.analysis_id = ".$analysis->dbID;
  }
  
  my @results = $self->fetch_by_contig_id_constraint($cid, $constraint);
  
  return @results;

}


=head2 fetch_by_assembly_location

 Title   : fetch_by_assembly_location
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_assembly_location_constraint{
   my ($self,$chr_start,$chr_end,$chr,$type, $constraint) = @_;

   if( !defined $type ) {
       $self->throw("Assembly location must be start,end,chr,type");
   }

   if( $chr_start !~ /^\d/ || $chr_end !~ /^\d/ ) {
       $self->throw("start/end must be numbers not $chr_start,$chr_end (have you typed the location in the right way around - start,end,chromosome,type");
   }

   my $mapper = $self->db->get_AssemblyMapperAdaptor->fetch_by_type($type);
   $mapper->register_region($chr, $chr_start,$chr_end);

   my @cids = $mapper->list_contig_ids($chr, $chr_start,$chr_end);
   
   # build the SQL
   my $cid_list = join(',',@cids);
   my $sql = "SELECT s.contig_id, s.contig_start, s.contig_end, 
                     s.contig_strand, s.display_label, s.analysis_id, s.score 
              FROM simple_feature s 
              WHERE s.contig_id IN ($cid_list)";
   if($constraint){
     $sql .= " AND $constraint";
   }
   my $sth = $self->prepare($sql);
   $sth->execute();

   my ($contig_id,$start,$end,$strand,$display,$analysis_id, $score);
   $sth->bind_columns(undef,\$contig_id,\$start,\$end,\$strand,
		      \$display,\$analysis_id, \$score);

   my @f = ();

   my $analysis_adaptor = $self->db()->get_AnalysisAdaptor();

   while( $sth->fetch ) {
     # we whether this is sensible to use or not
     my @coord_list = 
       $mapper->map_coordinates_to_assembly($contig_id, $start,$end,$strand);
       
     # coord list > 1 - means does not cleanly map. At the moment, skip
     if( scalar(@coord_list) > 1 ) {
       next;
     }
       
     #caching handled internally by AnalysisAdaptor
     my $analysis = $analysis_adaptor->fetch_by_dbID($analysis_id);
     next unless(defined $analysis && $analysis->dbID());

     if($coord_list[0]->isa("Bio::EnsEMBL::Mapper::Gap")){
       $self->warn("feature is on a piece of contig not on golden path"
		   . " or in a gap skipping as not needed\n");
       next;
     }

     if(!($coord_list[0]->start >= $chr_start) ||
	!($coord_list[0]->end <= $chr_end)) {
       next;
     }

     my $out = $self->_new_feature($coord_list[0]->start, 
				   $coord_list[0]->end, 
				   $coord_list[0]->strand, 
				   $display, $analysis, 
				   $coord_list[0]->id, undef,
				   $score);
     
       
     push(@f,$out);
   }

   return @f;
}

sub fetch_by_assembly_location{
  my ($self,$chr_start,$chr_end,$chr,$type, $logic_name) = @_;

  my $constraint;
  my $analysis;
  
  if($logic_name){
   my $aa = $self->db->get_AnalysisAdaptor();
   $analysis = $aa->fetch_by_logic_name($logic_name);
   unless(defined $analysis && $analysis->dbID()) {
     $self->warn("No Analysis exists for logic_name=$logic_name");
     return ();
   }
   $constraint .= " s.analysis_id = ".$analysis->dbID(); 
  }
  
  my @results = 
    $self->fetch_by_assembly_location_constraint($chr_start,
						 $chr_end,
						 $chr,
						 $type, 
						 $constraint);


  return @results;
}

sub fetch_by_Slice{
  my($self, $slice, $logic_name) = @_;

  #chain to fetch by Slice and score, but without score defined
  return $self->fetch_by_Slice_and_score($slice, $logic_name, undef);  
}



=head2 fetch_by_Slice_and_score

  Args      : $slice, $logic_name, $score
  Function  : retrieves all SimpleFeatures on a slice of type logic_name 
              and above score
  Returntype: @Bio::EnsEMBL::SimpleFeature
  Exceptions: none
  Caller    : Bio::EnsEMBL::Slice::get_all_SimpleFeatures_above_score
  
=cut

sub fetch_by_Slice_and_score {
  my($self, $slice, $logic_name, $score) = @_;
  
  my $constraint = '';
  my $analysis = undef;
  
  # determine the analysis id constraint if the logic_name is defined
  if($logic_name){
    my $aa = $self->db->get_AnalysisAdaptor();
    $analysis = $aa->fetch_by_logic_name($logic_name);
    unless(defined $analysis && $analysis->dbID()) {
      $self->warn("No Analysis exists for logic_name=$logic_name");
      return ();
    }   
    $constraint .= " s.analysis_id = ".$analysis->dbID(); 
  }

  #add a score constraint if score is defined
  if($score) {
    if($constraint) {
      $constraint .= " AND";
    }
    $constraint .= " s.score > $score";
  }

  # fetch the simple features on this slice, with the above constraints
  my @results = 
    $self->fetch_by_assembly_location_constraint($slice->chr_start,
						 $slice->chr_end,
						 $slice->chr_name,
						 $slice->assembly_type, 
						 $constraint);
  
  #alter the simple feature coordinates by putting them in slice coords
  foreach my $s(@results){
    my $start = ($s->start - ($slice->chr_start - 1));
    my $end = ($s->end - ($slice->chr_start - 1));
    $s->start($start);
    $s->end($end);
  }

  return @results;
}


=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub store{
   my ($self,$contig_id,@sf) = @_;

   if( scalar(@sf) == 0 ) {
       $self->throw("Must call store with contig_id then sequence features");
   }

   if( $contig_id !~ /^\d+$/ ) {
       $self->throw("Contig_id must be a number, not [$contig_id]");
   }

   my $sth = $self->prepare("insert into simple_feature (contig_id,contig_start,contig_end,contig_strand,display_label,analysis_id,score) values (?,?,?,?,?,?,?)");

   foreach my $sf ( @sf ) {
       if( !ref $sf || !$sf->isa("Bio::EnsEMBL::SimpleFeature") ) {
	   $self->throw("Simple feature must be an Ensembl SimpleFeature, not a [$sf]");
       }

       if( !defined $sf->analysis ) {
	   $self->throw("Cannot store sequence features without analysis");
       }
       if( !defined $sf->analysis->dbID ) {
	   # maybe we should throw here. Shouldn't we always have an analysis from the database?
	   $self->throw("I think we should always have an analysis object which has originated from the database. No dbID, not putting in!");
       }

       $sth->execute($contig_id,$sf->start,$sf->end,$sf->strand,$sf->display_label,$sf->analysis->dbID,$sf->score);
   }


}



sub _new_feature{
  my ($self, $start, $end, $strand, $display, $analysis, $seqname, $seq, 
      $score) = @_;

  my $out = Bio::EnsEMBL::SimpleFeature->new();
  $out->start($start);
  $out->end($end);
  $out->strand($strand);
  $out->analysis($analysis);
  $out->display_label($display);
  $out->seqname($seqname);
  if($seq){
    $out->attach_seq($seq); 
  }
  if($score) {
    $out->score($score);
  }

  return $out;
}

1;
