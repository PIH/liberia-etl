-- update index asc/desc on all_encounters table
drop table if exists #derived_indexes;
select  encounter_id,
        ROW_NUMBER() over (PARTITION by patient_id, encounter_type order by encounter_datetime, encounter_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id, encounter_type order by encounter_datetime DESC, encounter_id DESC) as index_desc
into    #derived_indexes
from    all_encounters;

update t
set t.index_asc = i.index_asc,
	t.index_desc = i.index_desc
from all_encounters t inner join #derived_indexes i on i.encounter_id = t.encounter_id
;
-- update patient  index asc/desc on all_diagnoses table
drop table if exists #derived_indexes;
select  obs_id,
        ROW_NUMBER() over (PARTITION by patient_id order by obs_datetime, obs_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id order by obs_datetime DESC, obs_id DESC) as index_desc
into    #derived_indexes
from    all_diagnoses;

update t
set t.index_asc = i.index_asc,
    t.index_desc = i.index_desc
from all_diagnoses t inner join #derived_indexes i on i.obs_id = t.obs_id
;
-- update index asc/desc on all_checkins table
drop table if exists #derived_indexes;
select  encounter_id,
        ROW_NUMBER() over (PARTITION by patient_id order by encounter_datetime, encounter_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id order by encounter_datetime DESC, encounter_id DESC) as index_desc
into    #derived_indexes
from    all_checkins;

update t
set t.index_asc = i.index_asc,
    t.index_desc = i.index_desc
from all_checkins t inner join #derived_indexes i on i.encounter_id = t.encounter_id
;
-- update index asc/desc on all_vitals table
drop table if exists #derived_indexes;
select  encounter_id,
        ROW_NUMBER() over (PARTITION by patient_id order by encounter_datetime, encounter_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id order by encounter_datetime DESC, encounter_id DESC) as index_desc
into    #derived_indexes
from    all_vitals;

update t
set t.index_asc = i.index_asc,
    t.index_desc = i.index_desc
from all_vitals t inner join #derived_indexes i on i.encounter_id = t.encounter_id
;
-- update index asc/desc on all_visits table
drop table if exists #derived_indexes;
select  visit_id,
        ROW_NUMBER() over (PARTITION by patient_id order by visit_date_started, visit_id) as index_asc,
        ROW_NUMBER() over (PARTITION by patient_id order by visit_date_started DESC, visit_id DESC) as index_desc
into    #derived_indexes
from    all_visits;

update t
set t.index_asc = i.index_asc,
    t.index_desc = i.index_desc
from all_visits t inner join #derived_indexes i on i.visit_id = t.visit_id
;
