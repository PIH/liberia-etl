-- note that this script APPENDS to the data_warnings table that is created in an extract (LIB-435).
-- ported from zl-etl/jobs/sql/derivations/append_data_warnings.sql (UHM-9020) for Liberia.
-- runs in the warehouse after every site has loaded (refresh-openmrs-data.yml, refresh-ci-warehouse.yml).
-- avoid semicolons inside comments and strings: petl splits this file on the semicolon delimiter
-- encounter types are matched on encounter_type_uuid, not the encounter_type name,
-- so a renamed form doesn't silently drop out. names are kept in comments for readability

-- --------------------------------------------------- remove any previously appended rows
-- each site refresh replaces its own partition of data_warnings, but if a site failed to refresh
-- its old appended rows would still be there, so clear them first to avoid duplicates
delete from data_warnings
where warning_type in (
	'Followup without Intake',
	'Intake after Followup',
	'Duplicate encounters within visit',
	'Duplicate encounters within program',
	'Duplicate emr_ids',
	'return_visit_date not in future');

drop table if exists #temp_data_warnings;
create table #temp_data_warnings
(
data_warning_id    int IDENTITY(1,1) primary key,
warning_type       varchar(255),
event_type         varchar(255),
event_datetime     datetime,
patient_id         varchar(50),
emr_id             varchar(50),
visit_id           varchar(50),
encounter_id       varchar(50),
patient_program_id varchar(50),
encounter_datetime datetime,
datetime_entered   datetime,
visit_date_started datetime,
visit_date_stopped datetime,
user_entered       text,
other_details      text,
site               varchar(100),
partition_num      int
);

-- -------------------------------------------------- intake / followup / delivery encounters by program
-- program_area groups each intake with its followups. group_key is the scope they are compared in:
-- ANC uses the MCH enrollment the encounter falls in (latest enrollment started on or before the
-- encounter and not completed before it), or the patient if there is none. the other areas use the patient
drop table if exists #mch_enrollments;
select patient_program_id, patient_id, date_enrolled, date_completed
into #mch_enrollments
from all_programs
where program_name = 'MCH';

drop table if exists #program_encounters;
select
	case e.encounter_type_uuid
		when 'ae06d311-1866-455b-8a64-126a9bd74171' then 'NCD'             /* NCD Initial Consult */
		when '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c' then 'NCD'             /* NCD Followup Consult */
		when '00e5e810-90ec-11e8-9eb6-529269fb1459' then 'ANC'             /* ANC Intake */
		when '00e5e946-90ec-11e8-9eb6-529269fb1459' then 'ANC'             /* ANC Followup */
		when '00e5ebb2-90ec-11e8-9eb6-529269fb1459' then 'ANC'             /* ANC Delivery */
		when 'fccd53c2-f802-439b-a7a2-2d680bd8b81b' then 'Mental Health'   /* Mental Health Intake */
		when 'a8584ab8-cc2a-11e5-9956-625662870761' then 'Mental Health'   /* Mental Health Followup */
		when '7336a05e-4bd1-4e52-81c1-207697afc868' then 'Epilepsy'        /* Epilepsy Intake */
		when '74e06462-243e-4fad-8d7c-0bb3921322f1' then 'Epilepsy'        /* Epilepsy Followup */
		when '1d1faf4f-a848-44c8-ac44-ada8aa5ae40c' then 'Family Medicine' /* Family Medicine Intake */
		when '84d5e978-66d1-4a2c-b209-95d47c911dd8' then 'Family Medicine' /* Family Medicine Followup */
	end as program_area,
	case
		when e.encounter_type_uuid in ('ae06d311-1866-455b-8a64-126a9bd74171', '00e5e810-90ec-11e8-9eb6-529269fb1459',
			'fccd53c2-f802-439b-a7a2-2d680bd8b81b', '7336a05e-4bd1-4e52-81c1-207697afc868', '1d1faf4f-a848-44c8-ac44-ada8aa5ae40c') then 'intake'
		when e.encounter_type_uuid = '00e5ebb2-90ec-11e8-9eb6-529269fb1459' then 'delivery'
		else 'followup'
	end as role,
	cast(null as varchar(50)) as patient_program_id,
	cast(concat('patient ', e.patient_id) as varchar(100)) as group_key,
	e.encounter_type_uuid, e.encounter_type, e.patient_id, e.emr_id, e.visit_id, e.encounter_id,
	e.encounter_datetime, e.datetime_entered, e.user_entered, e.site, e.partition_num
into #program_encounters
from all_encounters e
where e.encounter_type_uuid in (
	'ae06d311-1866-455b-8a64-126a9bd74171', '5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c',
	'00e5e810-90ec-11e8-9eb6-529269fb1459', '00e5e946-90ec-11e8-9eb6-529269fb1459', '00e5ebb2-90ec-11e8-9eb6-529269fb1459',
	'fccd53c2-f802-439b-a7a2-2d680bd8b81b', 'a8584ab8-cc2a-11e5-9956-625662870761',
	'7336a05e-4bd1-4e52-81c1-207697afc868', '74e06462-243e-4fad-8d7c-0bb3921322f1',
	'1d1faf4f-a848-44c8-ac44-ada8aa5ae40c', '84d5e978-66d1-4a2c-b209-95d47c911dd8');

-- ANC: scope to the MCH enrollment the encounter falls in
update pe
set pe.patient_program_id = m.patient_program_id,
	pe.group_key = concat('program ', m.patient_program_id)
from #program_encounters pe
cross apply
	(select top 1 m1.patient_program_id
	from #mch_enrollments m1
	where m1.patient_id = pe.patient_id
	and m1.date_enrolled <= cast(pe.encounter_datetime as date)
	and (m1.date_completed is null or m1.date_completed >= cast(pe.encounter_datetime as date))
	order by m1.date_enrolled desc, m1.patient_program_id desc) m
where pe.program_area = 'ANC';

-- first followup in each program area and scope, reused by both followup/intake warnings
drop table if exists #first_fu;
select x.*
into #first_fu
from
	(select pe.*,
		row_number() over (partition by pe.program_area, pe.group_key order by pe.encounter_datetime, pe.datetime_entered) as rn
	from #program_encounters pe
	where pe.role = 'followup') x
where x.rn = 1;

-- -------------------------------------------------- followup without intake
-- flags the first followup in each program area and scope when there is no intake at all.
-- if the intake exists but came later, only the 'Intake after Followup' warning is raised
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, site, partition_num)
select 'Followup without Intake', f.encounter_type, f.patient_id, f.emr_id, f.visit_id, f.encounter_id, f.patient_program_id,
f.encounter_datetime, f.datetime_entered, f.user_entered, f.site, f.partition_num
from #first_fu f
where not exists
	(select 1 from #program_encounters i
	where i.program_area = f.program_area
	and i.group_key = f.group_key
	and i.role = 'intake');

-- -------------------------------------------------- intake after followup
-- every intake that has a followup before it in the same program area and scope.
-- other_details shows the earliest followup that came before the intake
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, site, partition_num, other_details)
select 'Intake after Followup', i.encounter_type, i.patient_id, i.emr_id, i.visit_id, i.encounter_id, i.patient_program_id,
i.encounter_datetime, i.datetime_entered, i.user_entered, i.site, i.partition_num,
concat('earlier followup: ', f.encounter_datetime, ' (encounter_id ', f.encounter_id, ')')
from #program_encounters i
inner join #first_fu f on f.program_area = i.program_area
	and f.group_key = i.group_key
	and f.encounter_datetime < i.encounter_datetime
where i.role = 'intake';

-- -------------------------------------------------- duplicate encounters within program
-- more than one intake (or ANC delivery) in the same program area and scope:
-- ANC per MCH enrollment, the others per patient. one row per group, pointing at the latest duplicate
with dup_program as (
	select pe.*,
		count(*) over (partition by pe.program_area, pe.group_key, pe.encounter_type_uuid) as cnt,
		row_number() over (partition by pe.program_area, pe.group_key, pe.encounter_type_uuid
			order by pe.encounter_datetime desc, pe.datetime_entered desc) as rn
	from #program_encounters pe
	where pe.role in ('intake', 'delivery'))
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, patient_program_id,
encounter_datetime, datetime_entered, user_entered, site, partition_num, other_details)
select 'Duplicate encounters within program', d.encounter_type, d.patient_id, d.emr_id, d.visit_id, d.encounter_id, d.patient_program_id,
d.encounter_datetime, d.datetime_entered, d.user_entered, d.site, d.partition_num,
concat('number of encounters: ', d.cnt)
from dup_program d
where d.cnt > 1
and d.rn = 1;

-- -------------------------------------------------- duplicate encounters within visit
-- one row per patient/visit/encounter type, pointing at the latest duplicate
with dup_visit as (
	select e.*,
		count(*) over (partition by e.patient_id, e.visit_id, e.encounter_type_uuid) as cnt,
		row_number() over (partition by e.patient_id, e.visit_id, e.encounter_type_uuid
			order by e.encounter_datetime desc, e.datetime_entered desc) as rn
	from all_encounters e
	where e.visit_id is not null
	and e.encounter_type_uuid in
	('55a0d3ea-a4d7-4e88-8f01-5aceb2d3c61b' /* Check-in */,
	'92fd09b4-5335-4f7e-9f63-b2a663fd09a6' /* Outpatient Consult */,
	'ae06d311-1866-455b-8a64-126a9bd74171' /* NCD Initial Consult */,
	'5cbfd6a2-92d9-4ad0-b526-9d29bfe1d10c' /* NCD Followup Consult */,
	'00e5e810-90ec-11e8-9eb6-529269fb1459' /* ANC Intake */,
	'00e5e946-90ec-11e8-9eb6-529269fb1459' /* ANC Followup */,
	'fccd53c2-f802-439b-a7a2-2d680bd8b81b' /* Mental Health Intake */,
	'a8584ab8-cc2a-11e5-9956-625662870761' /* Mental Health Followup */,
	'7336a05e-4bd1-4e52-81c1-207697afc868' /* Epilepsy Intake */,
	'74e06462-243e-4fad-8d7c-0bb3921322f1' /* Epilepsy Followup */,
	'1d1faf4f-a848-44c8-ac44-ada8aa5ae40c' /* Family Medicine Intake */,
	'84d5e978-66d1-4a2c-b209-95d47c911dd8' /* Family Medicine Followup */))
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, site, partition_num, other_details)
select 'Duplicate encounters within visit', d.encounter_type, d.patient_id, d.emr_id, d.visit_id, d.encounter_id,
d.encounter_datetime, d.datetime_entered, d.user_entered, d.site, d.partition_num,
concat('number of encounters: ', d.cnt)
from dup_visit d
where d.cnt > 1
and d.rn = 1;

-- -------------------------------------------------- duplicate emr_id
-- compared within the same site only (Pleebo and JJD are separate servers).
-- linked to the patient's most recent registration encounter, as in the extract
drop table if exists #latest_reg;
select x.patient_id, x.encounter_id, x.visit_id, x.encounter_datetime
into #latest_reg
from
	(select r1.patient_id, r1.encounter_id, r1.visit_id, r1.encounter_datetime,
		row_number() over (partition by r1.patient_id order by r1.encounter_datetime desc, r1.datetime_entered desc) as rn
	from all_encounters r1
	where r1.encounter_type_uuid = '873f968a-73a8-4f9c-ac78-9f4778b751b6' /* Patient Registration */) x
where x.rn = 1;

insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id, encounter_datetime, datetime_entered,
user_entered, site, partition_num, other_details)
select 'Duplicate emr_ids', 'patient registration', p.patient_id, p.emr_id, r.visit_id, r.encounter_id,
coalesce(r.encounter_datetime, p.registration_date), p.registration_entry_date,
p.user_entered, p.site, p.partition_num, concat('other patient_id: ', p2.patient_id)
from all_patients p
inner join all_patients p2 on p2.emr_id = p.emr_id
	and p2.site = p.site
	and p2.patient_id <> p.patient_id
left join #latest_reg r on r.patient_id = p.patient_id
where p.emr_id is not null;

-- --------------------------------------------------- return_visit_date not in future
-- all_encounters.next_appt_date covers every form that records a next appointment date
insert into #temp_data_warnings (warning_type, event_type, patient_id, emr_id, visit_id, encounter_id,
encounter_datetime, datetime_entered, user_entered, site, partition_num, other_details)
select 'return_visit_date not in future', e.encounter_type, e.patient_id, e.emr_id, e.visit_id, e.encounter_id,
e.encounter_datetime, e.datetime_entered, e.user_entered, e.site, e.partition_num,
concat('next appointment date: ', e.next_appt_date)
from all_encounters e
where e.next_appt_date <= cast(e.encounter_datetime as date);

-- -------------------------------------------------- visit details
update t
set t.visit_date_started = v.visit_date_started,
	t.visit_date_stopped = v.visit_date_stopped
from #temp_data_warnings t
inner join all_visits v on v.visit_id = t.visit_id;

-- -------------------------------------------------- event datetime
update t
set t.event_datetime = coalesce(t.encounter_datetime, t.visit_date_started, t.datetime_entered)
from #temp_data_warnings t;

-- --------------------------------------------------- final insert
insert into data_warnings
	(data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	patient_id,
	emr_id,
	visit_id,
	encounter_id,
	patient_program_id,
	encounter_datetime,
	datetime_entered,
	visit_date_started,
	visit_date_stopped,
	user_entered,
	other_details,
	site,
	partition_num)
select
	(select isnull(max(data_warning_id), 0) from data_warnings) + data_warning_id,
	warning_type,
	event_type,
	event_datetime,
	patient_id,
	emr_id,
	visit_id,
	encounter_id,
	patient_program_id,
	encounter_datetime,
	datetime_entered,
	visit_date_started,
	visit_date_stopped,
	user_entered,
	other_details,
	site,
	partition_num
from #temp_data_warnings;
