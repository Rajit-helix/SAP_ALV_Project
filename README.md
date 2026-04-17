# ZKIRIT_SALES_ALV_REPORT — Custom SAP ABAP ALV Report

## Project Overview
This is a Real ABAP Development Scenario implementing a **Custom ALV Grid Report**
for Sales Order analysis in SAP SD (Sales & Distribution).

---

## Submission Details
| Field        | Value                          |
|--------------|-------------------------------|
| Program Name | ZKIRIT_SALES_ALV_REPORT        |
| Module       | SAP SD + ABAP                 |
| Tables Used  | VBAK, VBAP, VBUP, KNA1        |
| Transaction  | SE38 (ABAP Editor)            |

---

## Files Included

| File | Description |
|------|-------------|
| `ZKIRIT_SALES_ALV_REPORT.abap` | Main ABAP report program |
| `README.md` | This file |

---

## How to Run in SAP

### Step 1 — Open ABAP Editor
1. Log in to your SAP system
2. Run transaction **SE38**
3. Enter program name: `ZKIRIT_SALES_ALV_REPORT`
4. Click **Create**

### Step 2 — Enter Program Attributes
- Title: `Custom ALV Report – Sales Order Analysis`
- Type: `Executable Program`
- Status: `Test Program`
- Application: `SD`

### Step 3 — Copy and Activate
1. Paste the contents of `ZKIRIT_SALES_ALV_REPORT.abap`
2. Press **Ctrl+S** to save
3. Press **Ctrl+F3** to activate

### Step 4 — Execute
1. Press **F8** or go to **Program > Execute**
2. Fill the Selection Screen:
   - Sales Order No (optional)
   - Order Date range
   - Customer (optional)
   - Sales Org (optional)
   - Material (optional)
3. Press **Execute (F8)**

---

## Features
- **ALV Grid / List toggle** via radio button on selection screen
- **Double-click** on any row → opens VA03 (Display Sales Order)
- **Subtotals** per Sales Order on Quantity and Net Value
- **Zebra striping** for readability
- **Column width optimization** auto-enabled
- **Variant saving** — users can save their display preferences
- **Report header** showing date range, record count, printed-by info
- **Input validation** — from date cannot exceed to date

---

## Tables & Data Flow

```
VBAK (Sales Order Header)
     |
     +---> VBAP (Sales Order Items)   [joined on VBELN]
     |
     +---> VBUP (Item Status)         [joined on VBELN + POSNR]
     |
     +---> KNA1 (Customer Master)     [joined on KUNNR]
```

---

## Tech Stack
- **Language**: ABAP (Advanced Business Application Programming)
- **SAP Module**: SD (Sales & Distribution)
- **ALV Function**: REUSE_ALV_GRID_DISPLAY / REUSE_ALV_LIST_DISPLAY
- **SAP Tables**: VBAK, VBAP, VBUP, KNA1
- **Transaction**: SE38, VA03
