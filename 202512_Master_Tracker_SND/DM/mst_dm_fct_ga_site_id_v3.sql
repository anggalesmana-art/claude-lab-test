declare vdt_id date default @vdt_id;

delete from `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3` where dt = vdt_id; 

INSERT INTO `data-bi-prd-935c.bi_mart.fct_ga_site_id_v3`
SELECT a.dt, a.sbscrptn_ek_id, a.site_id, COALESCE(b.book_qrcode_final, b.partner_qr_cd) AS partner_qr_cd, b.channel
   FROM `data-bi-prd-935c.bi_mart`.fct_ga_site_id a
   LEFT JOIN `data-bi-prd-935c.bi_mart`.snd_rgu_ga_new_detail b ON a.dt = b.load_dt_sk_id AND a.sbscrptn_ek_id = b.sbscrptn_ek_id
where a.dt = vdt_id