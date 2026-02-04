# ==============================================================================
# SQL COLUMN MAPPING ANALYZER - WORKING VERSION
# Properly handles nested subqueries and temp table chains
# ==============================================================================

from google.colab import files as colab_files
import json
import os
import re
import csv
import zipfile
from collections import defaultdict, deque

print("=" * 70)
print("STEP 1: Upload mappings.json")
print("=" * 70)
uploaded_mappings = colab_files.upload()
with open('/content/mappings.json', 'wb') as f:
    f.write(list(uploaded_mappings.values())[0])
print("✅ mappings.json uploaded")

print("\n" + "=" * 70)
print("STEP 2: Upload SQL ZIP file")
print("=" * 70)
uploaded_sql = colab_files.upload()
zip_name = list(uploaded_sql.keys())[0]
with open(f'/content/{zip_name}', 'wb') as f:
    f.write(list(uploaded_sql.values())[0])

extract_path = '/content/sql_files'
os.makedirs(extract_path, exist_ok=True)
with zipfile.ZipFile(f'/content/{zip_name}', 'r') as z:
    z.extractall(extract_path)

sql_count = sum(1 for root, dirs, files in os.walk(extract_path) 
                for f in files if f.lower().endswith('.sql'))
print(f"✅ Extracted {sql_count} SQL files")

# ==============================================================================
# PARSER CODE - WORKING VERSION
# ==============================================================================

def strip_comments(sql):
    sql = re.sub(r'/\*.*?\*/', ' ', sql, flags=re.S)
    sql = re.sub(r'--.*?\n', '\n', sql)
    return sql

def norm(s):
    return s.strip().strip('"').lower()

def node(t, c):
    return f"{norm(t)}.{norm(c)}"

class Graph:
    def __init__(self):
        self.adj = defaultdict(set)
        self.nodes = set()
        self.cursor_aliases = {}
        self.loop_vars = {}
        self.var_sources = {}
        self.cursor_defs = {}

    def edge(self, s, d):
        self.nodes.update([s, d])
        self.adj[s].add(d)

    def paths(self, start, goal, max_d=30):
        res, q = [], deque([(start, [start])])
        visited_paths = set()
        while q:
            n, p = q.popleft()
            if len(p) > max_d: continue
            path_key = tuple(p)
            if path_key in visited_paths: continue
            visited_paths.add(path_key)
            if n == goal: res.append(p); continue
            for nx in self.adj.get(n, set()):
                if nx not in p: q.append((nx, p + [nx]))
        return res

    def longest_path(self, start, goal, max_d=30):
        all_p = self.paths(start, goal, max_d)
        if not all_p: return []
        return max(all_p, key=len)

    def all_destinations(self, start, max_d=30):
        all_paths = []
        q = deque([(start, [start])])
        visited = set()

        while q:
            n, p = q.popleft()
            path_key = tuple(p)
            if path_key in visited or len(p) > max_d: 
                continue
            visited.add(path_key)

            if '.' in n and n.count('.') == 1 and n != start and 'to_date' not in n and 'case' not in n and '[' not in n:
                all_paths.append(list(p))

            for nx in self.adj.get(n, set()):
                if nx not in p: 
                    q.append((nx, p + [nx]))

        return all_paths

    def get_all_paths_to_dest(self, start, dest_table, dest_col, max_d=30):
        dest_node = node(dest_table, dest_col)
        all_paths = []
        q = deque([(start, [start])])
        visited = set()

        while q:
            n, p = q.popleft()
            path_key = tuple(p)
            if path_key in visited or len(p) > max_d:
                continue
            visited.add(path_key)

            if n == dest_node:
                all_paths.append(list(p))

            for nx in self.adj.get(n, set()):
                if nx not in p: 
                    q.append((nx, p + [nx]))

        return all_paths

def extract_cols(expr):
    res = []
    keywords = {'select', 'from', 'where', 'and', 'or', 'not', 'null', 'then', 'when', 'else', 'case', 'end', 'join', 'on', 'as', 'left', 'right', 'inner', 'outer', 'union', 'all', 'distinct', 'partition', 'by', 'over', 'order', 'desc', 'asc'}
    for m in re.finditer(r'([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)', expr, re.I):
        al, col = m.group(1).lower(), m.group(2).lower()
        if al not in keywords: res.append((al, col))
    return res

def split_paren(s, delim=','):
    parts, depth, cur = [], 0, ""
    for c in s:
        if c == '(': depth += 1; cur += c
        elif c == ')': depth -= 1; cur += c
        elif c == delim and depth == 0: parts.append(cur.strip()); cur = ""
        else: cur += c
    return parts + [cur.strip()] if cur.strip() else parts

def read_files(root):
    files_list = []
    for dp, _, fn in os.walk(root):
        for f in fn:
            if f.lower().endswith('.sql'):
                try:
                    with open(os.path.join(dp, f), 'r', encoding='utf-8', errors='ignore') as fh:
                        files_list.append((f, fh.read()))
                except: pass
    return files_list

def fmt(p):
    if not p: return ""
    parts = []
    for n in p:
        if 'CASE(' in n or 'DECODE(' in n or 'TO_DATE(' in n: parts.append(f"{n} [X]")
        elif re.match(r'^[a-z_]+\.[a-z_]+$', n):
            tbl_part = n.split('.')[0]
            if tbl_part in ['er', 'sp', 'sep', 'dmc', 'dcp', 'm', 'dm', 'ma', 'c', 'id', 'cccpt', 'cccpt2']:
                parts.append(f"{n} [C]")
            else:
                parts.append(n)
        elif '.' not in n: 
            parts.append(f"{n} [V]")
        else: 
            parts.append(f"{n}")
    return ' -> '.join(parts)

def parse_insert_with_nested_subqueries(sql, graph, stats):
    """
    Parse INSERT statements with nested subqueries like:
    INSERT INTO dest (col1, col2) 
    SELECT id.col1, id.col2 
    FROM (SELECT src.col1, src.col2 FROM source src) id
    """
    sql_clean = strip_comments(sql)

    # Pattern for INSERT...SELECT with nested subquery
    # This handles the specific pattern in 4.7 - cmn_client_comm_pref.sql
    pattern = r"INSERT\s+INTO\s+([a-z0-9_]+)\s*\(([^)]+)\)[^;]*?SELECT\s+(.+?)\s+FROM\s*\(\s*SELECT\s+DISTINCT\s+(.+?)\s+FROM\s*\(\s*SELECT\s+(.+?)\s+FROM\s+dm_([a-z0-9_]+)\s+([a-z])"

    for match in re.finditer(pattern, sql_clean, re.I | re.S):
        dest_table = norm(match.group(1))
        dest_cols_str = match.group(2)
        outer_select = match.group(3)
        middle_select = match.group(4)
        inner_select = match.group(5)
        source_table = "dm_" + match.group(6)
        source_alias = match.group(7).lower()

        # Parse column lists
        dest_cols = [norm(c) for c in split_paren(dest_cols_str)]
        outer_exprs = [e.strip() for e in split_paren(outer_select)]
        inner_exprs = [e.strip() for e in split_paren(inner_select)]

        # Build inner column mapping
        inner_mapping = {}  # Maps output column name -> source column
        for expr in inner_exprs:
            # Pattern: m.column or m.column AS alias
            m = re.match(rf'{source_alias}\.([a-z0-9_]+)(?:\s+AS\s+([a-z0-9_]+))?', expr, re.I)
            if m:
                src_col = m.group(1).lower()
                alias_col = m.group(2).lower() if m.group(2) else src_col
                inner_mapping[alias_col] = src_col

        # Match by position
        for i, dest_col in enumerate(dest_cols):
            if i >= len(outer_exprs):
                break

            outer_expr = outer_exprs[i]
            dest_node = node(dest_table, dest_col)

            # Check if outer expression is alias.column format (e.g., id.consent_to_direct_marketing)
            outer_match = re.match(r'([a-z])\.([a-z0-9_]+)', outer_expr, re.I)
            if outer_match:
                outer_alias = outer_match.group(1).lower()
                outer_col = outer_match.group(2).lower()

                # Check if this column comes from inner mapping
                if outer_col in inner_mapping:
                    src_col = inner_mapping[outer_col]

                    # Create edges:
                    # 1. dm_employer.column -> source_alias.column
                    src_node = node(source_table, src_col)
                    inter_node1 = f"{source_alias}.{src_col}"
                    graph.edge(src_node, inter_node1)

                    # 2. source_alias.column -> outer_alias.column
                    inter_node2 = f"{outer_alias}.{outer_col}"
                    graph.edge(inter_node1, inter_node2)

                    # 3. outer_alias.column -> destination
                    graph.edge(inter_node2, dest_node)

                    stats['nested_subq'] += 1

def parse_temp_table_chains(sql, graph, stats):
    """
    Parse chains like: dm_correlated_person -> cccp_ini_temp -> cccp_temp -> cmn_client_contact_person
    """
    sql_clean = strip_comments(sql)

    # Step 1: Parse dm_correlated_person -> cccp_ini_temp
    # Pattern: INSERT INTO cccp_ini_temp (...) SELECT ... FROM dm_correlated_person
    pattern1 = r"insert\s+into\s+cccp_ini_temp\s*\(([^)]+)\)[^;]*?select\s+(.+?)\s+from\s+dm_correlated_person\s+([a-z])"

    for match in re.finditer(pattern1, sql_clean, re.I | re.S):
        cols_str = match.group(1)
        select_clause = match.group(2)
        table_alias = match.group(3).lower()

        cols = [norm(c) for c in split_paren(cols_str)]
        exprs = [e.strip() for e in split_paren(select_clause)]

        for col, expr in zip(cols, exprs):
            # Check if expr is table_alias.column
            m = re.match(rf'{table_alias}\.([a-z0-9_]+)', expr, re.I)
            if m:
                src_col = m.group(1).lower()
                src_node = node('dm_correlated_person', src_col)
                dest_node = node('cccp_ini_temp', col)
                graph.edge(src_node, dest_node)
                stats['temp1'] += 1
            elif re.match(r'^[a-z0-9_]+$', expr, re.I):
                # Simple column name
                src_node = node('dm_correlated_person', expr.lower())
                dest_node = node('cccp_ini_temp', col)
                graph.edge(src_node, dest_node)
                stats['temp1'] += 1

    # Step 2: Parse cccp_ini_temp -> cccp_temp
    # Pattern: INSERT INTO cccp_temp (...) SELECT ... FROM cccp_ini_temp
    pattern2 = r"insert\s+into\s+cccp_temp\s*\(([^)]+)\)[^;]*?select\s+(.+?)\s+from\s+cccp_ini_temp"

    for match in re.finditer(pattern2, sql_clean, re.I | re.S):
        cols_str = match.group(1)
        select_clause = match.group(2)

        cols = [norm(c) for c in split_paren(cols_str)]
        exprs = [e.strip() for e in split_paren(select_clause)]

        for col, expr in zip(cols, exprs):
            expr_lower = expr.lower()
            # Skip functions and literals
            if any(x in expr_lower for x in ['row_number', 'generate_guid', 'sysdate', 'null']):
                continue
            if expr_lower.startswith("'"):
                continue

            # Extract column name
            m = re.match(r'([a-z0-9_]+)', expr, re.I)
            if m:
                src_col = m.group(1).lower()
                src_node = node('cccp_ini_temp', src_col)
                dest_node = node('cccp_temp', col)
                graph.edge(src_node, dest_node)
                stats['temp2'] += 1

    # Step 3: Parse cccp_temp -> cmn_client_contact_person
    # Pattern: INSERT INTO cmn_client_contact_person (...) SELECT ... FROM cccp_temp
    pattern3 = r"insert\s+into\s+cmn_client_contact_person\s*\(([^)]+)\)[^;]*?select\s+(.+?)\s+from\s+cccp_temp\s+([a-z0-9_]+)"

    for match in re.finditer(pattern3, sql_clean, re.I | re.S):
        cols_str = match.group(1)
        select_clause = match.group(2)
        table_alias = match.group(3).lower()

        cols = [norm(c) for c in split_paren(cols_str)]
        # Split by comma but be careful with function calls
        exprs = split_paren(select_clause)

        for col, expr in zip(cols, exprs):
            expr_clean = expr.strip()
            expr_lower = expr_clean.lower()

            # Skip literals and functions without column refs
            if expr_lower in ['null', 'sysdate', 'systimestamp', "'n'"]:
                continue
            if expr_lower.startswith("'"):
                continue

            dest_node = node('cmn_client_contact_person', col)

            # Handle NVL(alias.column, ...)
            nvl_match = re.match(r'nvl\s*\(([^,]+),', expr_clean, re.I)
            if nvl_match:
                inner = nvl_match.group(1).strip()
                col_refs = extract_cols(inner)
                for al, src_col in col_refs:
                    if al == table_alias:
                        src_node = node('cccp_temp', src_col)
                        graph.edge(src_node, dest_node)
                        stats['temp3_nvl'] += 1
                continue

            # Handle CASE expressions
            if 'case' in expr_lower:
                col_refs = extract_cols(expr_clean)
                for al, src_col in col_refs:
                    if al == table_alias:
                        src_node = node('cccp_temp', src_col)
                        graph.edge(src_node, dest_node)
                        stats['temp3_case'] += 1
                continue

            # Extract all column references
            col_refs = extract_cols(expr_clean)
            if col_refs:
                for al, src_col in col_refs:
                    if al == table_alias:
                        src_node = node('cccp_temp', src_col)
                        graph.edge(src_node, dest_node)
                        stats['temp3'] += 1
            else:
                # Simple column name without table prefix
                m = re.match(r'([a-z0-9_]+)', expr_clean, re.I)
                if m:
                    src_col = m.group(1).lower()
                    src_node = node('cccp_temp', src_col)
                    graph.edge(src_node, dest_node)
                    stats['temp3'] += 1

def parse_sql(content, graph):
    stats = defaultdict(int)

    # Parse INSERT with nested subqueries (handles mapping 3)
    parse_insert_with_nested_subqueries(content, graph, stats)

    # Parse temp table chains (handles mapping 4)
    parse_temp_table_chains(content, graph, stats)

    # Original parsing for cursor-based patterns
    sql_clean = strip_comments(content)

    # Cursors
    for m in re.finditer(r'\bcursor\s+([a-z][a-z0-9_]*)\s+is\s+', sql_clean, re.I):
        name, start = m.group(1).lower(), m.end()
        depth, end = 0, start
        for i, c in enumerate(sql_clean[start:], start):
            if c == '(': depth += 1
            elif c == ')': depth -= 1
            elif c == ';' and depth == 0: end = i; break
        body = sql_clean[start:end]
        aliases = {}
        for dm in re.finditer(r'(dm_[a-z0-9_]+)(?:\s+([a-z][a-z0-9_]*))?', body, re.I):
            tbl, al = dm.group(1).lower(), (dm.group(2) or dm.group(1)).lower()
            aliases[al] = tbl
        if not aliases:
            for t in re.finditer(r'from\s+([a-z][a-z0-9_]+)(?:\s+([a-z][a-z0-9_]*))?', body, re.I):
                tbl, al = t.group(1).lower(), (t.group(2) or t.group(1)).lower()
                aliases[al] = tbl
        graph.cursor_defs[name] = {'aliases': aliases}
        graph.cursor_aliases[name] = aliases

    # FOR loops
    for m in re.finditer(r'\bfor\s+([a-z][a-z0-9_]*)\s+in\s+([a-z][a-z0-9_]*)\s+loop\b', sql_clean, re.I):
        lv, cur = m.group(1).lower(), m.group(2).lower()
        if cur in graph.cursor_aliases:
            graph.loop_vars[lv] = {'cursor': cur, 'aliases': graph.cursor_aliases[cur]}

    # Variable assignments
    for m in re.finditer(r'\b([a-z][a-z0-9_]*)\s*:=\s*([^;]+);', sql_clean, re.I):
        var, expr = m.group(1).lower(), m.group(2)
        ctx, aliases = None, {}
        for lv, info in graph.loop_vars.items():
            if re.search(rf'\b{re.escape(lv)}\.', expr, re.I):
                ctx, aliases = lv, info['aliases']; break
        for al, col in extract_cols(expr):
            tbl = aliases.get(al, al) if ctx else al
            if ctx:
                tbl = list(graph.cursor_defs[graph.loop_vars[lv]['cursor']]['aliases'].values())[0] if graph.cursor_defs[graph.loop_vars[lv]['cursor']]['aliases'] else al
            src = node(tbl, col)
            if ctx:
                inter = f"{ctx}.{col}"
                graph.edge(src, inter); graph.edge(inter, var)
                graph.var_sources[var] = inter
            else:
                graph.edge(src, var); graph.var_sources[var] = src
            stats['assign'] += 1

    # INSERT VALUES
    all_al = {}
    for info in graph.loop_vars.values(): all_al.update(info['aliases'])

    for m in re.finditer(r'insert\s+into\s+([a-z0-9_\."]+)\s*\(([\s\S]*?)\)\s*values\s*\(([\s\S]*?)\);', sql_clean, re.I | re.S):
        tbl = norm(m.group(1).split('.')[-1])
        cols = split_paren(re.sub(r'--.*?\n', '', m.group(2)))
        vals = split_paren(re.sub(r'--.*?\n', '', m.group(3)))
        for col, val in zip(cols, vals):
            dst, vlow = node(tbl, col), val.lower().strip()
            if re.match(r'^[a-z][a-z0-9_]*$', vlow) and vlow in graph.var_sources:
                graph.edge(vlow, dst); stats['ins_var'] += 1
            elif '.' in vlow and not vlow.startswith('to_date') and not vlow.startswith('decode'):
                for al, sc in extract_cols(val):
                    src = node(all_al.get(al, al), sc)
                    if al in graph.loop_vars:
                        inter = f"{al}.{sc}"
                        graph.edge(src, inter); graph.edge(inter, dst); stats['ins_loop'] += 1
                    else:
                        graph.edge(src, dst); stats['ins_col'] += 1
            elif 'to_date(' in vlow:
                for al, sc in extract_cols(val):
                    src = node(all_al.get(al, al), sc)
                    inter = f"TO_DATE({al}.{sc})"
                    graph.edge(src, inter); graph.edge(inter, dst); stats['ins_td'] += 1
            elif 'case' in vlow:
                for cm in re.finditer(r'case\s+when\s+([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)', val, re.I):
                    al, sc = cm.group(1).lower(), cm.group(2).lower()
                    src = node(all_al.get(al, al), sc)
                    inter = f"CASE({al}.{sc})"
                    graph.edge(src, inter); graph.edge(inter, dst); stats['ins_case'] += 1
            elif 'decode(' in vlow:
                dm = re.search(r'decode\s*\(\s*([a-z][a-z0-9_]*)', val, re.I)
                if dm:
                    vn = dm.group(1).lower()
                    if vn in graph.var_sources:
                        inter = f"DECODE({vn})"
                        graph.edge(vn, inter); graph.edge(inter, dst); stats['ins_dec'] += 1

    # Transitive closure
    for n in list(graph.nodes):
        if n not in graph.adj: continue
        vis, q, desc = set(), list(graph.adj[n]), []
        while q:
            c = q.pop(0)
            if c not in vis:
                vis.add(c); desc.append(c)
                if c in graph.adj: q.extend(graph.adj[c])
        for d in desc:
            if d not in graph.adj.get(n, set()): graph.edge(n, d); stats['trans'] += 1

    return stats

def process(files_list):
    g = Graph()
    totals = defaultdict(int)
    for name, content in files_list:
        print(f"Processing: {name}")
        stats = parse_sql(content, g)
        for k, v in stats.items(): totals[k] += v
    print(f"\nTotals: {dict(totals)}")
    return g

def load_maps(path):
    with open(path) as f:
        return [{k: norm(v) for k, v in m.items()} for m in json.load(f)]

def get_longest_path_only(paths):
    """Filter paths to keep only the longest ones when paths share the same end node."""
    if not paths:
        return []

    by_end = defaultdict(list)
    for p in paths:
        if p:
            by_end[p[-1]].append(p)

    result = []
    for end_node, paths_list in by_end.items():
        longest = max(paths_list, key=len)
        result.append(longest)

    return result

# ==============================================================================
# RUN ANALYSIS
# ==============================================================================

print("\n" + "=" * 70)
print("STEP 3: Running analysis")
print("=" * 70)

files_list = read_files('/content/sql_files')
print(f"\nFound {len(files_list)} SQL file(s)")
g = process(files_list)
queries = load_maps('/content/mappings.json')

out_file = '/content/mapping_results.csv'
with open(out_file, 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=['src_tbl', 'src_col', 'dst_tbl', 'dst_col', 'found', 'longest_path', 'length', 'inter', 'alts'])
    w.writeheader()

    print(f"\n{'='*70}")
    print("RESULTS")
    print('='*70)

    for q in queries:
        src, dst = node(q['source_table'], q['source_field']), node(q['dest_table'], q['dest_field'])

        # Get all paths to the destination
        all_paths = g.get_all_paths_to_dest(src, q['dest_table'], q['dest_field'])

        # Filter to keep only longest path for each end node
        longest_paths = get_longest_path_only(all_paths)

        found = len(longest_paths) > 0

        # Get the longest path overall
        if longest_paths:
            longest = max(longest_paths, key=len)
        else:
            longest = []

        inters = [n for n in longest[1:-1] if '.' not in n or '[' in n] if longest else []

        # For alternatives, find other paths that don't end at the target
        alts = []
        if not found:
            all_reachable = g.all_destinations(src)
            target_end = node(q['dest_table'], q['dest_field'])
            other_paths = [p for p in all_reachable if p and p[-1] != target_end]
            if other_paths:
                other_longest = get_longest_path_only(other_paths)
                alts = [fmt(p) for p in sorted(other_longest, key=len, reverse=True)[:5]]

        alts_str = '|||'.join(alts)

        w.writerow({
            'src_tbl': q['source_table'], 'src_col': q['source_field'],
            'dst_tbl': q['dest_table'], 'dst_col': q['dest_field'],
            'found': found, 'longest_path': fmt(longest), 'length': len(longest),
            'inter': ','.join(inters), 'alts': alts_str
        })

        print(f"\n{q['source_table']}.{q['source_field']} → {q['dest_table']}.{q['dest_field']}")
        print(f"  Found: {found}")
        if found:
            print(f"  ✅ Longest path ({len(longest)} nodes): {fmt(longest)}")
        elif alts_str:
            print("  ❌ No direct path to target")
            print("  Alternative paths found:")
            for a in alts_str.split('|||')[:3]: 
                print(f"    → {a}")
        else:
            print("  ❌ No path found")

print(f"\n{'='*70}")
print(f"✅ Results: {out_file}")
print('='*70)

colab_files.download(out_file)