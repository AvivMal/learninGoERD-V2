<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>LearninGo — Full Database ERD</title>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
<style>
  :root {
    --bg:          #0d1117;
    --surface:     #161b22;
    --border:      #30363d;
    --text:        #c9d1d9;
    --text-muted:  #8b949e;
    --sidebar-w:   260px;
    --zA-h:#1d4ed8; --zA-b:#0f2044; --zA-t:#93c5fd;
    --zB-h:#059669; --zB-b:#052e1c; --zB-t:#6ee7b7;
    --zC-h:#7c3aed; --zC-b:#2e1065; --zC-t:#c4b5fd;
    --zD-h:#b45309; --zD-b:#2d1b00; --zD-t:#fcd34d;
    --zE-h:#0891b2; --zE-b:#082f3e; --zE-t:#67e8f9;
    --zF-h:#be185d; --zF-b:#3b0d24; --zF-t:#f9a8d4;
    --zG-h:#374151; --zG-b:#111827; --zG-t:#9ca3af;
  }
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; display: flex; flex-direction: column; height: 100vh; overflow: hidden; }
  header { flex-shrink: 0; background: var(--surface); border-bottom: 1px solid var(--border); padding: 12px 20px; display: flex; align-items: center; gap: 16px; z-index: 10; }
  header h1 { font-size: 16px; font-weight: 600; color: #e6edf3; letter-spacing: .3px; }
  header .meta { font-size: 12px; color: var(--text-muted); }
  header .badge { background: #21262d; border: 1px solid var(--border); border-radius: 20px; padding: 2px 10px; font-size: 11px; color: var(--text-muted); }
  .spacer { flex: 1; }
  .ctrl-btn { background: #21262d; border: 1px solid var(--border); color: var(--text); border-radius: 6px; padding: 5px 11px; font-size: 12px; cursor: pointer; transition: background .15s; }
  .ctrl-btn:hover { background: #30363d; }
  .layout { flex: 1; display: flex; overflow: hidden; }
  aside { width: var(--sidebar-w); flex-shrink: 0; background: var(--surface); border-right: 1px solid var(--border); overflow-y: auto; display: flex; flex-direction: column; }
  .sidebar-header { padding: 14px 16px 10px; font-size: 11px; font-weight: 600; letter-spacing: .8px; color: var(--text-muted); text-transform: uppercase; border-bottom: 1px solid var(--border); }
  .zone-section { border-bottom: 1px solid var(--border); }
  .zone-header { display: flex; align-items: center; gap: 8px; padding: 9px 14px; cursor: pointer; transition: background .12s; user-select: none; }
  .zone-header:hover { background: #21262d; }
  .zone-header.active { background: #161b22; }
  .zone-dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
  .zone-name { font-size: 12px; font-weight: 500; flex: 1; }
  .zone-count { font-size: 11px; color: var(--text-muted); background: #21262d; border-radius: 10px; padding: 1px 7px; }
  .zone-tables { display: none; padding: 4px 14px 8px 30px; flex-direction: column; gap: 3px; }
  .zone-tables.open { display: flex; }
  .table-item { font-size: 11px; color: var(--text-muted); padding: 3px 6px; border-radius: 4px; cursor: pointer; font-family: 'Courier New', monospace; transition: all .12s; }
  .table-item:hover { background: #21262d; color: var(--text); }
  .table-item.highlighted { background: #1f3a5f; color: #93c5fd; }
  .sidebar-footer { margin-top: auto; padding: 12px 14px; font-size: 10px; color: #444d56; border-top: 1px solid var(--border); }
  .diagram-wrap { flex: 1; overflow: auto; position: relative; background: var(--bg); }
  #diagram-container { padding: 32px; min-width: max-content; transform-origin: top left; transition: transform .1s; }
  .mermaid svg { background: var(--bg) !important; border-radius: 8px; }
  .legend-bar { flex-shrink: 0; background: var(--surface); border-top: 1px solid var(--border); padding: 8px 20px; display: flex; gap: 20px; flex-wrap: wrap; align-items: center; }
  .legend-item { display: flex; align-items: center; gap: 6px; font-size: 11px; color: var(--text-muted); cursor: pointer; transition: color .12s; }
  .legend-item:hover, .legend-item.active { color: var(--text); }
  .legend-pip { width: 10px; height: 10px; border-radius: 2px; flex-shrink: 0; }
  .zone-A-entity .entityBox { fill: var(--zA-b) !important; stroke: var(--zA-h) !important; }
  .zone-A-entity .entityLabel { fill: var(--zA-t) !important; }
  .zone-B-entity .entityBox { fill: var(--zB-b) !important; stroke: var(--zB-h) !important; }
  .zone-B-entity .entityLabel { fill: var(--zB-t) !important; }
  .zone-C-entity .entityBox { fill: var(--zC-b) !important; stroke: var(--zC-h) !important; }
  .zone-C-entity .entityLabel { fill: var(--zC-t) !important; }
  .zone-D-entity .entityBox { fill: var(--zD-b) !important; stroke: var(--zD-h) !important; }
  .zone-D-entity .entityLabel { fill: var(--zD-t) !important; }
  .zone-E-entity .entityBox { fill: var(--zE-b) !important; stroke: var(--zE-h) !important; }
  .zone-E-entity .entityLabel { fill: var(--zE-t) !important; }
  .zone-F-entity .entityBox { fill: var(--zF-b) !important; stroke: var(--zF-h) !important; }
  .zone-F-entity .entityLabel { fill: var(--zF-t) !important; }
  .zone-G-entity .entityBox { fill: var(--zG-b) !important; stroke: var(--zG-h) !important; }
  .zone-G-entity .entityLabel { fill: var(--zG-t) !important; }
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: #30363d; border-radius: 3px; }
</style>
</head>
<body>
<header>
  <h1>LearninGo — Entity Relationship Diagram</h1>
  <span class="meta">Full Database Schema</span>
  <span class="badge">32 tables</span>
  <span class="badge">7 zones</span>
  <div class="spacer"></div>
  <button class="ctrl-btn" onclick="resetZoom()">Fit</button>
  <button class="ctrl-btn" onclick="zoomBy(1.2)">+</button>
  <button class="ctrl-btn" onclick="zoomBy(0.8)">−</button>
  <button class="ctrl-btn" id="clearBtn" onclick="clearFilter()" style="display:none">✕ Clear</button>
</header>
<div class="layout">
  <aside>
    <div class="sidebar-header">Zones &amp; Tables</div>
    <div id="zone-list"></div>
    <div class="sidebar-footer">LearninGo · full_schema_v2.sql</div>
  </aside>
  <div class="diagram-wrap">
    <div id="diagram-container">
      <div class="mermaid" id="erd">
erDiagram
  profiles { uuid user_id PK string email string display_name string membership_type boolean is_onboarded string user_status }
  user_preferences { uuid id PK uuid user_id FK array study_days string daily_duration string preferred_time string theme_mode }
  user_roles { uuid id PK uuid user_id FK enum role }
  user_devices { uuid id PK uuid user_id FK string device_id timestamp last_seen_at }
  hobbies { uuid id PK string name_he string slug boolean is_active }
  user_hobbies { uuid user_id FK uuid hobby_id FK timestamp created_at }
  courses { uuid id PK uuid created_by_user_id FK enum status string title date exam_date string course_difficulty }
  course_units { uuid id PK uuid course_id FK int unit_index string unit_title }
  course_sub_units { uuid id PK uuid unit_id FK uuid course_id FK string sub_unit_index string sub_unit_title }
  course_sources { uuid id PK uuid course_id FK uuid uploaded_by_user_id FK string file_name string file_type enum status }
  course_knowledge_chunk { uuid id PK uuid course_id FK uuid source_id FK int chunk_index text chunk_text }
  sub_unit_chunk_classifications { uuid id PK uuid sub_unit_id FK string chunk_id string content_type }
  sub_unit_summaries { uuid id PK uuid sub_unit_id FK uuid course_id FK jsonb summary_json string status int retry_count }
  sub_unit_flashcards { uuid id PK uuid sub_unit_id FK uuid course_id FK jsonb cards string status int retry_count }
  sub_unit_quizzes { uuid id PK uuid sub_unit_id FK uuid course_id FK jsonb questions string status int retry_count }
  unit_ex
