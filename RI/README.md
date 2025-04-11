# Queries de Recebimento Integrado (RI)

Este diretório contém consultas SQL voltadas à análise funcional e técnica do módulo de **Recebimento Integrado (RI)** no Oracle EBS.

---

## 📌 Query principal

### `RI_SUPERVISAO_ANALITICA_V3.sql`

Consulta funcional detalhada com os seguintes recursos:

- Diagnóstico por linha de nota fiscal
- Identificação de pendências no RI
- Flags para recebimento, OC, item ativo, retenções e mais
- Sugestão automatizada de ação (via lógica condicional)
- Integração com NFEE e verificação de HOLD

### Tabelas envolvidas:

- `CLL_F189_ENTRY_OPERATIONS`, `CLL_F189_INVOICES`, `CLL_F189_INVOICE_LINES`
- `PO_LINE_LOCATIONS_ALL`, `PO_HEADERS_ALL`
- `RCV_TRANSACTIONS`, `MTL_SYSTEM_ITEMS`
- `AP_AWT_GROUPS`, `FND_LOOKUP_VALUES`, `CLL_F189_HOLDS`, `NFEE_HEADER_XML`

---

## 📎 Como usar

- Filtrar por `:RI` (operation_id) para analisar um RI específico
- Pode ser usada diretamente em ferramentas como TOAD, SQL Developer ou integrada a dashboards
- Ideal para análise de chamados, bloqueios ou inconsistências no processo de recebimento

---

## ✍️ Autor

Adoniran Paim  
Consultor Funcional Oracle EBS – SCM  
abril/2025
