delete karyotype from attrib_type, seq_region_attrib, karyotype where attrib_type.code in ('patch_novel','patch_fix') and attrib_type.attrib_type_id = seq_region_attrib.attrib_type_id and seq_region_attrib.seq_region_id = karyotype.seq_region_id;