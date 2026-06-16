# Data Input — Working Notes

Phase 3 working document. Covers how outbreak data enters the tool.

The options under consideration (Google Sheets, REDCap, Microsoft Forms/SharePoint, built-in Shiny entry) are summarised in `docs/data-model.md`. This document contains a structured questionnaire to gather the requirements and contextual judgements needed to choose between them.

---

## Questionnaire

Complete each section. Guidance notes (in italics) explain what each answer implies for the decision — read them before answering if unsure.

---

### Section 1 — Organisational infrastructure

**1.1 Is REDCap available to your team, and if so, who administers it?**

_REDCap is the most robust option for relational data entry with audit trails. If your organisation has an instance and you have a project administrator available, it is likely the right choice regardless of other factors. If it exists but access requires a lengthy approval process, that may rule it out for rapid outbreak response._

Answer:No

---

**1.2 Do staff have access to Google Workspace (Google Sheets, Google Drive) on their work devices?**

_Many NHS devices block Google services or require a separate account. If Google is accessible and familiar to your team, it is the fastest option to stand up._

Answer:No

---

**1.3 Do staff have access to Microsoft 365 (SharePoint, Forms, Excel Online)?**

_Microsoft 365 is standard in most NHS contexts. If SharePoint is available and staff are confident with Excel, this option may be the path of least resistance even if it has weaker validation._

Answer: Yes

---

**1.4 Is there an IT team or technical colleague who could help configure a data collection system during an outbreak?**

_Some options (REDCap project build, Google Apps Script validation, Power Automate pipelines) require technical setup time. If no support is available, simpler options become more attractive._

Answer: yes, but I want a pre-designed form / line list

---

### Section 2 — Operational requirements

**2.1 How many people would be entering data concurrently at peak?**

_1–2 people: any option works. 3–5 people: Google Sheets or REDCap. More than 5: REDCap or built-in strongly preferred — Excel-based options become error-prone at scale._

Answer: 1-3

---

**2.2 Would data entry happen from a single location or across multiple sites (e.g. different hospitals or field teams)?**

_Multi-site entry increases the risk of duplicate or inconsistent records and strengthens the case for a platform with record locking and a shared lookup list for contexts._

Answer: Multiple sites, potentially multiple teams

---

**2.3 How quickly after the start of an outbreak would the tool need to be operational?**

_Google Sheets or a pre-prepared Excel template can be ready in hours. REDCap project build typically takes days. A built-in Shiny entry form would require weeks of development. If the tool needs to be usable from day one of an investigation, simpler wins._

Answer: hours

---

**2.4 Is this intended for a single outbreak, or as a reusable tool across future events?**

_A one-off investigation favours the fastest option. A reusable tool across multiple outbreaks or organisations justifies more investment in validation and a more robust platform._

Answer: reusable tool, ideally adaptable to different organisms

---

**2.5 Do data entry staff have reliable internet access during data entry?**

_All options except a locally-run Shiny app require internet. If field work happens in areas with poor connectivity, an offline-capable option is needed._

Answer: yes

---

### Section 3 — Information governance

**3.1 Is the data pseudonymised or identifiable?**

_If data includes names, addresses, or NHS numbers, the platform must meet NHS information governance requirements (DSPT, Data Security and Protection). Google Workspace and consumer tools may not be approved for identifiable data in your organisation without explicit IG sign-off._

Answer: I envisage that this tool will run using a subset of data from a larger line list dataset that will include PII. No PII should be necessary for the app (though may want to include case initials). To assist some elements of data input (I am thinking about the dates a case visited each context, for which a date range relevant to the onset date should be available, but also with flexibility to pick from suitable dates when onest date not known / asymptomatic)

---

**3.2 Has your organisation's IG or Caldicott lead approved the platforms you are considering for this type of data?**

_This is a binary gate for some options. Google Sheets and SharePoint may be approved for pseudonymised outbreak data in some trusts but not others. REDCap hosted on NHS infrastructure is typically approved._

Answer: sharepoint is approved for PII

---

**3.3 Is a formal audit trail required — i.e. a record of who entered or changed each data point and when?**

_Audit trails are required for some governance frameworks and can be important for legal or public inquiry purposes. REDCap provides this natively. Google Sheets has version history but it is not a formal audit log. Excel does not._

Answer: No

---

**3.4 Does the data need to remain within UK borders (data residency requirement)?**

_Google and Microsoft both offer UK data residency options, but this may need explicit configuration. REDCap on NHS servers satisfies this by default._

Answer: ideally yes (sharepoint is fine to use)

---

### Section 4 — Usability and staffing

**4.1 What is the typical technical confidence of the staff who will be entering data?**

_(e.g. comfortable with Excel, never used a database, confident with online forms)_

_Lower technical confidence favours a form-based interface (REDCap, Microsoft Forms) over a raw spreadsheet, where structural errors are easier to make._

Answer: basic excel level

---

**4.2 Who would be responsible for managing the contexts lookup list during an outbreak — adding new contexts as they are identified?**

_In all options, someone needs to add new contexts before case-context links can be recorded. This needs to be a named role with clear access. If it falls to whoever is available, a simpler shared list (e.g. a sheet tab or REDCap lookup instrument) is safer than a scripted dropdown._

Answer: staff with basic-intermediate data skills - a tool to enable editable validation categories for selected fields is required

---

**4.3 Who would be responsible for correcting data entry errors — and how would corrections be communicated?**

_Corrections in REDCap are tracked. In Google Sheets they overwrite silently unless tracked manually. This matters if data quality is audited or if the same data feeds other reports._

Answer: health protection practitioners. no formal process for reporting corrections. 

---

### Section 5 — Integration with existing systems

**5.1 What system holds the main outbreak linelist, and can it export structured data?**

_The network tool needs at minimum: case_id, onset_date, age_group, vaccination_status, case_status. If the linelist system can export these fields in a consistent format, the transfer step is simpler. If it is a free-text system or a paper form, a manual transcription step is unavoidable._

Answer:

--- currently use an excel file. Could also consider a sharepoint list which is starting to be used. 

**5.2 Are context names and types recorded anywhere in the existing linelist, or would they be entered fresh into this tool?**

_If contexts are already coded in the linelist (e.g. as exposure locations), there may be an opportunity to extract them automatically. If not, they will need to be entered manually into the network tool._

Answer: I would suggst context names are recorded in the main linelist spreadsheet, with relevant parts of tables / views of tables avaiable for import.

---

**5.3 Is there an existing data collection standard or template used by your team or region for outbreak investigation?**

_If so, it may be worth aligning the schema to that standard rather than designing from scratch, to reduce double-entry and enable comparisons across outbreaks._

Answer: there will be a main line list that contains a lot more data. I would ideally like to pull certain columns from that, but will need more data stored in other tables. 

---

### Section 6 — Development and maintenance capacity

**6.1 Is there R/Shiny development resource available to build a data entry interface within the app itself?**

_Option D (built-in Shiny entry) would give the tightest validation and the simplest user experience, but requires significant development effort — estimated several weeks for a robust implementation with SQLite backend, form validation, and conflict handling._

Answer: if this is something that can be expeidted with the assistance of claude code, then yes. simple is good, but it needs to meet organisational IT requirements - assume the person developing the model does not have admin rights. 

---

**6.2 If an external tool (REDCap, Sheets, SharePoint) is used, who would maintain it between outbreaks and update it if the schema changes?**

_Schema changes (e.g. adding a new field to cases) would need to be reflected in the data collection tool. Without a named maintainer, the tool and schema can drift apart._

Answer: The database would be managed by a team with good data science and management skills. 

---

**6.3 Would you want to be able to use this tool without any technical support during an active outbreak?**

_This is a strong argument for simplicity. The best option on paper is not useful if it requires a developer to be on call to fix it during an investigation._

Answer: there can be brief technical input to get it up and running quickly, and intermittend technical input during the course of the outbreak to tweak, but would want this to be reasonably simple, not massive development work. The people routinely using the tool and adding the data will not be technical

---

### Section 7 — Summary judgement

**7.1 Which options are ruled out by hard constraints (IG, access, timeline)?**

- **Option A (Google Sheets):** Ruled out — no Google Workspace access on work devices.
- **Option B (REDCap):** Ruled out — not available in the organisation.
- **Option C (Microsoft Forms + SharePoint) as a full solution:** Ruled out for this data model. Microsoft Forms is designed for flat surveys, not relational data. It cannot enforce foreign key integrity (e.g. requiring a case to exist before case-context links are created), cannot handle multiple visit dates per case-context combination cleanly, and cannot manage an editable lookup list for context types. A Power Automate pipeline to maintain the five-table schema would be fragile and require ongoing technical maintenance. SharePoint as a *component* (see 7.3) remains viable.

---

**7.2 Which option best balances your operational requirements and available resource?**

The answers point toward **Option D (built-in Shiny data entry)** as the target state, with a **staged approach** to get there (see 7.3).

The core reasons:

- The data model is relational (5 linked tables, FK integrity, editable context type dropdown, multiple visit dates per case-context). No off-the-shelf form tool handles this well without significant scripting that would be harder to maintain than the Shiny app itself.
- The requirement for smart date suggestions based on onset date (3.1) is straightforward to implement in Shiny but would require complex logic in any external form tool.
- The requirement for the tool to be adaptable to different organisms (2.4) is already partially met by the editable parameters — extending this to schema changes is easier in a single codebase.
- No admin rights are needed to run a local Shiny app. Development with Claude Code significantly reduces the effort involved.
- The data science team available for maintenance (6.2) can manage a Shiny/R codebase.

The main open risk is **multi-site simultaneous access** — see open questions below.

---

**7.3 Are there any hybrid approaches worth considering?**

Yes. A two-stage approach is recommended:

**Stage 1 — SharePoint export template (short-term, ready in hours/days)**

Build a pre-designed Excel template or SharePoint List structure that matches the five-table schema exactly. Cases are pulled (manually or via copy-paste) from the existing linelist; the network-specific tables (case_contexts, visit_dates, contacts) are entered directly. The Shiny app reads from this file via a file import mechanism. This requires restoring a limited form of file upload to the app (removed in a recent commit — see open questions).

This stage satisfies the "operational in hours" requirement and works within existing SharePoint approval.

**Stage 2 — Built-in Shiny data entry (medium-term)**

Once the tool has been used in a real outbreak and requirements are better understood, build data entry forms directly into the Shiny app with a SQLite or CSV backend stored on a shared network location or SharePoint document library. This eliminates the export/import step, enforces validation at entry, and enables the smart date-range suggestions described in 3.1.

---

## Deployment comparison

Two architectures are compared below, based on whether Posit Connect is available.

---

### Solution 1 — Posit Connect (centrally hosted)

**How it works**

The Shiny app is deployed to a Posit Connect server (either NHS-hosted or Posit's cloud). All users access it via a URL in their browser — no R installation required on their machine. Data entered through the app is written to a persistent backend: either a SQLite database or a SharePoint List accessed via the Microsoft Graph API.

```
[User browser] --> [Posit Connect server]
                        |
                   [Shiny app (R)]
                        |
              [SQLite / SharePoint List]
                  (persistent data)
```

**What is needed to set it up**

- Posit Connect instance provisioned by IT (one-off)
- App deployed from RStudio using the `rsconnect` package (no admin rights on local machine needed)
- If using SharePoint as the data backend: Azure AD app registration to allow the Shiny app to read/write SharePoint Lists (one-off IT task)
- If using SQLite: a persistent storage volume on the Connect server (IT configuration)

**Multi-site access**

Native. Any user with the URL and appropriate credentials can access the app simultaneously. Record-level locking or last-write-wins behaviour for the data backend should be considered for concurrent editing.

**Information governance**

Must be NHS-hosted instance (UK data residency required — Posit Connect Cloud is US-based and is ruled out). UK data residency confirmed for NHS-hosted Connect.

**Data entry flow**

1. Health protection practitioner opens the app URL in their browser
2. Enters cases, contexts, visits, and contacts directly in the app
3. Data written immediately to the shared backend
4. Network diagram and epi curve update in real time for all users

**Maintenance**

Schema or feature changes: developer pulls changes in RStudio, clicks "Republish" — live within seconds, no downtime. No action needed from users.

**Development effort**

Moderate. The data entry forms, validation logic, and backend read/write need to be built (Phase 3 scope). The hosting infrastructure is handled by Connect.

**Key risks**

| Risk | Mitigation |
|---|---|
| Posit Connect not available or slow to procure | Start with Stage 1 (SharePoint template); migrate when Connect is available |
| Concurrent writes corrupting data | Use row-level locking or a proper database backend (PostgreSQL) rather than SQLite |
| SharePoint API access not approved | Use SQLite on Connect server instead |

---

### Solution 2 — Locally run (no central server)

**How it works**

The Shiny app runs on one designated person's machine (the "operator"). Data is stored as a set of CSV files or a SQLite database on a SharePoint document library (accessed as a mapped drive or via OneDrive sync). Other team members share data by editing the same files on SharePoint, coordinating with the operator to avoid conflicts. The operator refreshes the app to see updates.

```
[Operator's machine]
  R + Shiny app
       |
  [SQLite / CSV files]
       |
  [SharePoint document library]  <-- other team members edit files here
  (synced via OneDrive)
```

**What is needed to set it up**

- R and RStudio installed on the operator's machine (no admin rights needed if R is already installed)
- Shared SharePoint document library accessible to all team members
- OneDrive sync or mapped drive so the app can read/write the data files
- A clear protocol for who edits what and when (to prevent conflicts)

**Multi-site access**

Not simultaneous. Only the operator can run the app and see the live network diagram. Other sites contribute data by editing shared files on SharePoint, which the operator loads into the app. This is a significant constraint for multi-team investigations.

Mitigation options:
- Designate one person per outbreak as the data operator
- Other sites submit data via a simple structured Excel template that the operator imports
- The operator shares their screen during team meetings for live network review

**Information governance**

Data stays within SharePoint (already approved for PII). UK data residency confirmed. No third-party cloud services involved.

**Data entry flow**

1. Field teams enter data into a structured Excel template on SharePoint
2. Operator imports the file into the app via file upload
3. Operator reviews network diagram and shares view with team (screen share or exported image)
4. Corrections are made in the source files and re-imported

**Maintenance**

Developer pushes updates to GitHub. Operator does `git pull` in RStudio and restarts the app. Straightforward but manual.

**Development effort**

Lower than Solution 1 — no deployment infrastructure to manage. App remains a visualisation tool with a well-defined import format. Data entry forms are optional.

**Key risks**

| Risk | Mitigation |
|---|---|
| Operator's machine unavailable during outbreak | Pre-install R on a second machine; keep the app deployable in minutes via GitHub |
| Conflicting edits to shared data files | Clear protocol: one person owns each table; use SharePoint version history to recover |
| Operator bottleneck slows data entry | Keep the import format simple so field teams can self-serve; operator role is review not entry |
| App not accessible to remote team members for live review | Use screen sharing (Teams) for group sessions |

---

### Side-by-side comparison

| | Solution 1 (Posit Connect) | Solution 2 (Local) |
|---|---|---|
| **Multi-site simultaneous access** | Yes | No — operator model only |
| **Real-time collaboration** | Yes | No |
| **Admin rights needed** | No (once Connect is provisioned) | No |
| **IT involvement** | Yes — to provision Connect | Minimal — shared drive setup only |
| **Data residency** | NHS-hosted Connect only (Posit Cloud ruled out) | Yes (SharePoint, NHS M365) |
| **Development effort** | Moderate (forms + backend + deploy) | Lower (forms optional; import-based) |
| **Time to first use** | Days to weeks (depends on Connect provisioning) | Hours to days |
| **Ongoing maintenance** | Click to redeploy | Git pull + restart |
| **Suitable for reuse across outbreaks** | Yes | Yes, with caveats |
| **Suitable for multi-team investigations** | Yes | With coordination overhead |

---

## Open questions before finalising the decision

**Q1 — 3.4 Data residency (not answered)**
Is there a requirement for data to remain within UK borders? SharePoint via Microsoft 365 is UK-hosted by default in NHS tenants, so Stage 1 is likely fine. Confirm with your IG lead if uncertain.

Yes must stay in UK

**Q2 — Multi-site simultaneous access**
When you say "multiple sites, potentially multiple teams" (2.2), does this mean multiple people need to enter data *at the same time* from different physical locations? If yes:
- Stage 1 (SharePoint template) handles this natively — SharePoint is cloud-hosted.
- Stage 2 (built-in Shiny) requires the app to be hosted somewhere accessible to all sites (e.g. shinyapps.io, Posit Connect, or an internal server). A locally-run Shiny app only works for the person running it on their machine. This is the most significant architectural constraint for Option D and needs a deployment decision before Stage 2 is designed.

Yes people will need to enter data at the same time. Fine to do two stage

**Q3 — File upload**
The file upload function was removed from the app in a recent commit. Stage 1 of the hybrid approach requires it back — in a simpler form (import a fixed-schema Excel file). Should this be restored as part of Stage 1 development, or is the intent to move directly to built-in data entry and skip Stage 1?

restore it 
---

## Decision

**Chosen option: Two-stage hybrid**

- **Stage 1 (immediate):** SharePoint-based Excel template matching the five-table schema, imported into the Shiny app via restored file upload. Operational within hours. Handles simultaneous multi-site data entry natively (SharePoint is cloud-hosted). Satisfies UK data residency requirement.
- **Stage 2 (target state):** Built-in Shiny data entry with a persistent backend, hosted on NHS-hosted Posit Connect. Posit Connect Cloud is ruled out (US servers, fails UK data residency). Stage 2 is conditional on Posit Connect being procured and provisioned.

**Rationale**

- REDCap and Google Sheets are unavailable. Microsoft Forms cannot handle the relational data model.
- Simultaneous multi-site entry is required, which a locally-run Shiny app cannot support. Stage 1 resolves this using SharePoint's native cloud access; Stage 2 resolves it via Posit Connect.
- UK data residency is required. SharePoint (NHS M365) satisfies this for Stage 1. For Stage 2, only an NHS-hosted Posit Connect instance is acceptable — shinyapps.io and Posit Connect Cloud are ruled out.
- The file upload function (recently removed from the app) must be restored for Stage 1.
- Built-in data entry remains the long-term goal: tighter validation, smart date suggestions based on onset date, no export/import step, and a single interface for data entry and visualisation. Development with Claude Code makes this feasible without a large team.
- Stage 1 and Stage 2 use the same data schema — migration between stages requires no redesign.

**Outstanding actions before first use**

1. **Restore file upload in the Shiny app** — limited to the fixed five-table schema; validate on import
2. **Design the Stage 1 Excel template** — one sheet per table, column names matching the schema exactly, with dropdown validation for fixed fields (age_group, vaccination_status, case_status, link_type) and a contexts lookup sheet for context_type
3. **Write a brief data entry guide** — one page covering the five tables, required fields, and how to export from the template into the app
4. **Investigate Posit Connect availability** — ask IT whether the organisation has or can procure an NHS-hosted Posit Connect instance; this gates Stage 2
5. **Confirm IG sign-off for Stage 2 hosting** — once a hosting platform is identified, confirm with IG/Caldicott lead before any real outbreak data is stored there



## Requirements for excel input file

### Data validation

| Requirement | Status | Implementation |
|---|---|---|
| Date fields must be real dates, DD/MM/YYYY format | Done | `type = "date"` validation on `onset_date` and `visit_date`; cells formatted DD/MM/YYYY |
| Count/ID fields must be integers | Done | `type = "whole"` validation on `context_id` in the contexts sheet |
| Categorical fields must enforce fixed values | Done | Dropdown (`type = "list"`) on `age_group`, `vaccination_status`, `case_status`, `link_type` |
| Linkage tables must only accept IDs that exist in cases/contexts | Done | `type = "list"` dropdown in case_contexts, visit_dates, and contacts referencing `cases!$A$2:$A$2000` and `contexts!$A$2:$A$2000`. Fill cases and contexts first. Also enforced by the app on upload. |

### UIDs

Auto-generated incrementally when a new row is added. Formats:

| Field | Format | Example |
|---|---|---|
| `case_id` | `C-nnn` (zero-padded, starting at 001) | C-001, C-002, C-003 |
| `context_id` | `Ctxt-nnn` (zero-padded, starting at 001) | Ctxt-001, Ctxt-002, Ctxt-003 |

| Requirement | Status | Implementation |
|---|---|---|
| case_id auto-increments as C-001, C-002 … | Not done | Requires Excel formula or VBA in the template; not yet implemented |
| context_id auto-increments as Ctxt-001, Ctxt-002 … | Not done | Requires Excel formula or VBA in the template; not yet implemented |
| case_id format enforced (C-nnn) | Not done | Could be added as `type = "custom"` validation but not supported in openxlsx 4.2.8.1 |
| context_id format enforced (Ctxt-nnn) | Not done | Same constraint as above |

> **Note:** auto-increment in a static Excel file requires either an Excel formula referencing the row above, or a VBA macro. A formula approach (e.g. `=IF(B2="","","C-"&TEXT(ROW()-1,"000"))`) can be pre-filled in the template but requires the user not to overwrite it. VBA macros add complexity and may be blocked by NHS IT policy. To be decided.

### Formatting

| Requirement | Status | Implementation |
|---|---|---|
| Sheets formatted as named Excel tables | Not done | `openxlsx::addTable()` can create named tables; table names to match schema (cases, contexts, case_contexts, visit_dates, contacts) |

---
