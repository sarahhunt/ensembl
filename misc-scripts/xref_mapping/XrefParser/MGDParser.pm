package XrefParser::MGDParser;
 
use strict;
use POSIX qw(strftime);
use File::Basename;
 
use XrefParser::BaseParser;
 
use vars qw(@ISA);
@ISA = qw(XrefParser::BaseParser);

my $xref_sth ;
my $dep_sth;
 

 
# --------------------------------------------------------------------------------
# Parse command line and run if being run directly
 
if (!defined(caller())) {
 
  if (scalar(@ARGV) != 1) {
    print "\nUsage: MGDParser.pm file <source_id> <species_id>\n\n";
    exit(1);
  }
 
  run($ARGV[0]);
 
}
 

sub run {
  my $self = shift if (defined(caller(1)));
  my $file = shift;

  my $source_id = shift;
  my $species_id = shift;

  if(!defined($source_id)){
    $source_id = XrefParser::BaseParser->get_source_id_for_filename($file);
  }
  if(!defined($species_id)){
    $species_id = XrefParser::BaseParser->get_species_id_for_filename($file);
  }                                                                                                                      
                                                                                                                      
  my (%swiss) = %{XrefParser::BaseParser->get_valid_codes("uniprot",$species_id)};
  my (%refseq) = %{XrefParser::BaseParser->get_valid_codes("refseq",$species_id)};


  my $count = 0;
  my $mismatch = 0;
  my %mgi_good;

  open(FILE,"<". $file) || die "could not open file $file";
  while(my $line = <FILE>){
    chomp $line;
    my ($key,$label,$desc,$sps) = (split("\t",$line))[0,1,3,6];
    my @sp = split(/\s/,$sps); 
    foreach my $value (@sp){
      if(defined($value) and $value and defined($swiss{$value})){
	XrefParser::BaseParser->add_to_xrefs($swiss{$value},$key,'',$label,$desc,"",$source_id,$species_id);
	$mgi_good{$key} = 1;
	$count++;
      }
      elsif(defined($value) and $value and defined($refseq{$value})){
	$mismatch++;
      }
    }
  }
  close FILE;


  my $dir = dirname($file);
  my $syn_file = $dir."/MRK_Synonym.sql.rpt";

  open(FILE2,"<". $syn_file) || die "could not open file $syn_file";
  my $synonyms=0;

  while(<FILE2>){
    if(/MGI:/){
      chomp ;
      my ($key,$syn) = (split)[0,4];
      if(defined($mgi_good{$key})){
	$self->add_to_syn($key, $source_id, $syn);
	$synonyms++;
      }
    }
  }
  close FILE2;
  print "\t$count xrefs succesfully loaded\n";
  print "\t$synonyms synonyms successfully loaded\n";
  print "\t$mismatch xrefs failed to load\n";
     



}                                                                                                                     

sub new {

  my $self = {};
  bless $self, "XrefParser::MGDParser";
  return $self;

}
 
1;
    
