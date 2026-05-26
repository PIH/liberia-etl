-- update index asc/desc on all_encounters table
drop table if exists #derived_indexes;
select  encounter_id,
        ROW_NUMBER() over (PARTITION by patient_id, encounter_type_id order by encounter_datetime, encounter_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id, encounter_type_id order by encounter_datetime DESC, encounter_id DESC) as index_desc
into    #derived_indexes
from    all_encounters;

update t
set t.index_asc = i.index_asc,
	t.index_desc = i.index_desc
from all_encounters t inner join #derived_indexes i on i.encounter_id = t.encounter_id
;
