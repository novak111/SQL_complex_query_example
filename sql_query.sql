--Snowflake SQL
SELECT 
		bps."id_controlling" AS "controlling_id",
		ebc."esum"  AS "esum",
		ebc."currency",
		bps."delivery_date" AS "delivery_date",
		-- commodity price ST/HT
		SUM(
			CASE
				WHEN ebc."tariff" = '01 - Jednotarif' THEN -- výpočet pro single tarif
					--vypocet ST
					CASE 
						WHEN ebc."currency" = 'EUR' THEN
							(bps."hedge_profile_price"::FLOAT * fx."fx_zaverkovy"::FLOAT  * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energysum"::FLOAT - edts."initialplanorig"::FLOAT))
						ELSE
							(bps."hedge_profile_price"::FLOAT * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energysum"::FLOAT - edts."initialplanorig"::FLOAT))
					END		
				ELSE
					-- výpočet pro high tarif
					CASE 
						WHEN ebc."currency" = 'EUR' THEN
							(bps."hedge_profile_price"::FLOAT * fx."fx_zaverkovy"::FLOAT * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energyhtsum"::FLOAT - edts."initialplanorig"::FLOAT))
						ELSE
							(bps."hedge_profile_price"::FLOAT * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energyhtsum"::FLOAT - edts."initialplanorig"::FLOAT))
					END
			END) 
		/
		COALESCE(NULLIF(SUM(
			CASE 
				WHEN ebc."tariff" = '01 - Jednotarif' THEN -- výpočet pro single tarif
					edts."energysum"::FLOAT
				ELSE
					edts."energyhtsum"::FLOAT
			END), 0.0), 1)
		AS "commodity_price_st_ht",
		-- commodity price LT
		SUM(
			CASE
				WHEN ebc."tariff" = '01 - Jednotarif' THEN NULL -- výpočet pro single tarif 
				ELSE 
				--výpočet pro low tarif
					CASE
						WHEN ebc."currency" = 'EUR' THEN
							(bps."hedge_profile_price"::FLOAT * fx."fx_zaverkovy"::FLOAT * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energyltsum"::FLOAT - edts."initialplanorig"::FLOAT))
						ELSE
							(bps."hedge_profile_price"::FLOAT * edts."initialplanorig"::FLOAT + sp."DA_price_EUR"::FLOAT * fx."fx_zaverkovy" * (edts."energyltsum"::FLOAT - edts."initialplanorig"::FLOAT))
					END
			END)
		/
		COALESCE(NULLIF(SUM(
			CASE 
				WHEN ebc."tariff" = '01 - Jednotarif' THEN NULL -- výpočet pro single tarif
				ELSE
					edts."energyltsum"::FLOAT
			END), 0.0), 1)
		AS "commodity_price_lt"
FROM "ee_b2b_price_structure"  bps
JOIN "ee_b2b_contract" ebc 
	ON bps."id_controlling" = ebc."lnc_controlling_id" 
JOIN "ee_diagram_ts" edts
	ON ebc."id_contract" = edts."smlouvaid" 
		AND DATE_TRUNC('MONTH', EDTS."datetime"::DATE) = DATE_TRUNC('MONTH', bps."delivery_date"::DATE)
JOIN "spot_prices" sp
	ON EDTS."datetime"  = sp."delivery_start"
JOIN "fx_zaverkovy" fx
WHERE ebc."product" LIKE 'Spotové vyrovnání%' 
	AND ebc."purchase" = 'Spotřeba'
	AND EDTS."datetime"::date BETWEEN '2023-05-01' AND '2023-05-31'
GROUP BY bps."delivery_date", bps."id_controlling", ebc."esum", ebc."currency"
;