/*
12/06/2024	George Ngai		change sys_guid to generate_guid
22/08/2024  Justin Leung    JL20240822 Add VIP_TYPE_CODE
*/
SET SERVEROUT ON SIZE 1000000;

DECLARE
v_update_by             VARCHAR2(50) := '&&1 UAT core2 14/12/2013'; 
v_scheme_cycle_date     DATE;
v_vip_uuid              RAW(16);

CURSOR vip_cur IS
SELECT  ea.id AS er_acct_uuid, dm.vip_code, ea.eff_date
FROM    DM_EMPLOYER dm
        INNER JOIN enr_er_acct ea
        ON  ea.tr_employer_code = dm.trustee_emplr_cd
        AND dm.scheme_code = ea.scheme_code
WHERE   dm.vip_code IS NOT NULL
AND dm.scheme_code = '&&1'
ORDER BY ea.id;

vip vip_cur%ROWTYPE;

BEGIN

    FOR vip IN vip_cur LOOP  
        SELECT generate_guid('&&1')
        INTO    v_vip_uuid
        FROM   DUAL;    
        
        -- 'TIER_1', 
        INSERT INTO cmn_agent_vip
        (ID, ER_ACCT_UUID, AV_VIP_TYPE_CODE, VIP_TYPE_CODE -- JL20240822
		,EFF_DATE, AV_ACTION_CODE
        ,ARCHIVE_FLAG
        ,CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY, CREATION_DATE, SCHEME_CODE)
        VALUES
        (v_vip_uuid, vip.er_acct_uuid, vip.vip_code, vip.vip_code
		,vip.eff_date, 'NEW'
        ,'N'
        ,v_update_by, SYSDATE, v_update_by, SYSDATE, '&&1');  
    END LOOP;
END;
/

--AV_VIP_TYPE_CODE in ('TIER_1','TIER_2')
