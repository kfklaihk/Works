SET SERVEROUT ON SIZE 1000000;
/*
21/02/2024	Paul Pang		Change from cursor to insert statement
20/04/2024  Paul Pang		Update RECEIVE_PAPER_FLAG logic for employer
12/06/2024	George Ngai		change sys_guid to generate_guid
03/07/2024	Winnie Lau		move AP to hst table
28/11/2024  Glenn Yi        handle duplicaed client_uuid,system_client_type
17/02/2025	Winnie Lau		WL-170225 for MT, keep AP in cmn_client_contact_person
02/07/2025  Justin Leung    JL-250702 Remove migration for correlated person's communication preference. Fix inconsistency between av_notify_medium_type and receive_paper_flag for member, SEP and employer
*/
DECLARE
v_update_by         VARCHAR2(50):= '&&1 TR2 UAT 07/12/2023';
V_SCHEME_CYCLE_DATE DATE;
V_SCHEME_UUID       RAW(16);

--CURSOR id_cur IS
/* SELECT  DISTINCT client_uuid, system_client_type, consent_to_direct_marketing, av_pref_lang_code, av_notify_medium_code, receive_paper_flag, trustee_entty_cd
FROM    (
SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
        (CASE
            WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
            ELSE m.LNGG_TYPE_ID
        END) AV_PREF_LANG_CODE
        ,(CASE MBR_COMMUNICATION_TYPE 
            WHEN 'SM' THEN 'SMS'		-- don't change this comment
            WHEN 'EM' THEN 'EMAIL'
            ELSE 'PAPER'
        END) AV_NOTIFY_MEDIUM_CODE
        ,(CASE
            WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS IS NULL THEN 'Y'
			WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'Y' THEN 'N'
			WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'N' THEN 'Y'					
            ELSE m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS
        END) RECEIVE_PAPER_FLAG
        ,m.trustee_mbr_id AS trustee_entty_cd
FROM    DM_MEMBER m
        INNER JOIN enr_mem_acct ma
        ON  ma.orig_tr_mem_no = m.trustee_mbr_id
        AND ma.scheme_code = m.scheme_code
        INNER JOIN cmn_client c
        ON  c.id = ma.id        
WHERE   ma.scheme_code = '&&1'

UNION ALL

SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
        (CASE
            WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
            ELSE m.LNGG_TYPE_ID
        END) AV_PREF_LANG_CODE
        ,(CASE SEP_COMMUNICATION_TYPE 
            WHEN 'SM' THEN 'SMS'		-- don't change this comment
            WHEN 'EM' THEN 'EMAIL'
            ELSE 'PAPER'
        END) AV_NOTIFY_MEDIUM_CODE
        ,(CASE
            WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS IS NULL THEN 'Y'
			WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'Y' THEN 'N'
			WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'N' THEN 'Y'					
            ELSE m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS
        END) RECEIVE_PAPER_FLAG
        ,m.trustee_sep_cd
FROM    DM_SEP m
        INNER JOIN enr_mem_acct ma
        ON  ma.orig_tr_mem_no = m.trustee_sep_cd
        AND ma.scheme_code = m.scheme_code
        INNER JOIN cmn_client c
        ON  c.id = ma.id        
WHERE   ma.scheme_code = '&&1'

UNION ALL

SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
        (CASE
            WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
            ELSE m.LNGG_TYPE_ID
        END) AV_PREF_LANG_CODE
        ,(CASE EMPLR_COMMUNICATION_TYPE 
            WHEN 'SM' THEN 'SMS'		-- don't change this comment
            WHEN 'EM' THEN 'EMAIL'
            ELSE 'PAPER'
        END) AV_NOTIFY_MEDIUM_CODE
        ,'N' RECEIVE_PAPER_FLAG
        ,m.trustee_emplr_cd
FROM    DM_EMPLOYER m
        INNER JOIN enr_er_acct ma
        ON  ma.tr_employer_code = m.trustee_emplr_cd
        AND ma.scheme_code = m.scheme_code
        INNER JOIN cmn_client c
        ON  c.id = ma.id        
WHERE   ma.scheme_code = '&&1'

UNION ALL

SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
        (CASE
            WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
            ELSE m.LNGG_TYPE_ID
        END) AV_PREF_LANG_CODE
        ,(CASE MBR_COMMUNICATION_TYPE 
            WHEN 'SM' THEN 'SMS'		-- don't change this comment
            WHEN 'EM' THEN 'EMAIL'
            ELSE 'PAPER'
        END) AV_NOTIFY_MEDIUM_CODE
        ,'N' RECEIVE_PAPER_FLAG
        ,m.trustee_entty_cd
FROM    DM_CORRELATED_PERSON m
        INNER JOIN cmn_client_contact_person cp
        ON  cp.remark = m.RELATED_PERSON_ID
        AND cp.scheme_code = m.scheme_code
        INNER JOIN cmn_client c
        ON  c.id = cp.id        
WHERE   cp.scheme_code = '&&1'
) cp
WHERE     NOT EXISTS (  SELECT *
                        FROM    CMN_CLIENT_COMM_PREF cp2
                        WHERE   cp2.client_uuid = cp.client_uuid)
--AND      cp.TRUSTEE_ENTTY_CD LIKE '%0000043366000001%'
ORDER BY 1; */

--id id_cur%ROWTYPE;

BEGIN
--    DELETE CMN_CLIENT_COMM_PREF WHERE SCHEME_CODE = '&&1';
    BEGIN
        SELECT sc.cycle_date, s.id
        INTO    v_scheme_cycle_date, v_scheme_uuid
        FROM    cmn_scheme_cycle sc
                INNER JOIN cmn_scheme s
                ON  s.id = sc.tr_scheme_uuid
        WHERE   s.scheme_code = '&&1'
        AND     sc.cycle_date_step_code = '2';
    END;
    
 --   FOR id IN id_cur LOOP
--        
--        IF v_pre_term_ref_no = id.term_ref_no THEN
--            v_seq_no := v_seq_no + 1;
--            v_term_ref_no := id.term_ref_no || '-' || TO_CHAR(v_seq_no);
--        ELSE
--            v_seq_no := 1;
--            v_pre_term_ref_no := id.term_ref_no;
--            v_term_ref_no := id.term_ref_no;
--        END IF;
--        
--        dbms_output.put_line('id.trustee_entty_cd ' || id.trustee_entty_cd); 
--        dbms_output.put_line('id.client_uuid ' || id.client_uuid); 
--        dbms_output.put_line('id.system_client_type ' || id.system_client_type); 
--
        INSERT INTO CMN_CLIENT_COMM_PREF
        (ID, CLIENT_UUID, AV_CLIENT_TYPE, DIRECT_MARKET_FLAG, DIRECT_MARKET_FLAG_EFF_DATE
        ,AV_PREF_LANG_CODE, PREF_LANG_EFF_DATE, AV_NOTIFY_MEDIUM_CODE, NOTIFY_MEDIUM_EFF_DATE, RECEIVE_PAPER_FLAG
        ,RECEIVE_PAPER_FLAG_EFF_DATE, ARCHIVE_FLAG, SCHEME_CODE
        ,CREATED_BY, CREATION_DATE, LAST_UPDATED_BY, LAST_UPDATE_DATE
        )
        -- VALUES
        -- (generate_guid('&&1'), id.client_uuid, id.system_client_type, id.CONSENT_TO_DIRECT_MARKETING, v_scheme_cycle_date
        -- ,id.AV_PREF_LANG_CODE, v_scheme_cycle_date, id.AV_NOTIFY_MEDIUM_CODE, v_scheme_cycle_date, id.RECEIVE_PAPER_FLAG
        -- ,v_scheme_cycle_date, 'N', '&&1'
        -- ,v_update_by, SYSDATE, v_update_by, SYSDATE);
		SELECT generate_guid('&&1'), id.client_uuid, id.system_client_type, id.CONSENT_TO_DIRECT_MARKETING, v_scheme_cycle_date
        ,id.AV_PREF_LANG_CODE, v_scheme_cycle_date, id.AV_NOTIFY_MEDIUM_CODE, v_scheme_cycle_date, id.RECEIVE_PAPER_FLAG
        ,v_scheme_cycle_date, 'N', '&&1'
        ,v_update_by, SYSDATE, v_update_by, SYSDATE
		FROM
		(
		SELECT  DISTINCT client_uuid, system_client_type, consent_to_direct_marketing, av_pref_lang_code, av_notify_medium_code, receive_paper_flag, trustee_entty_cd
		FROM    (
				SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
						(CASE
							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
							ELSE m.LNGG_TYPE_ID
						END) AV_PREF_LANG_CODE
						,(CASE MBR_COMMUNICATION_TYPE 
							WHEN 'SM' THEN 'SMS'		-- don't change this comment
							WHEN 'EM' THEN 'EMAIL'
							ELSE 'PAPER'
						END) AV_NOTIFY_MEDIUM_CODE
						,(CASE
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS IS NULL THEN 'Y'
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'Y' THEN 'N'
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'N' THEN 'Y'					
							ELSE m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS
						END) RECEIVE_PAPER_FLAG
						,m.trustee_mbr_id AS trustee_entty_cd
				FROM    DM_MEMBER m
						INNER JOIN enr_mem_acct ma
						ON  ma.orig_tr_mem_no = m.trustee_mbr_id
						AND ma.scheme_code = m.scheme_code
						INNER JOIN cmn_client c
						ON  c.id = ma.id        
				WHERE   ma.scheme_code = '&&1'

				UNION ALL

				SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
						(CASE
							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
							ELSE m.LNGG_TYPE_ID
						END) AV_PREF_LANG_CODE
						,(CASE SEP_COMMUNICATION_TYPE 
							WHEN 'SM' THEN 'SMS'		-- don't change this comment
							WHEN 'EM' THEN 'EMAIL'
							ELSE 'PAPER'
						END) AV_NOTIFY_MEDIUM_CODE
						,(CASE
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS IS NULL THEN 'Y'
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'Y' THEN 'N'
							WHEN m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS = 'N' THEN 'Y'					
							ELSE m.CONSENT_TO_ENTFCN_OF_REGULATORY_DOCS
						END) RECEIVE_PAPER_FLAG
						,m.trustee_sep_cd
				FROM    DM_SEP m
						INNER JOIN enr_mem_acct ma
						ON  ma.orig_tr_mem_no = m.trustee_sep_cd
						AND ma.scheme_code = m.scheme_code
						INNER JOIN cmn_client c
						ON  c.id = ma.id        
				WHERE   ma.scheme_code = '&&1'

				UNION ALL

				SELECT  ma.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
						(CASE
							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
							ELSE m.LNGG_TYPE_ID
						END) AV_PREF_LANG_CODE
						,(CASE EMPLR_COMMUNICATION_TYPE 
							WHEN 'SM' THEN 'SMS'		-- don't change this comment
							WHEN 'EM' THEN 'EMAIL'
							ELSE 'PAPER'
						END) AV_NOTIFY_MEDIUM_CODE
						-- JL-250702 begin
						-- ,(CASE NVL(EMPLR_COMMUNICATION_TYPE, 'N/A') WHEN 'PP' THEN 'Y' ELSE 'N' END) RECEIVE_PAPER_FLAG
						,(CASE WHEN NVL(EMPLR_COMMUNICATION_TYPE, 'N/A') IN ('SM','EM') THEN 'N' ELSE 'Y' END) RECEIVE_PAPER_FLAG
						-- JL-250702 end
						,m.trustee_emplr_cd
				FROM    DM_EMPLOYER m
						INNER JOIN enr_er_acct ma
						ON  ma.tr_employer_code = m.trustee_emplr_cd
						AND ma.scheme_code = m.scheme_code
						INNER JOIN cmn_client c
						ON  c.id = ma.id        
				WHERE   ma.scheme_code = '&&1'
-- JL-250702 begin
-- 				UNION ALL
-- GY 281124 begin
					
--					SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
--						(CASE
--							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
--							ELSE m.LNGG_TYPE_ID
--						END) AV_PREF_LANG_CODE
--					,(CASE MBR_COMMUNICATION_TYPE 
--						WHEN 'SM' THEN 'SMS'		-- don't change this comment
--							WHEN 'EM' THEN 'EMAIL'
--							ELSE 'PAPER'
--						END) AV_NOTIFY_MEDIUM_CODE
--						,'N' RECEIVE_PAPER_FLAG
--						,m.trustee_entty_cd
--				FROM    DM_CORRELATED_PERSON m
--						INNER JOIN cmn_client_contact_person cp
--						ON  cp.remark = m.RELATED_PERSON_ID
--						AND cp.scheme_code = m.scheme_code
--						INNER JOIN cmn_client c
--						ON  c.id = cp.id        
--				WHERE   cp.scheme_code = '&&1'
--					
--					
--								SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
--						(CASE
--							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
--							ELSE m.LNGG_TYPE_ID
--						END) AV_PREF_LANG_CODE
--						,(CASE MBR_COMMUNICATION_TYPE 
--							WHEN 'SM' THEN 'SMS'		-- don't change this comment
--							WHEN 'EM' THEN 'EMAIL'
--							ELSE 'PAPER'
--						END) AV_NOTIFY_MEDIUM_CODE
--						,'N' RECEIVE_PAPER_FLAG
--						,m.trustee_entty_cd
--				FROM    DM_CORRELATED_PERSON m
--						INNER JOIN cmn_client_contact_person cp ON  cp.remark = m.RELATED_PERSON_ID AND cp.scheme_code = m.scheme_code
--						INNER JOIN cmn_client c ON  c.id = cp.id        
--				WHERE   cp.scheme_code = '&&1' and cp.av_client_type not in ('EMPLOYER_ACCT','EMPLOYER','PAYROLL_GROUP')
--				
--				UNION ALL
--				SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
--						(CASE
--							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
--							ELSE m.LNGG_TYPE_ID
--						END) AV_PREF_LANG_CODE
--						,(CASE MBR_COMMUNICATION_TYPE 
--							WHEN 'SM' THEN 'SMS'		-- don't change this comment
--							WHEN 'EM' THEN 'EMAIL'
--							ELSE 'PAPER'
--						END) AV_NOTIFY_MEDIUM_CODE
--						,'N' RECEIVE_PAPER_FLAG
--						,m.trustee_entty_cd
--				FROM    DM_CORRELATED_PERSON m
--						INNER JOIN cmn_client_contact_person cp ON  cp.remark = m.RELATED_PERSON_ID AND cp.scheme_code = m.scheme_code
--						inner join enr_er_acct enr on cp.client_uuid = enr.id and m.trustee_entty_cd = enr.tr_employer_code 
--						INNER JOIN cmn_client c ON  c.id = cp.id        
--				WHERE   cp.scheme_code = '&&1' and cp.av_client_type = 'EMPLOYER_ACCT'
--		
--				UNION ALL
--				SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
--						(CASE
--							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
--							ELSE m.LNGG_TYPE_ID
--						END) AV_PREF_LANG_CODE
--						,(CASE MBR_COMMUNICATION_TYPE 
--							WHEN 'SM' THEN 'SMS'		-- don't change this comment
--							WHEN 'EM' THEN 'EMAIL'
--							ELSE 'PAPER'
--						END) AV_NOTIFY_MEDIUM_CODE
--						,'N' RECEIVE_PAPER_FLAG
--						,m.trustee_entty_cd
--				FROM    DM_CORRELATED_PERSON m
--						INNER JOIN cmn_client_contact_person cp ON  cp.remark = m.RELATED_PERSON_ID AND cp.scheme_code = m.scheme_code
--						inner join enr_er_acct enr on cp.client_uuid = enr.employer_uuid and m.trustee_entty_cd = enr.tr_employer_code 
--						INNER JOIN cmn_client c ON  c.id = cp.id        
--				WHERE   cp.scheme_code = '&&1' and cp.av_client_type = 'EMPLOYER'
--				
--				UNION ALL
--				SELECT  cp.id AS client_uuid, c.system_client_type, m.CONSENT_TO_DIRECT_MARKETING, 
--						(CASE
--							WHEN m.LNGG_TYPE_ID IS NULL THEN 'ZH-HK'
--							ELSE m.LNGG_TYPE_ID
--						END) AV_PREF_LANG_CODE
--						,(CASE MBR_COMMUNICATION_TYPE 
--							WHEN 'SM' THEN 'SMS'		-- don't change this comment
--							WHEN 'EM' THEN 'EMAIL'
--							ELSE 'PAPER'
--						END) AV_NOTIFY_MEDIUM_CODE
--						,'N' RECEIVE_PAPER_FLAG
--						,m.trustee_entty_cd
--				FROM    DM_CORRELATED_PERSON m
--						INNER JOIN cmn_client_contact_person cp ON  cp.remark = m.RELATED_PERSON_ID AND cp.scheme_code = m.scheme_code
--						inner join enr_er_acct enr on m.trustee_entty_cd = enr.tr_employer_code 
--						inner join enr_payroll_group pg on cp.client_uuid = pg.id
--						INNER JOIN cmn_client c ON  c.id = cp.id        
--				WHERE   cp.scheme_code = '&&1' and cp.av_client_type = 'PAYROLL_GROUP'
--				
--				-- GY 281124 end
				) cp
		WHERE     NOT EXISTS (  SELECT *
								FROM    CMN_CLIENT_COMM_PREF cp2
								WHERE   cp2.client_uuid = cp.client_uuid)
--		--AND      cp.TRUSTEE_ENTTY_CD LIKE '%0000043366000001%'
		) id
		ORDER BY client_uuid;
		
		-- update member AV_NOTIFY_MEDIUM_CODE based on RECEIVE_PAPER_FLAG
		-- if RECEIVE_PAPER_FLAG = 'Y', then set AV_NOTIFY_MEDIUM_CODE = 'PAPER'
		-- if RECEIVE_PAPER_FLAG = 'N' and AV_NOTIFY_MEDIUM_CODE = 'PAPER',then set AV_NOTIFY_MEDIUM_CODE = 'EMAIL' 
		update cmn_client_comm_pref a
		set AV_NOTIFY_MEDIUM_CODE = 'PAPER'
		where RECEIVE_PAPER_FLAG = 'Y'
		and exists (
			select 1
			from enr_mem_acct b
			where a.client_uuid = b.id
			and b.scheme_code = '&&1' -- remove this line if it is a full patch
		)
		and nvl(AV_NOTIFY_MEDIUM_CODE,'XX') <> 'PAPER';
		commit;

		update cmn_client_comm_pref a
		set AV_NOTIFY_MEDIUM_CODE = 'EMAIL'
		where RECEIVE_PAPER_FLAG = 'N'
		and exists (
			select 1
			from enr_mem_acct b
			where a.client_uuid = b.id
			and b.scheme_code = '&&1' -- remove this line if it is a full patch
		)
		and AV_NOTIFY_MEDIUM_CODE = 'PAPER';
		commit;
-- JL-250702

		--WL-030724 begin
		--WL-170225 begin
		if '&&1' <> 'MT' then
		--WL-170225 end
			delete cmn_client_phone a where a.scheme_code = '&&1' and a.client_uuid in 
				(select p.id from cmn_client_contact_person p where p.av_contact_person_type = 'AP' and scheme_code = '&&1');
			delete cmn_client_email a where a.scheme_code = '&&1' and a.client_uuid in 
				(select p.id from cmn_client_contact_person p where p.av_contact_person_type = 'AP' and scheme_code = '&&1');
			delete cmn_client_comm_pref a where a.scheme_code = '&&1' and a.client_uuid in 
				(select p.id from cmn_client_contact_person p where p.av_contact_person_type = 'AP' and scheme_code = '&&1');
			
			delete cmn_client_contact_person p where p.av_contact_person_type = 'AP' and scheme_code = '&&1';
		--WL-170225 begin
		end if;
		--WL-170225 end
		
		COMMIT;
		--WL-030724 end
--    END LOOP;

END;
/

/*

SELECT COUNT(1) FROM CMN_CLIENT_COMM_PREF
SELECT * FROM CMN_CLIENT_COMM_PREF

DELETE CMN_CLIENT_COMM_PREF WHERE SCHEME_CODE = '&&1'

        
*/