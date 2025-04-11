/* =============================================================================
  SCRIPT:        RI_NFE_ABERTURA_BKO.sql
  DESCRI??O:     Consulta anal?tica para identificar dados completos do RI
                 e informa??es da NFEE, com foco na an?lise da data m?nima de
                 vencimento de recebimentos e restri??es no m?dulo BKO.

  OBJETIVO:      Atender demanda funcional do m?dulo PO - Compras, relacionada
                 ? verifica??o de:
                 - Datas de vencimento das notas recebidas no RI
                 - Fechamento de permiss?es de recebimento via m?dulo BKO

  ESCOPOS:
                 - Integra??o entre RI e XML (NFEE)
                 - Detalhamento de roteiros, fornecedores, impostos e reten??es
                 - Indicadores de tipo de nota, inspe??o, distribui??o e status

  M?DULO:        Oracle EBS ? PO / RI / NFEE
  ?REA:          Compras / Recebimento
  PORTF?LIO:     ORACLE_EBS
  AUTOR:         Adoniran Paim
  DATA:          abril/2025
============================================================================= */

SELECT DISTINCT
       -------------------------------------- DADOS NFEE ----------------------
							(SELECT DISTINCT OOD.ORGANIZATION_CODE
					|| ' - '
					|| OOD.ORGANIZATION_NAME NOME_OI
				FROM apps.org_organization_definitions ood
				WHERE OOD.ORGANIZATION_ID = nhx.organization_id
				) LOCAL_RECEBIMENTO               ,
				nhx.cnpj_dest CNPJ_DESTINATARIO   ,
				nhx.TIPO_NF                       ,
				nhx.natop NATU_OPERA              ,
				nhx.nome_emit FORNECEDOR          ,
				nhx.cnpj_emit CNPJ_EMIT           ,
				nhx.nnf NNF                       ,
				nhx.file_type TIPO_DOCUMENTO      ,
				nhx.vlr_tot_nfe VALOR_TOTAL_NF    ,
				nhx.demi DATA_EMISSAO_NF          ,
				nhx.status||' - '|| nhx.status_sefaz STATUS_NFEE ,
				nhx.chave CHAVE                   ,
				nlx.cprod CODIGO_XML_LINHA        ,
				nlx.xprod DESCRICAO_XML_LINHA     ,
			 -------------------------------------- DADOS CABEÇALHO ----------------------
       REO.RECEIVE_DATE                                                             DT_RI,
       REO.GL_DATE                                                                  DT_GL,
       REO.LAST_UPDATE_DATE                                                         DT_ULTIMA_ALTERAÇÃO_RI,
       REO.OPERATION_ID                                                             RI,
       REO.STATUS                                                                   STATUS_RI,
       RLC.DESCRIPTION                                                              FRETE,
       MP.ORGANIZATION_CODE                                                         OI,
       HL.LOC_INFORMATION14                                                         CNPJ_OI,
       RFEA.DOCUMENT_NUMBER                                                         CNPJ,
       PV.VENDOR_NAME                                                               FORNECEDOR,
       RI.INVOICE_NUM                                                               NF,
       RI.SERIES                                                                    SÉRIE,
       -----
       (SELECT DISTINCT RS.STATE_CODE
          FROM APPS.CLL_F189_STATES  RS
         WHERE RS.STATE_ID = RI.SOURCE_STATE_ID
       )                                                                            UF_RETIRADA,
       -----
       (SELECT DISTINCT RS.STATE_CODE
          FROM APPS.CLL_F189_STATES  RS
         WHERE RS.STATE_ID = RI.DESTINATION_STATE_ID
       )                                                                            UF_ENTREGA,
       -----
       FU.USER_NAME 		                                                            CRIADO_POR_MATRICULA,
       FU.DESCRIPTION 	                                                            CRIADO_POR_NOME,
       RI.ISS_BASE,
       RI.ISS_TAX,
       RI.ISS_AMOUNT,
       RI.INSS_BASE,
       RI.INSS_TAX,
       RI.INSS_AMOUNT,
       RI.IR_BASE,
       RI.IR_TAX,
       RI.IR_AMOUNT,
       -----
       (SELECT (NVL(RD.FUNCTIONAL_DR,(RD.FUNCTIONAL_CR*-1)))    
          FROM APPS.CLL_F189_DISTRIBUTIONS RD
         WHERE REO.ORGANIZATION_ID = RD.ORGANIZATION_ID 
           AND REO.OPERATION_ID    = RD.OPERATION_ID    
           AND REO.LOCATION_ID     = RD.LOCATION_ID     
           AND RD.REFERENCE        = 'PIS RECUP'
       )                                                                           VALOR_PIS_A_RECUPERAR,
       -----
       (SELECT (NVL(RD.FUNCTIONAL_DR,(RD.FUNCTIONAL_CR*-1)))    
          FROM APPS.CLL_F189_DISTRIBUTIONS RD
         WHERE REO.ORGANIZATION_ID = RD.ORGANIZATION_ID 
           AND REO.OPERATION_ID    = RD.OPERATION_ID    
           AND REO.LOCATION_ID     = RD.LOCATION_ID     
           AND RD.REFERENCE        = 'COFINS RECUP'
       )                                                                           VALOR_COFINS_A_RECUPERAR,
       -----
       RI.FISCAL_DOCUMENT_MODEL                                                    DOCUMENTO_FISCAL,
       RIT.INVOICE_TYPE_CODE                                                       TIPO_NF,
       RIT.DESCRIPTION                                                             DESC_TIPO_NF,
       RIT.PROJECT_FLAG                                                            TIPO_COM_PROJETO,
       RI.FIRST_PAYMENT_DATE                                                       lo_PAGTO,
       REO.ATTRIBUTE11                                                             FATO_GERADOR,
       RI.INVOICE_DATE                                                             DT_EMISSÃO,
       RI.GROSS_TOTAL_AMOUNT                                                       VALOR_BRUTO_NF,
       RI.INVOICE_AMOUNT                                                           VALOR_LIQUIDO_NF,
       RI.ICMS_BASE,
       RI.ICMS_TAX,
       RI.ICMS_AMOUNT,
       RI.IPI_AMOUNT,
       -----
       (SELECT RT.NAME
          FROM APPS.AP_TERMS RT
         WHERE RT.TERM_ID = RI.TERMS_ID
       )                                                                           TERMO_PAGTO_RI,
       -------------------------------------- DADOS LINHA ----------------------
       RIL.QUANTITY                                                                QTD_NF,
       -----
       (SELECT PH.SEGMENT1
          FROM   APPS.PO_HEADERS_ALL             PH
         WHERE PH.PO_HEADER_ID     = PLL.PO_HEADER_ID
       )                                                                           ORDEM_DE_COMPRA,
       -----
       (SELECT PH.TYPE_LOOKUP_CODE 
          FROM   APPS.PO_HEADERS_ALL             PH
         WHERE PH.PO_HEADER_ID     = PLL.PO_HEADER_ID
       )                                                                           TIPO_OC,
       -----
       (SELECT   PR.RELEASE_NUM
          FROM     APPS.PO_RELEASES_ALL  PR
         WHERE    PR.PO_RELEASE_ID     = PLL.PO_RELEASE_ID
       )                                                                           LIBERAÇÃO,
       -----
       (SELECT  PL.LINE_NUM
          FROM   APPS.PO_LINES_ALL               PL
         WHERE PL.PO_LINE_ID   = PLL.PO_LINE_ID
       )                                                                           LINHA_PO,
       -----
       GLC2.SEGMENT1 ||'.'||
       GLC2.SEGMENT2 ||'.'||
       GLC2.SEGMENT3 ||'.'||
       GLC2.SEGMENT4 ||'.'||
       GLC2.SEGMENT5 ||'.'||
       GLC2.SEGMENT6 ||'.'||
       GLC2.SEGMENT7                                                               CONTA_CONTAB_LINHA_RI,
       -----
       PLL.QUANTITY                                                                QTD_SOLICITADA,
       PLL.QUANTITY_BILLED                                                         QTD_FATURADA,
       PLL.QUANTITY_RECEIVED                                                       QTD_RECEBIDA,
       RFC.CLASSIFICATION_CODE                                                     CLASSIFICAÇÃO_FISCAL,
       PDA.DESTINATION_TYPE_CODE                                                   TIPO_DE_DESTINO,
       RFO.CFO_CODE                                                                CFO,
       RIL.OPERATION_FISCAL_TYPE                                                   NOP,
       -----
    /*   (SELECT RLC.DESCRIPTION
          FROM   APPS.rec_CODES RLC
         WHERE  RLC.LOOKUP_TYPE   = 'OPERATION FISCAL TYPE'
           AND  RLC.LOOKUP_CODE   = RIL.OPERATION_FISCAL_TYPE
       )                                                                           DESC_NOP,*/
       -----
       RIL.TRIBUTARY_STATUS_CODE                                                   STC,
       RIU.UTILIZATION_CODE                                                        UTILIZAÇÃO,
       -----
       (SELECT PPA.SEGMENT1      
          FROM   APPS.PA_PROJECTS_ALL             PPA
         WHERE  PPA.PROJECT_ID = PDA.PROJECT_ID
       )                                                                           PROJETO,
       -----
       (SELECT REPLACE(REPLACE(PPA.NAME,CHR(9),' '),CHR(13),' ')
          FROM APPS.PA_PROJECTS_ALL             PPA
         WHERE PPA.PROJECT_ID = PDA.PROJECT_ID
       )                                                                           NOME,
       -----
       (SELECT PPA.PROJECT_TYPE	    
          FROM APPS.PA_PROJECTS_ALL             PPA
         WHERE PPA.PROJECT_ID = PDA.PROJECT_ID
       )                                                                           TIPO_PROJETO,
       -----
       (SELECT PPA.PROJECT_STATUS_CODE   
          FROM APPS.PA_PROJECTS_ALL             PPA
         WHERE PPA.PROJECT_ID = PDA.PROJECT_ID
       )                                                                           STATUS_PROJETO,
       -----
       (SELECT PPA.ATTRIBUTE_CATEGORY 
          FROM APPS.PA_PROJECTS_ALL             PPA
         WHERE PPA.PROJECT_ID = PDA.PROJECT_ID
       )                                                                           CATEGORIA_PROJETO,
       -----
       PDA.EXPENDITURE_TYPE		                                                     TIPO_DESPESA,
       PDA.EXPENDITURE_ITEM_DATE                                                   Data_do_item_de_despesas,
       -----
       (SELECT PT.TASK_NUMBER 
          FROM APPS.PA_TASKS                 PT
         WHERE PT.TASK_ID = PDA.TASK_ID
       )                                                                           TAREFA,
       -----
       (SELECT MSI.SEGMENT1 
          FROM APPS.MTL_SYSTEM_ITEMS         MSI
         WHERE MSI.INVENTORY_ITEM_ID = RIL.ITEM_ID
           AND MSI.ORGANIZATION_ID   = RI.ORGANIZATION_ID
       )                                                                           CÓD_ITEM,
       -----
       (SELECT MSI.GLOBAL_ATTRIBUTE2 
          FROM APPS.MTL_SYSTEM_ITEMS         MSI
         WHERE MSI.INVENTORY_ITEM_ID = RIL.ITEM_ID
           AND MSI.ORGANIZATION_ID   = RI.ORGANIZATION_ID
       )                                                                           UTILIZAÇÃO_ITEM,
       -----
       REPLACE(REPLACE(REPLACE(NVL((SELECT MSI.DESCRIPTION
                                      FROM APPS.MTL_SYSTEM_ITEMS MSI
                                     WHERE MSI.INVENTORY_ITEM_ID = RIL.ITEM_ID
                                       AND MSI.ORGANIZATION_ID   = RI.ORGANIZATION_ID
       ), RIL.DESCRIPTION), CHR(10), ' '), CHR(9), ' '), CHR(13), ' ')             DESC_ITEM,
       -----
       RIL.UOM                                                                     UOM,
       RIL.UNIT_PRICE                                                              PREÇO_UNITÁRIO,
       RIL.OTHER_EXPENSES                                                          OUTRAS_DESPESAS,
       RIL.ICMS_BASE                                                               BASE_ICMS,
       RIL.ICMS_TAX                                                                ALIQ_ICMS,
       RIL.ICMS_AMOUNT                                                             VALOR_ICMS,
       --INDICADOR TRIBUTÁRIO DE ICMS
       RIL.ICMS_AMOUNT_RECOVER                                                     VALOR_DO_ICMS_RECUPERÁVEL,
       RIL.DIFF_ICMS_TAX                                                           ALÍQUOTA_DO_DIFF_ICMS,
       RIL.DIFF_ICMS_AMOUNT                                                        VAL_DIFF_ICMS,
       RIL.ICMS_ST_BASE                                                            BASE_CÁLCULO_ICMS_SUBST,
       RIL.ICMS_ST_AMOUNT                                                          VALOR_ICMS_SUBSTITUTO,
       RIL.ICMS_ST_AMOUNT_RECOVER                                                  VALOR_ICMS_SUBST_RECUP,
       -------------------------------------- DADOS CTRCS ----------------------
       TRANS.CONTRATO                                                              TRANSP_CONTRATO,
       TRANS.INVOICE_NUM                                                           TRANSP_CONHECIMENTO,
       TRANS.INVOICE_DATE                                                          TRANSP_DT_EMISSÃO_CONHEC,
       TRANS.INVOICE_TYPE_CODE                                                     TRANSP_COD_TIPO_NF,
       TRANS.DESCRIPTION                                                           TRANSP_DESC_TIPO_NF,
       TRANS.PESO                                                                  TRANSP_PESO,
       TRANS.DOCUMENT_NUMBER                                                       CNPJ_TRANSPORTADOR,
       TRANS.VENDOR_NAME                                                           TRANSPORTADOR,
       TRANS.FISCAL_DOCUMENT_MODEL                                                 TRANSP_ESPÉCIE,
       TRANS.SERIES                                                                TRANSP_SÉRIE,
       ---CFOP DO FRETE
       TRANS.STATE_CODE_RET                                                        TRANSP_UF_RETIRADA,
       TRANS.STATE_CODE_ENT                                                        TRANSP_UF_ENTREGA,
       TRANS.INVOICE_AMOUNT                                                        TRANSP_VALOR_FRETE,
       TRANS.ICMS_TYPE                                                             TRANSP_TIPO_ICMS,
       TRANS.ICMS_BASE                                                             TRANSP_ICMS_BASE,
       TRANS.ICMS_TAX                                                              TRANSP_ICMS_ALIQ,
       TRANS.ICMS_AMOUNT                                                           TRANSP_ICMS_VALOR,
       TRANS.NOP                                                                   TRANSP_NOP,
       RI.FIRST_PAYMENT_DATE                                                       DATA_VENCIMENTO,
       -----
       (SELECT RC2.CITY_CODE
          FROM APPS.CLL_F189_CITIES RC2
         WHERE RC2.CITY_ID = RI.ISS_CITY_ID
       )                                                                           CIDADE_ISS,
       -----
       RI.ISS_BASE                                                                 BASE_ISS,
       RI.ISS_TAX                                                                  ALIQ_ISS,
       RI.ISS_AMOUNT                                                               VALOR_ISS,
       -----
       (SELECT RLC.DESCRIPTION
          FROM   APPS.REC_LOOKUP_CODES RLC
         WHERE  RLC.LOOKUP_TYPE   = 'OPERATION FISCAL TYPE'
           AND  RLC.LOOKUP_CODE   = TRANS.NOP
       )                                                                           TRANSP_DESC_NOP,
       -----
       (SELECT PH.CREATION_DATE
          FROM   APPS.PO_HEADERS_ALL             PH
         WHERE PH.PO_HEADER_ID     = PLL.PO_HEADER_ID
       )                                                                           DATA_DA_CRIAÇÃO_PO,
       -----
       (SELECT  PL.TRANSACTION_REASON_CODE
          FROM   APPS.PO_LINES_ALL               PL
         WHERE PL.PO_LINE_ID   = PLL.PO_LINE_ID
       )                                                                           MOTIVO_DA_TRANSAÇÃO,
       -----
       (SELECT NAME
          FROM APPS.AP_AWT_GROUPS
         WHERE GROUP_ID = RIL.AWT_GROUP_ID
       )                                                                           WITHHOLDIN_TAX_GROUP, 
       -----
       DECODE(RIT.REQUISITION_TYPE
               , 'PO' ,NVL((SELECT DISTINCT 'SIM' 
                           FROM APPS.RCV_TRANSACTIONS RT
                           WHERE RT.PO_LINE_LOCATION_ID = RIL.LINE_LOCATION_ID
                             AND RT.TRANSACTION_TYPE  =  'DELIVER'
                           )
                    , 'NÃO' )
               , 'OE' ,NVL((SELECT DISTINCT 'SIM' 
                          FROM APPS.RCV_TRANSACTIONS RT
                          WHERE RT.REQUISITION_LINE_ID = RIL.REQUISITION_LINE_ID
                            AND RT.TRANSACTION_TYPE  =  'DELIVER' 
                          )
                    , 'NÃO' )
                ,RIT.REQUISITION_TYPE
                )                                                                  "DISTRIBUÍDO_NO_INV ?",
       -----
       FU2.USER_NAME                                                               ALTERADO_POR_MATRICULA,
       FU2.DESCRIPTION                                                             ALTERADO_POR_NOME,
       LIN_NFF.INVOICE_LINE_NUM                                                    LINHA_DA_NF,
       TP_FRETE.DESCRIPTION                                                        TIPO_FRETE,
       -----
       DECODE(SUBSTR(RIT.INVOICE_TYPE_CODE,1,3)
              , '006', DECODE(SUBSTR(RIT.DESCRIPTION,1,4)
                              ,'SERV', 'Nota de Serviço'
                                     , RIT.DESCRIPTION)
              , '002','Nota de Serviço'
              , '005','Nota de Serviço'
              , '007','Nota de Serviço'
              , 'Nota de Material' )                                               TIPO_NOTA,
       -----
       (SELECT RC.CITY_CODE
          FROM APPS.CLL_F189_CITIES RC 
         WHERE RC.CITY_ID = RI.ISS_CITY_ID
       )                                                                           CIDADE_EXEC_SERVIÇO,
       -----
       RBV.BUSINESS_CODE                                                           ESTABELECIMENTO_DO_FORNECEDOR,
       REPLACE(REPLACE(RI.DESCRIPTION,CHR(10),' '),CHR(13),' ')                    DESCRIÇÃO,
       PLL.PRICE_OVERRIDE                                                          PREÇO_LINHA_PO,
       RI.TERMS_DATE                                                               DATA_BASE,
       -----
       DECODE(PLL.RECEIVING_ROUTING_ID, 1, 'STANDARD RECEIPT', 
               DECODE(PLL.RECEIVING_ROUTING_ID, 2, 'INSPECTION REQUIRED', 
                                                   'DIRECT DELIVERY'))             ROTEIRO_DO_RECEBIMENTO
  --------------------
  FROM
        APPS.CLL_F189_ENTRY_OPERATIONS        REO
      , APPS.CLL_F189_INVOICES                RI
      , APPS.CLL_F189_INVOICE_LINES           RIL
      , APPS.CLL_F189_INVOICE_TYPES           RIT
      , APPS.MTL_PARAMETERS                   MP
      , APPS.CLL_F189_FISCAL_ENTITIES_ALL     RFEA
      , APPS.PO_VENDOR_SITES_ALL              PVSA
      , APPS.PO_VENDORS                       PV
      , APPS.FND_USER 		                    FU
      , APPS.REC_LOOKUP_CODES                 RLC
      , APPS.PO_LINE_LOCATIONS_ALL            PLL
      , APPS.PO_DISTRIBUTIONS_ALL             PDA
      , apps.Cll_F189_Fiscal_Class            RFC
      , APPS.CLL_F189_FISCAL_OPERATIONS       RFO
      , APPS.CLL_F189_ITEM_UTILIZATIONS       RIU
      , APPS.GL_CODE_COMBINATIONS             GLC2
      , APPS.HR_LOCATIONS                     HL
      , APPS.FND_USER                         FU2  
      , APPS.CLL_F189_BUSINESS_VENDORS        RBV
			, APPS.NFEE_HEADER_XML                  NHX
		  , APPS.NFEE_LINES_XML                   NLX
      , APPS.NFEE_PO_RELATIONS                NPR
      ---------------------------------------
      ,(SELECT DISTINCT 
               RFEA.DOCUMENT_NUMBER
              ,PV.VENDOR_NAME
              ,RFI.PO_HEADER_ID
              ,PHA.SEGMENT1    CONTRATO
              ,RFI.LOCATION_ID
              ,RFI.ORGANIZATION_ID
              ,RFI.OPERATION_ID 
              ,RFI.INVOICE_NUM
              ,RFI.SERIES
              ,RFI.INVOICE_DATE
              ,RFI.INVOICE_AMOUNT
              ,RFI.FISCAL_DOCUMENT_MODEL
              ,RSRET.STATE_CODE  STATE_CODE_RET
              ,RSENT.STATE_CODE  STATE_CODE_ENT
              ,RIT.INVOICE_TYPE_CODE
              ,RIT.DESCRIPTION
              ,RFI.ATTRIBUTE1 NOP
              ,RFI.ICMS_TYPE
              ,RFI.ICMS_BASE
              ,RFI.ICMS_TAX
              ,RFI.ICMS_AMOUNT
              ,RFI.TOTAL_FREIGHT_WEIGHT PESO
							
        --------------------
        FROM 
				      APPS.CLL_F189_FREIGHT_INVOICES    RFI
             ,APPS.CLL_F189_FISCAL_ENTITIES_ALL RFEA
             ,ap.Ap_Supplier_SITES_all          PVSA
             ,ap.Ap_Suppliers                   PV
             ,APPS.CLL_F189_STATES              RSRET
             ,APPS.CLL_F189_STATES              RSENT
             ,APPS.CLL_F189_INVOICE_TYPES       RIT
             ,APPS.PO_HEADERS_ALL               PHA
        --------------------
        WHERE RFI.ENTITY_ID       = RFEA.ENTITY_ID
          AND RFEA.VENDOR_SITE_ID = PVSA.VENDOR_SITE_ID
          AND PVSA.VENDOR_ID      = PV.VENDOR_ID
          AND RSRET.STATE_ID      = RFI.SOURCE_STATE_ID
          AND RSENT.STATE_ID      = RFI.DESTINATION_STATE_ID
          AND RFI.INVOICE_TYPE_ID = RIT.INVOICE_TYPE_ID
          AND RFI.ORGANIZATION_ID = RIT.ORGANIZATION_ID
          AND RFI.PO_HEADER_ID    = PHA.PO_HEADER_ID (+)
         ) TRANS
      ---------------------------------------
       ,(SELECT LINHAS.INVOICE_ID
               ,LINHAS.INVOICE_LINE_ID
               ,ROW_NUMBER() OVER (PARTITION BY LINHAS.INVOICE_ID 
                                       ORDER BY LINHAS.INVOICE_LINE_ID) "INVOICE_LINE_NUM"
           FROM APPS.CLL_F189_INVOICE_LINES LINHAS
        ) LIN_NFF
      ---------------------------------------
       ,(SELECT FLV.DESCRIPTION
               ,POH.PO_HEADER_ID 
               ,POH.SEGMENT1
           FROM PO.PO_HEADERS_ALL      POH
               ,APPS.FND_LOOKUP_VALUES FLV
               ,HR.HR_LOCATIONS_ALL_TL HRL1
               ,HR.HR_LOCATIONS_ALL_TL HRL2
         WHERE FLV.LOOKUP_TYPE  = 'FOB'  
           AND FLV.LOOKUP_CODE  = POH.FOB_LOOKUP_CODE
           AND FLV.LANGUAGE     = HRL1.LANGUAGE
           AND HRL1.LOCATION_ID = POH.SHIP_TO_LOCATION_ID 
           AND HRL1.LANGUAGE    = USERENV('LANG') 
           AND HRL2.LOCATION_ID = POH.BILL_TO_LOCATION_ID 
           AND HRL2.LANGUAGE    = USERENV('LANG') 
        )  TP_FRETE
  --------------------
 WHERE RBV.BUSINESS_ID              = RFEA.BUSINESS_VENDOR_ID 
   AND TP_FRETE.PO_HEADER_ID  (+)   = PLL.PO_HEADER_ID 
   AND LIN_NFF.INVOICE_ID           = RIL.INVOICE_ID
   AND LIN_NFF.INVOICE_LINE_ID      = RIL.INVOICE_LINE_ID
   AND REO.OPERATION_ID             = RI.OPERATION_ID
   AND REO.ORGANIZATION_ID          = RI.ORGANIZATION_ID
   AND RI.INVOICE_ID                = RIL.INVOICE_ID
   AND RI.INVOICE_TYPE_ID           = RIT.INVOICE_TYPE_ID
   AND RI.ORGANIZATION_ID           = RIT.ORGANIZATION_ID
   AND REO.ORGANIZATION_ID          = MP.ORGANIZATION_ID
   AND RI.ENTITY_ID                 = RFEA.ENTITY_ID
   AND RFEA.VENDOR_SITE_ID          = PVSA.VENDOR_SITE_ID
   AND PVSA.VENDOR_ID               = PV.VENDOR_ID
   AND REO.CREATED_BY			          = FU.USER_ID
   AND REO.FREIGHT_FLAG             = RLC.LOOKUP_CODE
   AND RIL.LINE_LOCATION_ID         = PLL.LINE_LOCATION_ID(+)
   AND PLL.LINE_LOCATION_ID         = PDA.LINE_LOCATION_ID(+)
   AND PLL.PO_HEADER_ID             = PDA.PO_HEADER_ID(+)
   AND PLL.PO_LINE_ID               = PDA.PO_LINE_ID(+)
   AND REO.ORGANIZATION_ID          = TRANS.ORGANIZATION_ID(+)
   AND REO.OPERATION_ID             = TRANS.OPERATION_ID(+)
   AND REO.LOCATION_ID              = TRANS.LOCATION_ID(+)
   AND FU.USER_ID                   = REO.CREATED_BY
   AND RIL.CLASSIFICATION_ID        = RFC.CLASSIFICATION_ID
   AND RIL.CFO_ID                   = RFO.CFO_ID
   AND RIL.UTILIZATION_ID           = RIU.UTILIZATION_ID
   AND RIL.DB_CODE_COMBINATION_ID   = GLC2.CODE_COMBINATION_ID(+)
   AND HL.INVENTORY_ORGANIZATION_ID = MP.ORGANIZATION_ID
   AND FU2.USER_ID                  = RIL.LAST_UPDATED_BY
	 AND nlx.header_id                = nhx.header_id
   AND npr.header_id                = nhx.header_id
   AND npr.line_location_id         = pll.line_location_id 
	 and RI.ELETRONIC_INVOICE_KEY     = nhx.chave
	 --and RFEA.DOCUMENT_NUMBER         = NHX.CNPJ_EMIT
	 --AND RI.INVOICE_NUM               = NHX.NNF
	 AND nhx.status                   = 'PROCESSADO'
   AND RLC.LOOKUP_TYPE              = 'CIF FOB FREIGHT'
   AND REO.STATUS                   <> 'INCOMPLETE'
	 AND NHX.DEMI > SYSDATE-5
  -- AND (REO.LAST_UPDATE_DATE        >= TO_DATE('25'||'/'||TO_CHAR(SYSDATE, 'MM/YYYY'), 'DD/MM/YYYY') AND 
  --      REO.LAST_UPDATE_DATE        <  SYSDATE + 0.9999)
  ORDER BY 1, MP.ORGANIZATION_CODE, 3     