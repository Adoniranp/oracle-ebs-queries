/* -------------------------------------------------------------------------
  SCRIPT:     ATENDIMENTO_OC_SEM_RC.sql
  DESCRIÇÃO:  Consulta que identifica pedidos de compra (OC) do tipo STANDARD,
              BLANKET e PLANNED que não possuem vínculo com requisição (RC),
              mas possuem centro de custo, com o objetivo de análise de
              atendimento de materiais e rastreabilidade de recebimentos.

  OBJETIVO:
     - Identificar fluxos de OC que não tiveram requisição associada
     - Validar itens, prazos, recebimentos e roteiros de inspeção
     - Avaliar fornecedores e contratos envolvidos
     - Apontar possíveis inconsistências ou oportunidades de melhoria

  INFORMAÇÕES RETORNADAS:
     - Dados da OC, linha, entrega e liberação
     - Informações do item, projeto e centro de custo
     - Prazo de entrega previsto e lead time de contrato
     - Datas de recebimento (RECEIVE e DELIVER)
     - Status do RI, roteiros, aprovadores, valores
     - Situação do vínculo com RC (ausente)

  CLASSIFICAÇÃO:
     - Tipo: Diagnóstico Operacional
     - Módulo: PO / RECEBIMENTO / GL / PROJETOS
     - Origem: Solicitação funcional (atendimento/fornecimento)

  AUTOR:      Adoniran Paim
  VERSÃO:     1.0
  DATA:       abril/2025
-------------------------------------------------------------------------*/
SELECT DISTINCT 
       ' '                                                                         "DT_APROVACAO_RC (HEADER)",
       ---
       (SELECT SUBSTR(HOU.NAME, 4)
          FROM APPS.HR_OPERATING_UNITS HOU
         WHERE HOU.ORGANIZATION_ID = PHA.ORG_ID)                                   "EMPRESA",
       ---
       ' '                                                                         "NR_RC",
       ' '                                                                         "STATUS_RC",
       ' '                                                                         "NR_LINHA_RC",
       ' '                                                                         "STATUS FECHAMENTO RC (LINHA)",   
       ' '                                                                         "STATUS CANCELAMENTO RC (LINHA)",  
       ---
       (SELECT MSI.SEGMENT1
          FROM INV.MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.INVENTORY_ITEM_ID = PLA.ITEM_ID
           AND MSI.ORGANIZATION_ID   = PLLA.SHIP_TO_ORGANIZATION_ID)               "CD_ITEM_REQ (LINHA)",
       ---
       TRANSLATE(PLA.ITEM_DESCRIPTION, CHR(9) || CHR(10) || CHR(13), ' ')          "DESCRICAO_ITEM",
       ---
       (SELECT FLV.MEANING      
          FROM APPS.FND_LOOKUP_VALUES FLV,
               INV.MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.INVENTORY_ITEM_ID = PLA.ITEM_ID
           AND MSI.ORGANIZATION_ID   = PLLA.SHIP_TO_ORGANIZATION_ID   
           AND FLV.LANGUAGE          = 'PTB'
           AND FLV.LOOKUP_TYPE       = 'ITEM_TYPE'
           AND MSI.ITEM_TYPE         = FLV.LOOKUP_CODE)                            "TIPO_ITEM_USUARIO",   
       ---
       PLA.UNIT_MEAS_LOOKUP_CODE                                                   "UNIDADE_MEDIDA",                    
       MC.SEGMENT1 || '.' || MC.SEGMENT2 || '.' || MC.SEGMENT3 || '.' ||
       MC.SEGMENT4 || '.' || MC.SEGMENT5                                           "CD_CATEGORIA_COMPRAS (LINHA)",
       ' '                                                                         "VALOR_RC (HEADER)",
       ' '                                                                         "VALOR_RC (LINHA)",         
       ' '                                                                         "CARACTERISTICA_REQ (LINHA)",
       ' '                                                                         "FLAG_URGENCIA (LINHA)",
       ' '                                                                         "ORIGEM", 
       ' '                                                                         "DESTINO", 
       ' '                                                                         "QT_REQUISITADA (LINHA)",
       ---
       (SELECT OOD.ORGANIZATION_CODE
          FROM APPS.ORG_ORGANIZATION_DEFINITIONS OOD
         WHERE OOD.ORGANIZATION_ID = PLLA.SHIP_TO_ORGANIZATION_ID)                 "CD_ORGANIZACAO_DESTINO (LINHA)",
       ---
       ' '                                                                         "DT_NECESSIDADE (LINHA)",
       TO_CHAR(PHA.APPROVED_DATE, 'DD/MM/YYYY HH24:MI:SS')                         "DT_APROVACAO_OC (HEADER)",
       PHA.SEGMENT1                                                                "NR_DOC_COMPRA",
       PHA.AUTHORIZATION_STATUS                                                    "STATUS_DOC_COMPRA",  
       ---
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_ID IS NOT NULL THEN 
                  (SELECT   ICIT.LEAD_TIME
                    FROM ICX.ICX_CAT_ITEM_PRICES ICIP,
                         ICX.ICX_CAT_ITEMS_B ICIB,
                         APPS.ICX_CAT_ITEMS_TLP           ICIT,
                         PO.PO_HEADERS_ALL CONTRATO_PAI
                   WHERE ICIB.RT_ITEM_ID           = ICIP.RT_ITEM_ID
                     AND ICIB.SUPPLIER_PART_AUXID  = CONTRATO_PAI.SEGMENT1   -- SEGMENT1 DO CONTRACT
                     AND ICIB.SUPPLIER             = PV.VENDOR_NAME          -- NOME DO FORNECEDOR
                     AND ICIB.SUPPLIER_PART_NUM    = PLA.VENDOR_PRODUCT_NUM  -- PART NUMBER DO ITEM FORNECEDOR  
                     AND ICIB.RT_ITEM_ID           = ICIT.RT_ITEM_ID
                     AND ICIT.LANGUAGE             = 'PTB'
                     AND CONTRATO_PAI.PO_HEADER_ID = PLA.CONTRACT_ID
                     AND ROWNUM                    = 1)             
            ELSE TO_NUMBER(PLA.ATTRIBUTE3) END                                     "PRAZO DE ENTREGA",
       ---
       PLLA.SHIPMENT_NUM                                                           "NR_ENTREGA",
       PLA.LINE_NUM                                                                "NR_LINHA",
       NULL                                                                        "NR_LIBERACAO",
       ---
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_NUM IS NOT NULL THEN 'STANDARD (CONTRACT)'
            WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_NUM IS NULL THEN 'STANDARD (SPOT)'
            ELSE PHA.TYPE_LOOKUP_CODE END                                          "TIPO_DOCUMENTO",
       ---
       PV.VENDOR_NAME                                                              "RAZAO_SOCIAL_FORNECEDOR",
       ---
       DECODE(PVSA.GLOBAL_ATTRIBUTE9,
              2,
              PVSA.GLOBAL_ATTRIBUTE10 || '/' || PVSA.GLOBAL_ATTRIBUTE11 || '-' ||
              PVSA.GLOBAL_ATTRIBUTE12,
              1,
              PVSA.GLOBAL_ATTRIBUTE10 || '-' || PVSA.GLOBAL_ATTRIBUTE12,
              3,
              PVSA.GLOBAL_ATTRIBUTE10 || PVSA.GLOBAL_ATTRIBUTE11 ||
              PVSA.GLOBAL_ATTRIBUTE12)                                             "CNPJ_FORNECEDOR",
       ---
       PVSA.CITY                                                                   "MUNICIPIO_FORNECEDOR",
       PVSA.ADDRESS_LINE4                                                          "UF_FORNECEDOR",
       PHA.FOB_LOOKUP_CODE                                                         "INCOTERM",
       ---
       (SELECT PAP.LAST_NAME          
          FROM HR.PER_ALL_PEOPLE_F PAP        
         WHERE PAP.PERSON_ID  = PHA.AGENT_ID         
           AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE)         
                                  AND TRUNC(PAP.EFFECTIVE_END_DATE)         
           AND ROWNUM         = 01)                                                "NOME_COMPRADOR",
       ---
       PLA.VENDOR_PRODUCT_NUM                                                      "PART_NUMBER",
       ---
       (SELECT SUM(R.QUANTITY)
          FROM REC.REC_INVOICE_LINES R
         WHERE R.INVOICE_ID = RI.INVOICE_ID
           AND R.LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
       )                                                                           "QT_ENTREGUE_FORNECEDOR (LINHA)",
       ---
       PLA.UNIT_PRICE                                                              "PRECO_UNITARIO (LINHA_OC)",
       PHA.CURRENCY_CODE                                                           "CD_MOEDA",
       PLLA.QTY_RCV_TOLERANCE                                                      "TOLERANCIA",
       TO_CHAR(PLLA.PROMISED_DATE, 'DD/MM/YYYY HH24:MI:SS')                        "DATA PROMESSA OC",
       TO_CHAR(PLLA.NEED_BY_DATE, 'DD/MM/YYYY HH24:MI:SS')                         "DATA NECESSIDADE OC",
       ---
       (SELECT DISTINCT TO_CHAR(MIN(RTT.TRANSACTION_DATE), 'DD/MM/YYYY HH24:MI:SS')
          FROM PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
         WHERE RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
           AND RTT.PO_LINE_ID          = PLA.PO_LINE_ID
           AND RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
           AND RSH.RECEIPT_NUM         = RI.OPERATION_ID
           AND RTT.TRANSACTION_TYPE    = 'RECEIVE' )                               "DT_CHEGADA_MATERIAL",
       ---
       TO_CHAR(RI.CREATION_DATE, 'DD/MM/YYYY HH24:MI:SS')                          "DT_CAD_NF (LINHA)",
       TO_CHAR(RI.INVOICE_NUM)                                               "NR_NF",
     (SELECT DISTINCT TO_CHAR(MAX(RTT.TRANSACTION_DATE), 'DD/MM/YYYY HH24:MI:SS')
        FROM   PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
        WHERE  RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
         AND   RTT.PO_LINE_ID          = PLA.PO_LINE_ID
        AND    RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
        AND RI.OPERATION_ID      = DECODE((REPLACE(TRANSLATE(TRIM(RSH.RECEIPT_NUM), '0123456789','0000000000'),
                                                            '0',  NULL)), NULL, TO_NUMBER(TRIM(RSH.RECEIPT_NUM)))
         AND RTT.TRANSACTION_TYPE    = 'DELIVER' )                         "DT_BAIXA_AR",
       ---
       RI.OPERATION_ID                                                             "NR_AR",
       ---
       (SELECT SUM(RTT.QUANTITY)
          FROM PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
         WHERE RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
           AND RTT.PO_LINE_ID          = PLA.PO_LINE_ID
           AND RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
           AND RSH.RECEIPT_NUM         = RI.OPERATION_ID
           AND RTT.TRANSACTION_TYPE    = 'DELIVER' )                               "QT_RECEBIDA_AR (LINHA)",
       ---
       (SELECT PH.SEGMENT1
          FROM PO.PO_HEADERS_ALL PH
         WHERE PH.PO_HEADER_ID = PLA.CONTRACT_ID)                                  "NR_CONTRATO_PAI",
       ---
       RRH.MEANING                                                                 "ROTEIRO_DE_RECEBIMENTO",
       REO.STATUS                                                                  "STATUS_RI",
       ' '                                                                         "SOLICITANTE",
       ---
       DECODE(NVL((SELECT 1
                     FROM APPS.MTL_CATEGORIES X,
                          PO.PO_LINES_ALL Y
                    WHERE X.CATEGORY_ID = Y.CATEGORY_ID
                      AND Y.PO_HEADER_ID = PHA.PO_HEADER_ID
                      AND X.SEGMENT1 IN ('SE', 'SM')
                      AND NVL(Y.CANCEL_FLAG, 'N') = 'N'   -- DESCONSIDERAR LINHAS CANCELADAS                   
                      AND ROWNUM = 1), 0),
              1, 'Sim',
                 'Não'
                )                                                                  "RC_TEM_LINHA_SERVICO",
       ' '                                                                         "PREPARADOR",
       ---
       (SELECT DISTINCT LAST_NAME
          FROM APPS.PER_ALL_PEOPLE_F PAPF
         WHERE PAPF.EFFECTIVE_END_DATE > SYSDATE
           AND PAPF.PERSON_ID          = 
             (SELECT DISTINCT PAH.EMPLOYEE_ID
                FROM APPS.PO_ACTION_HISTORY PAH
               WHERE PAH.OBJECT_ID          = PHA.PO_HEADER_ID
                 AND PAH.ACTION_CODE        = 'APPROVE'
                 AND PAH.OBJECT_TYPE_CODE   IN ('PA', 'PO')
                 AND PAH.SEQUENCE_NUM       =  
                      (SELECT MAX(A.SEQUENCE_NUM)
                         FROM APPS.PO_ACTION_HISTORY A
                        WHERE A.ACTION_CODE      = PAH.ACTION_CODE
                          AND A.OBJECT_TYPE_CODE = PAH.OBJECT_TYPE_CODE
                          AND A.OBJECT_ID        = PAH.OBJECT_ID
                      )
             )
           AND ROWNUM                  = 1)  							                          "APROVADOR",
       ---
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_ID IS NOT NULL THEN 
                  (SELECT   MAX(ICIT.LEAD_TIME)
                    FROM ICX.ICX_CAT_ITEM_PRICES ICIP,
                         ICX.ICX_CAT_ITEMS_B ICIB,
                         APPS.ICX_CAT_ITEMS_TLP           ICIT,
                         PO.PO_HEADERS_ALL CONTRATO_PAI
                   WHERE ICIB.RT_ITEM_ID = ICIP.RT_ITEM_ID
                     AND ICIB.SUPPLIER_PART_AUXID = CONTRATO_PAI.SEGMENT1   -- SEGMENT1 DO CONTRACT
                     AND ICIB.SUPPLIER            = PV.VENDOR_NAME          -- NOME DO FORNECEDOR
                     AND ICIB.SUPPLIER_PART_NUM   IN (SELECT PL.VENDOR_PRODUCT_NUM
                                                         FROM PO.PO_LINES_ALL PL
                                                       WHERE PL.PO_HEADER_ID = PHA.PO_HEADER_ID
                                                         AND PL.VENDOR_PRODUCT_NUM IS NOT NULL
                                                         AND NVL(PL.CANCEL_FLAG, 'N')= 'N')
                     AND ICIB.RT_ITEM_ID          = ICIT.RT_ITEM_ID
                     AND ICIT.LANGUAGE           = 'PTB'
                     AND CONTRATO_PAI.PO_HEADER_ID = PLA.CONTRACT_ID        -- PART NUMBER DO ITEM FORNECEDOR
                     ) 
       END                                                                         "PRAZO MAXIMO DE ENTREGA",
       ---
       --PDA.DISTRIBUTION_NUM                                                        "NUMERO_DISTRIBUICAO",
       GCC.SEGMENT1                                                                "CODIGO_EMPRESA",
       GCC.SEGMENT2                                                                "UNIDADE_CONTROLE",
       GCC.SEGMENT3                                                                "CONTA_CONTABIL",
       GCC.SEGMENT4                                                                "CENTRO_DE_CUSTO",
       PPA.SEGMENT1                                                                "NUMERO_PROJETO",
       ---
       (SELECT PAPF.ATTRIBUTE7 || PAPF.ATTRIBUTE8 || '-' || PAPF.LAST_NAME
          FROM APPS.PER_ALL_PEOPLE_F  PAPF,
               APPS.PO_ACTION_HISTORY PAH
         WHERE PAPF.EFFECTIVE_END_DATE(+) > SYSDATE
           AND PAPF.PERSON_ID(+)          = PAH.EMPLOYEE_ID
           AND PAH.SEQUENCE_NUM           =
               (SELECT MAX(P.SEQUENCE_NUM)
                  FROM APPS.PO_ACTION_HISTORY P
                 WHERE P.ACTION_CODE      = PAH.ACTION_CODE
                   AND P.OBJECT_TYPE_CODE = PAH.OBJECT_TYPE_CODE
                   AND P.OBJECT_ID        = PAH.OBJECT_ID)
           AND PAH.ACTION_CODE       = 'APPROVE'
           AND PAH.OBJECT_TYPE_CODE IN ('PA', 'PO')
           AND PAH.OBJECT_ID(+)      = PHA.PO_HEADER_ID
           AND ROWNUM                = 1)                                          "APROVADOR"
  -----
  FROM PO.PO_HEADERS_ALL               PHA,
       PO.PO_LINES_ALL                 PLA,
       PO.PO_LINE_LOCATIONS_ALL        PLLA,
       PO.PO_DISTRIBUTIONS_ALL         PDA,
       GL.GL_CODE_COMBINATIONS         GCC,
       APPS.PA_PROJECTS_ALL            PPA,
       PO.PO_VENDORS                   PV,
       APPS.MTL_CATEGORIES             MC,
       APPS.PO_VENDOR_SITES_ALL        PVSA,   
       REC.REC_INVOICE_LINES           RIL,
       REC.REC_INVOICES                RI,
       REC.REC_ENTRY_OPERATIONS        REO,
       APPS.REC_INVOICE_TYPES          RIT,
       ---
       (SELECT * 
         FROM APPS.FND_LOOKUP_VALUES LV 
        WHERE LV.LOOKUP_TYPE = 'RCV_ROUTING_HEADERS' 
          AND LANGUAGE       = 'PTB')  RRH
 -----
 WHERE PHA.TYPE_LOOKUP_CODE        = 'STANDARD'
   AND PHA.PO_HEADER_ID            = PLA.PO_HEADER_ID
   AND PLA.PO_LINE_ID              = PLLA.PO_LINE_ID  
   AND PLLA.LINE_LOCATION_ID       = PDA.LINE_LOCATION_ID
   AND PDA.CODE_COMBINATION_ID     = GCC.CODE_COMBINATION_ID
   AND PDA.PROJECT_ID              = PPA.PROJECT_ID             (+)
   AND PLA.CATEGORY_ID             = MC.CATEGORY_ID
   AND MC.SEGMENT1            NOT IN ('SE', 'SV')
   AND PLLA.LINE_LOCATION_ID       = RIL.LINE_LOCATION_ID       (+)
   AND PLLA.RECEIVING_ROUTING_ID   = RRH.LOOKUP_CODE            (+)
   AND RIL.INVOICE_ID              = RI.INVOICE_ID              (+)
   AND RI.ORGANIZATION_ID          = REO.ORGANIZATION_ID        (+)
   AND RI.OPERATION_ID             = REO.OPERATION_ID           (+)
   AND PHA.VENDOR_ID               = PVSA.VENDOR_ID             (+)
   AND PHA.VENDOR_SITE_ID          = PVSA.VENDOR_SITE_ID        (+)
   AND PHA.VENDOR_ID               = PV.VENDOR_ID               (+)
   ---
   AND NOT EXISTS
       (SELECT DISTINCT '1'
          FROM PO.PO_REQUISITION_LINES_ALL PRLA
         WHERE PLLA.LINE_LOCATION_ID = PRLA.LINE_LOCATION_ID) -- FILTRA OC SEM REQ
   ---
   AND PHA.AUTHORIZATION_STATUS   IN ('APPROVED')
   AND REO.REVERSION_FLAG         IS NULL
   AND RI.INVOICE_TYPE_ID          = RIT.INVOICE_TYPE_ID        (+)
   AND RI.ORGANIZATION_ID          = RIT.ORGANIZATION_ID        (+)
   AND (
           RI.INVOICE_ID IS NULL
           OR
           (RI.INVOICE_ID IS NOT NULL AND RI.INVOICE_NUM >0 AND NVL(RIT.PARENT_FLAG, 'N') = 'N')
       ) 
   --      
   AND  PHA.APPROVED_DATE    BETWEEN TO_DATE(:Data_Inicial ||' 00:00:00', 'DD/MM/YYYY HH24:MI:SS')
                                 AND TO_DATE(:Data_Final ||' 23:59:59', 'DD/MM/YYYY HH24:MI:SS')
--
--
UNION ALL
--
--
-->> BLANKET, PLANNED <<--
SELECT DISTINCT 
       ' '                                                                         "DT_APROVACAO_RC (HEADER)",
       ---
       (SELECT SUBSTR(HOU.NAME, 4)
          FROM APPS.HR_OPERATING_UNITS HOU
         WHERE HOU.ORGANIZATION_ID = PHA.ORG_ID)                                   "EMPRESA",
       ---
       ' '                                                                         "NR_RC",
       ' '                                                                         "STATUS_RC",
       ' '                                                                         "NR_LINHA_RC",
       ' '                                                                         "STATUS FECHAMENTO RC (LINHA)",   
       ' '                                                                         "STATUS CANCELAMENTO RC (LINHA)",  
       ---
       (SELECT MSI.SEGMENT1
          FROM INV.MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.INVENTORY_ITEM_ID = PLA.ITEM_ID
           AND MSI.ORGANIZATION_ID   = PLLA.SHIP_TO_ORGANIZATION_ID)               "CD_ITEM_REQ (LINHA)",
       ---
       TRANSLATE(PLA.ITEM_DESCRIPTION, CHR(9) || CHR(10) || CHR(13), ' ')          "DESCRICAO_ITEM",
       ---
       (SELECT FLV.MEANING      
          FROM APPS.FND_LOOKUP_VALUES FLV,
               INV.MTL_SYSTEM_ITEMS_B MSI
         WHERE MSI.INVENTORY_ITEM_ID = PLA.ITEM_ID
           AND MSI.ORGANIZATION_ID   = PLLA.SHIP_TO_ORGANIZATION_ID   
           AND FLV.LANGUAGE          = 'PTB'
           AND FLV.LOOKUP_TYPE       = 'ITEM_TYPE'
           AND MSI.ITEM_TYPE         = FLV.LOOKUP_CODE)                            "TIPO_ITEM_USUARIO",   
       ---
       PLA.UNIT_MEAS_LOOKUP_CODE                                                   "UNIDADE_MEDIDA",                    
       MC.SEGMENT1 || '.' || MC.SEGMENT2 || '.' || MC.SEGMENT3 || '.' ||
       MC.SEGMENT4 || '.' || MC.SEGMENT5                                           "CD_CATEGORIA_COMPRAS (LINHA)",
       ' '                                                                         "VALOR_RC (HEADER)",
       ' '                                                                         "VALOR_RC (LINHA)",         
       ' '                                                                         "CARACTERISTICA_REQ (LINHA)",
       ' '                                                                         "FLAG_URGENCIA (LINHA)",
       ' '                                                                         "ORIGEM", 
       ' '                                                                         "DESTINO", 
       ' '                                                                         "QT_REQUISITADA (LINHA)",
       ---
       (SELECT OOD.ORGANIZATION_CODE
          FROM APPS.ORG_ORGANIZATION_DEFINITIONS OOD
         WHERE OOD.ORGANIZATION_ID = PLLA.SHIP_TO_ORGANIZATION_ID)                 "CD_ORGANIZACAO_DESTINO (LINHA)",
       ' '                                                                         "DT_NECESSIDADE (LINHA)",
       TO_CHAR(PRA.APPROVED_DATE, 'DD/MM/YYYY HH24:MI:SS')                         "DT_APROVACAO_OC (HEADER)",
       PHA.SEGMENT1                                                                "NR_DOC_COMPRA",
       PHA.AUTHORIZATION_STATUS                                                    "STATUS_DOC_COMPRA",  
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_ID IS NOT NULL THEN 
                  (SELECT   ICIT.LEAD_TIME
                    FROM ICX.ICX_CAT_ITEM_PRICES ICIP,
                         ICX.ICX_CAT_ITEMS_B ICIB,
                         APPS.ICX_CAT_ITEMS_TLP           ICIT,
                         PO.PO_HEADERS_ALL CONTRATO_PAI
                   WHERE ICIB.RT_ITEM_ID           = ICIP.RT_ITEM_ID
                     AND ICIB.SUPPLIER_PART_AUXID  = CONTRATO_PAI.SEGMENT1   -- SEGMENT1 DO CONTRACT
                     AND ICIB.SUPPLIER             = PV.VENDOR_NAME          -- NOME DO FORNECEDOR
                     AND ICIB.SUPPLIER_PART_NUM    = PLA.VENDOR_PRODUCT_NUM  -- PART NUMBER DO ITEM FORNECEDOR  
                     AND ICIB.RT_ITEM_ID           = ICIT.RT_ITEM_ID
                     AND ICIT.LANGUAGE             = 'PTB'
                     AND CONTRATO_PAI.PO_HEADER_ID = PLA.CONTRACT_ID
                     AND ROWNUM                    = 1)             
            ELSE TO_NUMBER(PLA.ATTRIBUTE3) END                                     "PRAZO DE ENTREGA",
       ---
       PLLA.SHIPMENT_NUM                                                           "NR_ENTREGA",
       PLA.LINE_NUM                                                                "NR_LINHA",
       PRA.RELEASE_NUM                                                             "NR_LIBERACAO",
       ---
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_NUM IS NOT NULL THEN 'STANDARD (CONTRACT)'
            WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_NUM IS NULL THEN 'STANDARD (SPOT)'
            ELSE PHA.TYPE_LOOKUP_CODE END                                          "TIPO_DOCUMENTO",
       ---
       PV.VENDOR_NAME                                                              "RAZAO_SOCIAL_FORNECEDOR",
       ---
       DECODE(PVSA.GLOBAL_ATTRIBUTE9,
              2,
              PVSA.GLOBAL_ATTRIBUTE10 || '/' || PVSA.GLOBAL_ATTRIBUTE11 || '-' ||
              PVSA.GLOBAL_ATTRIBUTE12,
              1,
              PVSA.GLOBAL_ATTRIBUTE10 || '-' || PVSA.GLOBAL_ATTRIBUTE12,
              3,
              PVSA.GLOBAL_ATTRIBUTE10 || PVSA.GLOBAL_ATTRIBUTE11 ||
              PVSA.GLOBAL_ATTRIBUTE12)                                             "CNPJ_FORNECEDOR",
       ---
       PVSA.CITY                                                                   "MUNICIPIO_FORNECEDOR",
       PVSA.ADDRESS_LINE4                                                          "UF_FORNECEDOR",
       PHA.FOB_LOOKUP_CODE                                                         "INCOTERM",
       ---
       (SELECT PAP.LAST_NAME          
          FROM HR.PER_ALL_PEOPLE_F PAP        
         WHERE PAP.PERSON_ID  = PHA.AGENT_ID         
           AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE)         
                                  AND TRUNC(PAP.EFFECTIVE_END_DATE)         
           AND ROWNUM         = 01)                                                "NOME_COMPRADOR",
       ---
       PLA.VENDOR_PRODUCT_NUM                                                      "PART_NUMBER",
       ---
       (SELECT SUM(R.QUANTITY)
          FROM REC.REC_INVOICE_LINES R
         WHERE R.INVOICE_ID       = RI.INVOICE_ID
           AND R.LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
       )                                                                           "QT_ENTREGUE_FORNECEDOR (LINHA)",
       ---
       PLA.UNIT_PRICE                                                              "PRECO_UNITARIO (LINHA_OC)",
       PHA.CURRENCY_CODE                                                           "CD_MOEDA",
       PLLA.QTY_RCV_TOLERANCE                                                      "TOLERANCIA",
       TO_CHAR(PLLA.PROMISED_DATE, 'DD/MM/YYYY HH24:MI:SS')                        "DATA PROMESSA OC",
       TO_CHAR(PLLA.NEED_BY_DATE, 'DD/MM/YYYY HH24:MI:SS')                         "DATA NECESSIDADE OC",
       ---
       (SELECT DISTINCT TO_CHAR(MIN(RTT.TRANSACTION_DATE), 'DD/MM/YYYY HH24:MI:SS')
          FROM PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
         WHERE RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
           AND RTT.PO_LINE_ID          = PLA.PO_LINE_ID
           AND RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
           AND RSH.RECEIPT_NUM         = RI.OPERATION_ID
           AND RTT.TRANSACTION_TYPE    = 'RECEIVE' )                               "DT_CHEGADA_MATERIAL",
       ---
       TO_CHAR(RI.CREATION_DATE, 'DD/MM/YYYY HH24:MI:SS')                          "DT_CAD_NF (LINHA)",
       TO_CHAR(RI.INVOICE_NUM)                                               "NR_NF",
     (SELECT DISTINCT TO_CHAR(MAX(RTT.TRANSACTION_DATE), 'DD/MM/YYYY HH24:MI:SS')
        FROM   PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
        WHERE  RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
         AND   RTT.PO_LINE_ID          = PLA.PO_LINE_ID
        AND    RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
        AND RI.OPERATION_ID      = DECODE((REPLACE(TRANSLATE(TRIM(RSH.RECEIPT_NUM), '0123456789','0000000000'),
                                                            '0',  NULL)), NULL, TO_NUMBER(TRIM(RSH.RECEIPT_NUM)))
         AND RTT.TRANSACTION_TYPE    = 'DELIVER' )                         "DT_BAIXA_AR",
       ---
       RI.OPERATION_ID                                                             "NR_AR",
       ---
       (SELECT SUM(RTT.QUANTITY)
          FROM PO.RCV_SHIPMENT_HEADERS RSH ,
               PO.RCV_TRANSACTIONS     RTT
        WHERE RTT.PO_LINE_LOCATION_ID = PLLA.LINE_LOCATION_ID
          AND RTT.PO_LINE_ID          = PLA.PO_LINE_ID
          AND RTT.SHIPMENT_HEADER_ID  = RSH.SHIPMENT_HEADER_ID
          AND RSH.RECEIPT_NUM         = RI.OPERATION_ID
          AND RTT.TRANSACTION_TYPE    = 'DELIVER' )                                "QT_RECEBIDA_AR (LINHA)",
       ---
       (SELECT PH.SEGMENT1
          FROM PO.PO_HEADERS_ALL PH
         WHERE PH.PO_HEADER_ID = PLA.CONTRACT_ID)                                  "NR_CONTRATO_PAI",
       ---
       RRH.MEANING                                                                 "ROTEIRO_DE_RECEBIMENTO",
       REO.STATUS                                                                  "STATUS_RI",
       ' '                                                                         "SOLICITANTE",
       ---
       DECODE(NVL((SELECT 1
                     FROM APPS.MTL_CATEGORIES X,
                          PO.PO_LINES_ALL Y
                    WHERE X.CATEGORY_ID = Y.CATEGORY_ID
                      AND Y.PO_HEADER_ID = PHA.PO_HEADER_ID
                      AND X.SEGMENT1 IN ('SE', 'SM')
                      AND NVL(Y.CANCEL_FLAG, 'N') = 'N'   -- DESCONSIDERAR LINHAS CANCELADAS                   
                      AND ROWNUM = 1), 0),
              1, 'Sim',
                 'Não'
             )                                                                     "RC_TEM_LINHA_SERVICO",
       ---
       ' '                                                                         "PREPARADOR",    
       ---
       (SELECT DISTINCT LAST_NAME
          FROM APPS.PER_ALL_PEOPLE_F PAPF
         WHERE PAPF.EFFECTIVE_END_DATE > SYSDATE
           AND PAPF.PERSON_ID          = 
             (SELECT DISTINCT PAH.EMPLOYEE_ID
                FROM APPS.PO_ACTION_HISTORY PAH
               WHERE PAH.OBJECT_ID          = PRA.PO_RELEASE_ID
                 AND PAH.ACTION_CODE        = 'APPROVE'
                 AND PAH.OBJECT_TYPE_CODE   = 'RELEASE'
                 AND PAH.SEQUENCE_NUM       =  
                      (SELECT MAX(A.SEQUENCE_NUM)
                         FROM APPS.PO_ACTION_HISTORY A
                        WHERE A.ACTION_CODE      = PAH.ACTION_CODE
                          AND A.OBJECT_TYPE_CODE = PAH.OBJECT_TYPE_CODE
                          AND A.OBJECT_ID        = PAH.OBJECT_ID
                      )
             )
          AND ROWNUM                   = 1
       )  							                                                           "APROVADOR",
       ---
       CASE WHEN PHA.TYPE_LOOKUP_CODE = 'STANDARD' 
             AND PLA.CONTRACT_ID IS NOT NULL THEN 
                  (SELECT   MAX(ICIT.LEAD_TIME)
                    FROM ICX.ICX_CAT_ITEM_PRICES ICIP,
                         ICX.ICX_CAT_ITEMS_B ICIB,
                         APPS.ICX_CAT_ITEMS_TLP           ICIT,
                         PO.PO_HEADERS_ALL CONTRATO_PAI
                   WHERE ICIB.RT_ITEM_ID = ICIP.RT_ITEM_ID
                     AND ICIB.SUPPLIER_PART_AUXID = CONTRATO_PAI.SEGMENT1   -- SEGMENT1 DO CONTRACT
                     AND ICIB.SUPPLIER            = PV.VENDOR_NAME          -- NOME DO FORNECEDOR
                     AND ICIB.SUPPLIER_PART_NUM   IN (SELECT PL.VENDOR_PRODUCT_NUM
                                                         FROM PO.PO_LINES_ALL PL
                                                       WHERE PL.PO_HEADER_ID = PHA.PO_HEADER_ID
                                                         AND PL.VENDOR_PRODUCT_NUM IS NOT NULL
                                                         AND NVL(PL.CANCEL_FLAG, 'N')= 'N')
                     AND ICIB.RT_ITEM_ID          = ICIT.RT_ITEM_ID
                     AND ICIT.LANGUAGE           = 'PTB'
                     AND CONTRATO_PAI.PO_HEADER_ID = PLA.CONTRACT_ID        -- PART NUMBER DO ITEM FORNECEDOR
                     ) END                                                         "PRAZO MAXIMO DE ENTREGA",
       ---
       --PDA.DISTRIBUTION_NUM                                                        "NUMERO_DISTRIBUICAO",
       GCC.SEGMENT1                                                                "CODIGO_EMPRESA",
       GCC.SEGMENT2                                                                "UNIDADE_CONTROLE",
       GCC.SEGMENT3                                                                "CONTA_CONTABIL",
       GCC.SEGMENT4                                                                "CENTRO_DE_CUSTO",
       PPA.SEGMENT1                                                                "NUMERO_PROJETO",
       ---
       (SELECT PAPF.ATTRIBUTE7 || PAPF.ATTRIBUTE8 || '-' || PAPF.LAST_NAME
          FROM APPS.PER_ALL_PEOPLE_F  PAPF,
               APPS.PO_ACTION_HISTORY PAH
         WHERE PAPF.EFFECTIVE_END_DATE(+) > SYSDATE
           AND PAPF.PERSON_ID(+)          = PAH.EMPLOYEE_ID
           AND PAH.SEQUENCE_NUM           =
               (SELECT MAX(P.SEQUENCE_NUM)
                  FROM APPS.PO_ACTION_HISTORY P
                 WHERE P.ACTION_CODE      = PAH.ACTION_CODE
                   AND P.OBJECT_TYPE_CODE = PAH.OBJECT_TYPE_CODE
                   AND P.OBJECT_ID        = PAH.OBJECT_ID)
           AND PAH.ACTION_CODE       = 'APPROVE'
           AND PAH.OBJECT_TYPE_CODE  = 'RELEASE'
           AND PAH.OBJECT_ID         = PRA.PO_RELEASE_ID
           AND ROWNUM                = 1)                                          "APROVADOR"
  -----
  FROM PO.PO_HEADERS_ALL               PHA,
       PO.PO_LINES_ALL                 PLA,
       PO.PO_LINE_LOCATIONS_ALL        PLLA,
       PO.PO_DISTRIBUTIONS_ALL         PDA,
       PO.PO_RELEASES_ALL              PRA,
       GL.GL_CODE_COMBINATIONS         GCC,
       APPS.PA_PROJECTS_ALL            PPA,
       APPS.MTL_CATEGORIES             MC,
       PO.PO_VENDORS                   PV,
       APPS.PO_VENDOR_SITES_ALL        PVSA,   
       REC.REC_INVOICE_LINES           RIL,
       REC.REC_INVOICES                RI,
       REC.REC_ENTRY_OPERATIONS        REO,
       APPS.REC_INVOICE_TYPES          RIT,         
       (SELECT * 
         FROM APPS.FND_LOOKUP_VALUES LV 
        WHERE LV.LOOKUP_TYPE = 'RCV_ROUTING_HEADERS' 
          AND LANGUAGE       = 'PTB')  RRH
 -----
 WHERE PHA.TYPE_LOOKUP_CODE       IN ('BLANKET', 'PLANNED')
   AND PHA.PO_HEADER_ID            = PLA.PO_HEADER_ID
   AND PLA.PO_LINE_ID              = PLLA.PO_LINE_ID  
   AND PLLA.LINE_LOCATION_ID       = PDA.LINE_LOCATION_ID
   AND PDA.CODE_COMBINATION_ID     = GCC.CODE_COMBINATION_ID
   AND PDA.PROJECT_ID              = PPA.PROJECT_ID       (+)
   AND PLA.CATEGORY_ID             = MC.CATEGORY_ID
   AND MC.SEGMENT1            NOT IN ('SE', 'SV')
   AND PLLA.PO_RELEASE_ID          = PRA.PO_RELEASE_ID          
   AND PLLA.LINE_LOCATION_ID       = RIL.LINE_LOCATION_ID (+)
   AND PLLA.RECEIVING_ROUTING_ID   = RRH.LOOKUP_CODE      (+)
   AND RIL.INVOICE_ID              = RI.INVOICE_ID        (+)
   AND RI.ORGANIZATION_ID          = REO.ORGANIZATION_ID  (+)
   AND RI.OPERATION_ID             = REO.OPERATION_ID     (+)
   AND PHA.VENDOR_ID               = PVSA.VENDOR_ID       (+)
   AND PHA.VENDOR_SITE_ID          = PVSA.VENDOR_SITE_ID  (+)
   AND PHA.VENDOR_ID               = PV.VENDOR_ID         (+)
   ---
   AND NOT EXISTS
       (SELECT DISTINCT '1'
          FROM PO.PO_REQUISITION_LINES_ALL PRLA
         WHERE PLLA.LINE_LOCATION_ID = PRLA.LINE_LOCATION_ID) -- FILTRA OC SEM REQ
   ---
   AND PHA.AUTHORIZATION_STATUS   IN ('APPROVED')
   AND REO.REVERSION_FLAG         IS NULL
   AND RI.INVOICE_TYPE_ID          = RIT.INVOICE_TYPE_ID        (+)
   AND RI.ORGANIZATION_ID          = RIT.ORGANIZATION_ID        (+)
   AND (
           RI.INVOICE_ID IS NULL
           OR
           (RI.INVOICE_ID IS NOT NULL AND RI.INVOICE_NUM >0 AND NVL(RIT.PARENT_FLAG, 'N') = 'N')
       ) 
   --      
   AND  PRA.APPROVED_DATE    BETWEEN TO_DATE(:Data_Inicial ||' 00:00:00', 'DD/MM/YYYY HH24:MI:SS')
                                 AND TO_DATE(:Data_Final ||' 23:59:59', 'DD/MM/YYYY HH24:MI:SS')