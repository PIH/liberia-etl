-- ---- All Encounters
set @partition = '${partitionNum}';
SELECT patient_identifier_type_id INTO @identifier_type FROM patient_identifier_type pit WHERE uuid ='1a2acce0-7426-11e5-a837-0800200c9a66';
SELECT patient_identifier_type_id INTO @kgh_identifier_type FROM patient_identifier_type pit WHERE uuid ='c09a1d24-7162-11eb-8aa6-0242ac110002';

set @next_appt_date_concept_id = CONCEPT_FROM_MAPPING('PIH', 5096);
set @disposition_concept_id = concept_from_mapping('PIH','8620');

DROP temporary TABLE IF EXISTS temp_all_encounters;
create temporary table temp_all_encounters(
encounter_id       int,          
patient_id         int,           
visit_id           int,          
emr_id             varchar(50),  
encounter_type     varchar(50),  
encounter_type_id  int,       
provider_id        int(11),
provider           text,  
provider_role_id   int(11),
provider_role      varchar(255),
encounter_datetime datetime,     
location_id        int(11),      
encounter_location varchar(255), 
encounter_year     int,          
encounter_month    int,          
birthdate          date,         
datetime_entered   datetime,     
age_at_encounter   int,      
creator            int(11),
user_entered       varchar(50),  
next_appt_date     date,         
disposition        varchar(255), 
retrospective      boolean,      
entry_lag_hours    int,
new_patient        boolean,
users_modified     text,
dates_modified     text,
index_asc          int,           
index_desc         int           
);

insert into temp_all_encounters(encounter_id,patient_id, visit_id, encounter_type,encounter_type_id, encounter_datetime, location_id,
		encounter_year, encounter_month, datetime_entered, creator)
select e.encounter_id,
	e.patient_id,
	e.visit_id,
	et.name encounter_type,
	e.encounter_type encounter_type_id,
	e.encounter_datetime,
	e.location_id,
	year(e.encounter_datetime) as encounter_year,
	month(e.encounter_datetime) as encounter_month,
	e.date_created,
	e.creator
from encounter e
left outer join encounter_type et on e.encounter_type =et.encounter_type_id 
WHERE e.voided =0;

create index temp_all_encounters_pi on temp_all_encounters(patient_id);
create index temp_all_encounters_ei on temp_all_encounters(encounter_id);

DROP TEMPORARY TABLE IF EXISTS temp_patient;
CREATE TEMPORARY TABLE temp_patient
(
patient_id      int(11),      
wellbody_emr_id varchar(50),  
kgh_emr_id      varchar(50),  
emr_id          varchar(50),
birthdate       date       
);
   
insert into temp_patient(patient_id)
select distinct patient_id from temp_all_encounters;

create index temp_patient_pi on temp_patient(patient_id);

UPDATE temp_patient SET emr_id = patient_identifier(patient_id, metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));

UPDATE temp_patient t 
inner join person p on p.person_id = t.patient_id
set t.birthdate = p.birthdate;

update temp_all_encounters t
inner join temp_patient p on p.patient_id = t.patient_id
set t.emr_id = p.emr_id,
	t.birthdate = p.birthdate;
 	
update temp_all_encounters ae
inner join encounter_provider ep on ep.encounter_id = ae.encounter_id
set ae.provider_id = ep.provider_id;

UPDATE temp_all_encounters ae 
SET ae.provider=provider_name_from_provider_id(ae.provider_id);

UPDATE temp_all_encounters ae
inner join provider p on p.provider_id = ae.provider_id
set ae.provider_role_id = p.provider_role_id;

UPDATE temp_all_encounters ae
set provider_role = provider_role_name(provider_role_id);

UPDATE temp_all_encounters ae
set user_entered = username(creator);

UPDATE temp_all_encounters ae 
SET ae.encounter_location = location_name(ae.location_id);

UPDATE temp_all_encounters ae 
SET age_at_encounter = TIMESTAMPDIFF(YEAR, birthdate, encounter_datetime);

-- get next appointment, disposition
set @disposition_concept_id = concept_from_mapping('PIH','8620');
DROP TEMPORARY TABLE IF EXISTS temp_obs;
CREATE TEMPORARY TABLE temp_obs
select encounter_id, concept_id, value_coded, value_datetime
from obs
where concept_id in (@next_appt_date_concept_id, @disposition_concept_id)
  and voided = 0;

DROP TEMPORARY TABLE IF EXISTS temp_obs_collated;
CREATE TEMPORARY TABLE temp_obs_collated
select encounter_id,
max(case when concept_id = @next_appt_date_concept_id then value_datetime end) "next_appt_date",
max(case when concept_id = @disposition_concept_id then concept_name(value_coded, @locale) end) "disposition"
from temp_obs
group by encounter_id;

create index temp_obs_collated_ei on temp_obs_collated(encounter_id);

UPDATE temp_all_encounters t
inner join temp_obs_collated o on o.encounter_id = t.encounter_id
set t.next_appt_date = o.next_appt_date,
    t.disposition = o.disposition;

UPDATE temp_all_encounters t 
set retrospective = 
  IF(TIME_TO_SEC(datetime_entered) - TIME_TO_SEC(encounter_datetime) > 1800,1,0);

UPDATE temp_all_encounters t 
set entry_lag_hours = TIMESTAMPDIFF(HOUR, encounter_datetime, datetime_entered)
where retrospective = 1;

-- new patient
drop temporary table if exists temp_all_encounters_dup;
create temporary table temp_all_encounters_dup
select encounter_id, patient_id, visit_id, encounter_datetime from temp_all_encounters;

create index temp_all_encounters_dup_c1 on temp_all_encounters_dup(patient_id);

update temp_all_encounters t 
set new_patient = 1 
where t.visit_id is not null 
and not exists 
	(select 1 from temp_all_encounters_dup d 
	where d.patient_id = t.patient_id 
	and (d.visit_id <> t.visit_id or d.visit_id is null) 
	and d.encounter_datetime < t.encounter_datetime);

update temp_all_encounters t 
set new_patient = 1 
where t.visit_id is  null 
and not exists 
	(select 1 from temp_all_encounters_dup d 
	where d.patient_id = t.patient_id 
	and d.encounter_datetime < t.encounter_datetime);


drop temporary table if exists temp_other_modifiers;
create temporary table temp_other_modifiers
select o.encounter_id, GROUP_CONCAT(distinct username(o.creator) separator ', ') "other_modifiers", GROUP_CONCAT(distinct date(date_created) separator ', ') "dates_modified" 
from obs o 
inner join temp_all_encounters t where t.encounter_id = o.encounter_id  and o.creator <> t.creator
group by encounter_id;

update temp_all_encounters t
inner join temp_other_modifiers m on m.encounter_id = t.encounter_id 
set t.users_modified = m.other_modifiers,
	t.dates_modified = m.dates_modified;

select 
concat(@partition,"-",encounter_id) as encounter_id,
concat(@partition,"-",patient_id)  as patient_id,
concat(@partition,"-",visit_id)  as visit_id,
emr_id,
encounter_type,
encounter_location,
provider,
provider_role,
encounter_datetime,
datetime_entered,
user_entered,
users_modified,
dates_modified,
age_at_encounter,
disposition,
next_appt_date,
retrospective,
entry_lag_hours,
new_patient,
index_asc,
index_desc
from temp_all_encounters;
