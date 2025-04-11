/* ============================================================================
  SCRIPT:        RI_SUPERVISAO_ANALITICA_V3.sql
  DESCRIÇÃO:     Consulta funcional detalhada para diagnóstico de RI (Recebimento Integrado),
                 com análise por linha de nota fiscal, roteiros, integrações e flags analíticas.

  OBJETIVO:      Auxiliar na identificação de falhas ou pendências em processos de RI, tais como:
                 - RI aprovado mas sem entrega
                 - Falta de inspeção obrigatória
                 - Notas sem vínculo com OC
                 - Itens inativos
                 - Retenções aplicadas
                 - Diagnóstico funcional e sugestão de ação

  INFORMAÇÕES INCLUÍDAS:
                 - Dados da NF, item, fornecedor e organização
                 - Quantidades da PO e do RI
                 - Roteiro de recebimento (item e PO)
                 - Indicadores de retenção (IR, INSS, ISS)
                 - Situação da NFEE e presença de HOLD
                 - Flags de análise e recomendação automatizada de ação

  TABELAS USADAS:
                 - CLL_F189_ENTRY_OPERATIONS
                 - CLL_F189_INVOICES / LINES / TYPES
                 - PO_LINE_LOCATIONS_ALL / PO_HEADERS_ALL
                 - RCV_TRANSACTIONS
                 - MTL_SYSTEM_ITEMS
                 - FND_LOOKUP_VALUES
                 - AP_AWT_GROUPS
                 - CLL_F189_HOLDS
                 - NFEE_HEADER_XML

  VERSÃO:        v3
  AUTOR:         Adoniran Paim
  DATA:          abril/2025
============================================================================ */

WITH base_ri AS (

  SELECT

    reo.operation_id AS ri,

    reo.status AS status_ri,

    reo.receive_date,

    reo.gl_date,

  

    ri.invoice_id,

    ri.invoice_num,

    ri.series,

    ri.invoice_date,

    ri.invoice_amount,

    ri.invoice_type_id,

    ri.entity_id,

    ri.ir_base, ri.ir_tax, ri.ir_amount,

    ri.inss_base, ri.inss_tax, ri.inss_amount,

    ri.iss_base, ri.iss_tax, ri.iss_amount,

    ri.eletronic_invoice_key,

 

    ril.invoice_line_id,

    ril.quantity AS qtd_nf,

    ril.item_id,

    ril.line_location_id,

    ril.operation_fiscal_type AS nop,

    ril.awt_group_id,

    ril.cfo_id,

    ril.utilization_id,

 

    pll.quantity AS qtd_solicitada_po,

    pll.quantity_received AS qtd_recebida_po,

    pll.po_header_id,

 

    ph.segment1 AS numero_oc,

    ph.type_lookup_code AS tipo_oc,

    ph.creation_date AS data_criacao_oc,

 

    rit.invoice_type_code,

    rit.description AS desc_tipo_nf,

    rit.requisition_type,

--    rit.interface_flag,

 

    rfo.cfo_code,

    riu.utilization_code,

 

    pv.vendor_name,

    mp.organization_code AS org,

 

    msi.inventory_item_id,

    msi.receiving_routing_id AS roteiro_item_id,

    pll.receiving_routing_id AS roteiro_po_id,

 

    rt.transaction_id,

 

    nhx.status AS status_nfee,

 

    -- Verifica se tem HOLD

    (SELECT COUNT(1) FROM apps.cll_f189_holds h WHERE h.invoice_id = ri.invoice_id) AS hold_count

 

  FROM apps.cll_f189_entry_operations reo

 

  LEFT JOIN apps.cll_f189_invoices ri

         ON ri.operation_id = reo.operation_id AND ri.organization_id = reo.organization_id

 

  LEFT JOIN apps.cll_f189_invoice_lines ril

         ON ril.invoice_id = ri.invoice_id

 

  LEFT JOIN apps.cll_f189_invoice_types rit

         ON rit.invoice_type_id = ri.invoice_type_id AND rit.organization_id = ri.organization_id

 

  LEFT JOIN apps.po_line_locations_all pll

         ON pll.line_location_id = ril.line_location_id

 

  LEFT JOIN apps.po_headers_all ph

         ON ph.po_header_id = pll.po_header_id

 

  LEFT JOIN apps.rcv_transactions rt

         ON rt.po_line_location_id = pll.line_location_id AND rt.transaction_type = 'DELIVER'

 

  LEFT JOIN apps.cll_f189_fiscal_operations rfo

         ON rfo.cfo_id = ril.cfo_id

 

  LEFT JOIN apps.cll_f189_item_utilizations riu

         ON riu.utilization_id = ril.utilization_id

 

  LEFT JOIN apps.cll_f189_fiscal_entities_all rfea

         ON rfea.entity_id = ri.entity_id

 

  LEFT JOIN apps.po_vendor_sites_all pvsa

         ON pvsa.vendor_site_id = rfea.vendor_site_id

 

  LEFT JOIN apps.po_vendors pv

         ON pv.vendor_id = pvsa.vendor_id

 

  LEFT JOIN apps.mtl_parameters mp

         ON mp.organization_id = reo.organization_id

 

  LEFT JOIN apps.mtl_system_items msi

         ON msi.inventory_item_id = ril.item_id AND msi.organization_id = reo.organization_id

 

  LEFT JOIN apps.nfee_header_xml nhx

         ON nhx.chave = ri.eletronic_invoice_key

)

 

SELECT

  b.ri,

  b.status_ri,

  b.receive_date,

  b.gl_date,

 

  b.invoice_num,

  b.series,

  b.invoice_date,

  b.invoice_amount,

 

  b.invoice_line_id,

  b.qtd_nf,

  b.qtd_solicitada_po,

  b.qtd_recebida_po,

 

  b.numero_oc,

  b.tipo_oc,

  b.data_criacao_oc,

 

  b.invoice_type_code,

  b.desc_tipo_nf,

  b.requisition_type,

  --b.interface_flag,

 

  b.cfo_code,

  b.nop,

  b.utilization_code,

  b.vendor_name,

  b.org,

 

  -- Roteiro PO e Item

  rrh.meaning AS roteiro_po,

  rrh_item.meaning AS roteiro_item,

 

  -- Retenção

  b.awt_group_id,

  awt.name AS grupo_retencao,

  b.ir_base, b.ir_tax, b.ir_amount,

  b.inss_base, b.inss_tax, b.inss_amount,

  b.iss_base, b.iss_tax, b.iss_amount,

 

  -- Flags

  CASE WHEN b.transaction_id IS NULL THEN 'NÃO' ELSE 'SIM' END AS flag_recebimento,

  CASE WHEN b.po_header_id IS NULL THEN 'NÃO' ELSE 'SIM' END AS flag_oc,

  CASE WHEN b.inventory_item_id IS NULL THEN 'NÃO' ELSE 'SIM' END AS flag_item_ativo,

  --CASE WHEN b.interface_flag = 'Y' THEN 'SIM' ELSE 'NÃO' END AS flag_integra_ap,

  CASE WHEN b.requisition_type = 'PO' THEN 'REQUER OC' ELSE 'SEM OC' END AS flag_precisa_oc,

  CASE WHEN b.hold_count > 0 THEN 'SIM' ELSE 'NÃO' END AS flag_hold,

  b.status_nfee,

 

  -- Diagnóstico

  CASE

    WHEN b.invoice_line_id IS NULL THEN 'SEM LINHA DE NOTA'

    WHEN b.transaction_id IS NULL THEN 'SEM TRANSAÇÃO'

    WHEN b.po_header_id IS NULL AND b.requisition_type = 'PO' THEN 'SEM OC'

    WHEN b.qtd_recebida_po < b.qtd_nf THEN 'QTD RECEBIDA MENOR QUE NF'

    ELSE 'OK'

  END AS status_analitico,

 

  -- Ação recomendada

  CASE

    WHEN b.transaction_id IS NULL AND b.status_ri = 'APPROVED' THEN 'Executar concurrent para gerar transação'

    WHEN b.invoice_line_id IS NULL THEN 'Verificar parsing do XML'

    WHEN b.po_header_id IS NULL AND b.requisition_type = 'PO' THEN 'Verificar se houve quebra de vínculo com OC'

    WHEN b.hold_count > 0 THEN 'Remover ou tratar HOLD'

    ELSE 'OK'

  END AS sugestao_acao

 

FROM base_ri b

 

LEFT JOIN apps.fnd_lookup_values rrh

       ON rrh.lookup_type = 'RCV_ROUTING_HEADERS'

      AND rrh.lookup_code = b.roteiro_po_id

      AND rrh.language = 'PTB'

 

LEFT JOIN apps.fnd_lookup_values rrh_item

       ON rrh_item.lookup_type = 'RCV_ROUTING_HEADERS'

      AND rrh_item.lookup_code = b.roteiro_item_id

      AND rrh_item.language = 'PTB'

 

LEFT JOIN apps.ap_awt_groups awt

       ON awt.group_id = b.awt_group_id

 

WHERE 1=1

  AND b.ri  = '357165'--:RI
  AND b.org = 'GVT'

 

ORDER BY b.ri, b.invoice_line_id;