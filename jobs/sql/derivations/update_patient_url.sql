update ap
set patient_url = 
CASE
	when patient_url like '%jjd-ci%' then
		concat('https://jjd-ci.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
	when site = 'pleebo' then
		concat('https://pleebo.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
	when site = 'jjd' then
		concat('https://jjdossen.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
END
from all_patients ap ;
