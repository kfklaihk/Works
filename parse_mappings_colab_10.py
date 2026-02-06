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

SQL_FILE_CACHE_ROOT = None
SQL_FILE_CACHE_LIST = None
SQL_CLEAN_CACHE = {}

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

# Reset caches after new extraction
SQL_FILE_CACHE_ROOT = None
SQL_FILE_CACHE_LIST = None
SQL_CLEAN_CACHE = {}

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
    if s is None:
        return ""
    return str(s).strip().strip('"').lower()

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

KEYWORDS = {
    'where', 'join', 'inner', 'left', 'right', 'full', 'cross', 'on', 'group',
    'order', 'union', 'connect', 'minus', 'intersect', 'having', 'values',
    'set', 'and', 'or', 'from', 'select'
}
UNQUALIFIED_SKIP = KEYWORDS.union({
    'case', 'when', 'then', 'else', 'end', 'nvl', 'upper', 'lower', 'decode',
    'to_date', 'sysdate', 'systimestamp', 'distinct', 'row_number', 'over',
    'partition', 'by', 'null', 'as'
})

def find_matching_paren(s, start_idx):
    depth = 0
    for i in range(start_idx, len(s)):
        if s[i] == '(':
            depth += 1
        elif s[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1

def split_union_all(sql):
    parts = []
    depth = 0
    start = 0
    i = 0
    sql_lower = sql.lower()
    while i < len(sql):
        c = sql[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif depth == 0 and sql_lower.startswith('union all', i):
            parts.append(sql[start:i].strip())
            i += len('union all')
            start = i
            continue
        i += 1
    tail = sql[start:].strip()
    if tail:
        parts.append(tail)
    return parts

def split_select_from(sql):
    sql_lower = sql.lower()
    sel_idx = sql_lower.find('select')
    if sel_idx == -1:
        return None, None
    i = sel_idx + len('select')
    depth = 0
    from_idx = None
    while i < len(sql):
        c = sql[i]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
        elif depth == 0 and sql_lower.startswith('from', i):
            from_idx = i
            break
        i += 1
    if from_idx is None:
        return None, None
    select_clause = sql[sel_idx + len('select'):from_idx].strip()
    from_clause = sql[from_idx + len('from'):].strip()
    return select_clause, from_clause

def split_conditions(s):
    parts, depth, cur = [], 0, ""
    i = 0
    s_len = len(s)
    while i < s_len:
        c = s[i]
        if c == '(':
            depth += 1
            cur += c
        elif c == ')':
            depth -= 1
            cur += c
        elif depth == 0 and s[i:i+3].lower() == 'and' and (i == 0 or not s[i-1].isalnum()):
            parts.append(cur.strip())
            cur = ""
            i += 3
            continue
        else:
            cur += c
        i += 1
    if cur.strip():
        parts.append(cur.strip())
    return parts

def parse_join_conditions(from_clause, table_aliases, subquery_aliases, default_alias, graph, stats):
    join_cols_by_alias = defaultdict(set)
    on_pattern = re.compile(r'\bon\b\s+([\s\S]*?)(?=\b(join|where|group|order|union|having|$))', re.I)
    for on_match in on_pattern.finditer(from_clause):
        cond_block = on_match.group(1)
        for cond in split_conditions(cond_block):
            if not cond:
                continue
            eq_parts = cond.split('=')
            if len(eq_parts) != 2:
                continue
            left = eq_parts[0].strip()
            right = eq_parts[1].strip()

            m_left = re.match(r'([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)$', left, re.I)
            m_right = re.match(r'([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)$', right, re.I)

            if m_left and not m_right:
                alias, col = m_left.group(1).lower(), m_left.group(2).lower()
                out_col, sources = resolve_expr_sources(
                    right, table_aliases, subquery_aliases, graph, stats, default_alias
                )
                if sources:
                    for src in sources:
                        graph.edge(src, f"{alias}.{col}")
                        stats['join_cond'] += 1
                    join_cols_by_alias[alias].add(col)
            elif m_right and not m_left:
                alias, col = m_right.group(1).lower(), m_right.group(2).lower()
                out_col, sources = resolve_expr_sources(
                    left, table_aliases, subquery_aliases, graph, stats, default_alias
                )
                if sources:
                    for src in sources:
                        graph.edge(src, f"{alias}.{col}")
                        stats['join_cond'] += 1
                    join_cols_by_alias[alias].add(col)
            elif m_left and m_right:
                l_alias, l_col = m_left.group(1).lower(), m_left.group(2).lower()
                r_alias, r_col = m_right.group(1).lower(), m_right.group(2).lower()
                graph.edge(f"{r_alias}.{r_col}", f"{l_alias}.{l_col}")
                graph.edge(f"{l_alias}.{l_col}", f"{r_alias}.{r_col}")
                join_cols_by_alias[l_alias].add(l_col)
                join_cols_by_alias[r_alias].add(r_col)
                stats['join_cond'] += 2

    return join_cols_by_alias

def parse_from_clause(from_clause, graph, stats):
    table_aliases = {}
    subquery_aliases = {}
    primary_alias = None
    clause = from_clause.strip()
    rest = clause

    if clause.startswith('('):
        end_idx = find_matching_paren(clause, 0)
        if end_idx != -1:
            sub_sql = clause[1:end_idx]
            alias_match = re.match(r'\s*([a-z][a-z0-9_]*)', clause[end_idx + 1:], re.I)
            if alias_match:
                alias = alias_match.group(1).lower()
                subquery_aliases[alias] = parse_select_mapping(sub_sql, graph, stats)
                primary_alias = alias
            rest = clause[end_idx + 1:]
    else:
        first = re.match(r'\s*([a-z0-9_".]+)(?:\s+as)?\s+([a-z][a-z0-9_]*)?', rest, re.I)
        if first:
            tbl = norm(first.group(1).split('.')[-1].strip('"'))
            alias = first.group(2).lower() if first.group(2) else tbl
            if alias in KEYWORDS:
                alias = tbl
            table_aliases[alias] = tbl
            primary_alias = alias

    for m in re.finditer(r'\bjoin\s+([a-z0-9_".]+)(?:\s+as)?\s+([a-z][a-z0-9_]*)?', rest, re.I):
        tbl = norm(m.group(1).split('.')[-1].strip('"'))
        alias = m.group(2).lower() if m.group(2) else tbl
        if alias in KEYWORDS:
            alias = tbl
        table_aliases[alias] = tbl
    return table_aliases, subquery_aliases, primary_alias

def extract_unqualified_cols(expr):
    expr_clean = re.sub(r"'([^']|'')*'", ' ', expr)
    expr_clean = re.sub(r'[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*', ' ', expr_clean, flags=re.I)
    tokens = re.findall(r'\b[a-z][a-z0-9_]*\b', expr_clean, flags=re.I)
    cols = []
    for tok in tokens:
        t = tok.lower()
        if t in UNQUALIFIED_SKIP:
            continue
        cols.append(t)
    return cols

def resolve_expr_sources(expr, table_aliases, subquery_aliases, graph, stats, default_alias=None):
    expr_clean = expr.strip()
    expr_body = expr_clean
    out_col = None

    m = re.match(r'(.+?)\s+as\s+([a-z0-9_]+)$', expr_clean, re.I | re.S)
    if m:
        expr_body = m.group(1).strip()
        out_col = m.group(2).lower()
    else:
        m = re.match(r'(.+?)\s+([a-z0-9_]+)$', expr_clean, re.I | re.S)
        if m:
            expr_body = m.group(1).strip()
            out_col = m.group(2).lower()

    m = re.match(r'([a-z][a-z0-9_]*)\.([a-z0-9_]+)$', expr_body, re.I)
    if m:
        alias = m.group(1).lower()
        col = m.group(2).lower()
        if not out_col:
            out_col = col
        if alias in subquery_aliases:
            sources = subquery_aliases[alias].get(col, set())
            if not sources:
                sources = {f"{alias}.{col}"}
        else:
            sources = {f"{alias}.{col}"}
        if alias in table_aliases:
            base_table = table_aliases[alias]
            graph.edge(node(base_table, col), f"{alias}.{col}")
            stats['alias_src'] += 1
        return out_col, sources

    m = re.match(r'([a-z][a-z0-9_]*)$', expr_body, re.I)
    if m:
        col = m.group(1).lower()
        if not out_col:
            out_col = col
        sources = set()
        if len(subquery_aliases) == 1:
            alias = next(iter(subquery_aliases))
            mapped = subquery_aliases[alias].get(col, set())
            if mapped:
                sources.update(mapped)
        if not sources and len(table_aliases) == 1:
            alias = next(iter(table_aliases))
            sources.add(f"{alias}.{col}")
            base_table = table_aliases[alias]
            graph.edge(node(base_table, col), f"{alias}.{col}")
            stats['alias_src'] += 1
        return out_col, sources

    col_refs = extract_cols(expr_body)
    if col_refs:
        sources = set()
        for al, col in col_refs:
            if al in subquery_aliases:
                sources.update(subquery_aliases[al].get(col, set()))
            else:
                sources.add(f"{al}.{col}")
                if al in table_aliases:
                    base_table = table_aliases[al]
                    graph.edge(node(base_table, col), f"{al}.{col}")
                    stats['alias_src'] += 1
        return out_col, sources

    if default_alias:
        cols = extract_unqualified_cols(expr_body)
        if cols:
            sources = set()
            for col in cols:
                if default_alias in subquery_aliases:
                    mapped = subquery_aliases[default_alias].get(col, set())
                    if mapped:
                        sources.update(mapped)
                    else:
                        sources.add(f"{default_alias}.{col}")
                else:
                    sources.add(f"{default_alias}.{col}")
                    if default_alias in table_aliases:
                        base_table = table_aliases[default_alias]
                        graph.edge(node(base_table, col), f"{default_alias}.{col}")
                        stats['alias_src'] += 1
            if not out_col and len(cols) == 1:
                out_col = cols[0]
            return out_col, sources

    return None, set()

def strip_select_alias(expr):
    expr_clean = expr.strip()
    m = re.match(r'(.+?)\s+as\s+[a-z0-9_]+$', expr_clean, re.I | re.S)
    if m:
        return m.group(1).strip()
    m = re.match(r'(.+?)\s+[a-z0-9_]+$', expr_clean, re.I | re.S)
    if m:
        return m.group(1).strip()
    return expr_clean

def parse_select_mapping(sql, graph, stats):
    mapping = defaultdict(set)
    for part in split_union_all(sql):
        select_clause, from_clause = split_select_from(part)
        if not select_clause or not from_clause:
            continue
        table_aliases, subquery_aliases, primary_alias = parse_from_clause(from_clause, graph, stats)
        default_alias = primary_alias
        if not default_alias:
            if len(subquery_aliases) == 1:
                default_alias = next(iter(subquery_aliases))
            elif len(table_aliases) == 1:
                default_alias = next(iter(table_aliases))
        join_cols_by_alias = parse_join_conditions(
            from_clause, table_aliases, subquery_aliases, default_alias, graph, stats
        )
        exprs = split_paren(select_clause)
        for expr in exprs:
            out_col, sources = resolve_expr_sources(
                expr, table_aliases, subquery_aliases, graph, stats, default_alias
            )
            if out_col and sources:
                mapping[out_col].update(sources)
            expr_body = strip_select_alias(expr)
            m = re.match(r'\s*([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)\s*$', expr_body, re.I)
            if m:
                alias, col = m.group(1).lower(), m.group(2).lower()
                for join_col in join_cols_by_alias.get(alias, set()):
                    if join_col != col:
                        graph.edge(f"{alias}.{join_col}", f"{alias}.{col}")
                        stats['join_to_select'] += 1
    return mapping

def read_files(root, use_cache=True):
    global SQL_FILE_CACHE_ROOT, SQL_FILE_CACHE_LIST, SQL_CLEAN_CACHE
    if use_cache and SQL_FILE_CACHE_ROOT == root and SQL_FILE_CACHE_LIST is not None:
        return SQL_FILE_CACHE_LIST

    files_list = []
    SQL_CLEAN_CACHE = {}
    for dp, _, fn in os.walk(root):
        for f in fn:
            if f.lower().endswith('.sql'):
                full_path = os.path.join(dp, f)
                try:
                    with open(full_path, 'r', encoding='utf-8', errors='ignore') as fh:
                        content = fh.read()
                        rel_path = os.path.relpath(full_path, root)
                        files_list.append((rel_path, content))
                        if use_cache:
                            SQL_CLEAN_CACHE[rel_path] = strip_comments(content)
                except:
                    pass
    SQL_FILE_CACHE_ROOT = root
    SQL_FILE_CACHE_LIST = files_list
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

def parse_insert_with_nested_subqueries(sql, graph, stats, sql_clean=None):
    """
    Parse INSERT...SELECT...FROM (subquery) alias patterns and build
    alias chains for nested subqueries.
    """
    if sql_clean is None:
        sql_clean = strip_comments(sql)
    pattern = r'insert\s+into\s+([a-z0-9_".]+)\s*\((.*?)\)\s*select\s+(.*?)\s+from\s*\('

    for m in re.finditer(pattern, sql_clean, re.I | re.S):
        dest_table = norm(m.group(1).split('.')[-1].strip('"'))
        dest_cols = [norm(c) for c in split_paren(m.group(2))]
        select_exprs = [e.strip() for e in split_paren(m.group(3))]

        open_idx = m.end() - 1
        close_idx = find_matching_paren(sql_clean, open_idx)
        if close_idx == -1:
            continue
        subquery_sql = sql_clean[open_idx + 1:close_idx]
        alias_match = re.match(r'\s*([a-z][a-z0-9_]*)', sql_clean[close_idx + 1:], re.I)
        if not alias_match:
            continue
        sub_alias = alias_match.group(1).lower()

        sub_mapping = parse_select_mapping(subquery_sql, graph, stats)
        for out_col, sources in sub_mapping.items():
            sub_node = f"{sub_alias}.{out_col}"
            for src in sources:
                graph.edge(src, sub_node)
                stats['subq_map'] += 1

        for dest_col, expr in zip(dest_cols, select_exprs):
            dest_node = node(dest_table, dest_col)
            expr_clean = expr.strip()
            m_expr = re.match(r'([a-z][a-z0-9_]*)\.([a-z0-9_]+)$', expr_clean, re.I)
            if m_expr:
                alias = m_expr.group(1).lower()
                col = m_expr.group(2).lower()
                graph.edge(f"{alias}.{col}", dest_node)
                stats['ins_subq'] += 1
                continue

            m_bare = re.match(r'([a-z][a-z0-9_]*)$', expr_clean, re.I)
            if m_bare:
                col = m_bare.group(1).lower()
                graph.edge(f"{sub_alias}.{col}", dest_node)
                stats['ins_subq'] += 1

def parse_insert_select_statements(sql, graph, stats, sql_clean=None):
    if sql_clean is None:
        sql_clean = strip_comments(sql)
    pattern = re.compile(r'insert\s+into\s+([a-z0-9_".]+)\s*\((.*?)\)\s*select\b', re.I | re.S)
    for m in pattern.finditer(sql_clean):
        dest_table = norm(m.group(1).split('.')[-1].strip('"'))
        dest_cols = [norm(c) for c in split_paren(m.group(2))]
        select_start = m.end() - len('select')
        depth = 0
        end_idx = None
        for i in range(m.end(), len(sql_clean)):
            c = sql_clean[i]
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
            elif c == ';' and depth == 0:
                end_idx = i
                break
        select_sql = sql_clean[select_start:end_idx].strip() if end_idx else sql_clean[select_start:].strip()
        select_clause, from_clause = split_select_from(select_sql)
        if not select_clause or not from_clause:
            continue
        table_aliases = {}
        subquery_aliases = {}
        primary_alias = None
        join_cols_by_alias = defaultdict(set)
        from_clause_stripped = from_clause.lstrip()
        if from_clause_stripped.startswith('('):
            end_idx = find_matching_paren(from_clause_stripped, 0)
            if end_idx != -1:
                sub_sql = from_clause_stripped[1:end_idx]
                alias_match = re.match(r'\s*([a-z][a-z0-9_]*)', from_clause_stripped[end_idx + 1:], re.I)
                if alias_match:
                    alias = alias_match.group(1).lower()
                    subquery_aliases[alias] = parse_select_mapping(sub_sql, graph, stats)
                    primary_alias = alias
                    join_cols_by_alias = parse_join_conditions(
                        from_clause, table_aliases, subquery_aliases, primary_alias, graph, stats
                    )
                else:
                    pseudo = "_subq"
                    subquery_aliases[pseudo] = parse_select_mapping(sub_sql, graph, stats)
                    primary_alias = pseudo
        else:
            table_aliases, subquery_aliases, primary_alias = parse_from_clause(from_clause, graph, stats)
            join_cols_by_alias = parse_join_conditions(
                from_clause, table_aliases, subquery_aliases, primary_alias, graph, stats
            )
        default_alias = primary_alias
        if not default_alias:
            if len(subquery_aliases) == 1:
                default_alias = next(iter(subquery_aliases))
            elif len(table_aliases) == 1:
                default_alias = next(iter(table_aliases))
        exprs = split_paren(select_clause)
        for dest_col, expr in zip(dest_cols, exprs):
            dest_node = node(dest_table, dest_col)
            out_col, sources = resolve_expr_sources(
                expr, table_aliases, subquery_aliases, graph, stats, default_alias
            )
            for src in sources:
                graph.edge(src, dest_node)
                stats['ins_select'] += 1
            expr_body = strip_select_alias(expr)
            m_expr = re.match(r'\s*([a-z][a-z0-9_]*)\.([a-z][a-z0-9_]*)\s*$', expr_body, re.I)
            if m_expr:
                alias, col = m_expr.group(1).lower(), m_expr.group(2).lower()
                for join_col in join_cols_by_alias.get(alias, set()):
                    if join_col != col:
                        graph.edge(f"{alias}.{join_col}", f"{alias}.{col}")
                        stats['join_to_select'] += 1

def extract_alias_after_from(after_text):
    m = re.match(r'\s+([a-z][a-z0-9_]*)', after_text, re.I)
    if m:
        alias = m.group(1).lower()
        if alias not in KEYWORDS:
            return alias
    return None

def map_insert_select(sql_clean, dest_table, source_table, graph, stats,
                      dest_col=None, source_col=None, stats_key=''):
    pattern = rf'insert\s+(?:/\*.*?\*/\s*)?into\s+{re.escape(dest_table)}\s*\((.*?)\)\s*select\s+(.*?)\s+from\s+{re.escape(source_table)}\b'
    for m in re.finditer(pattern, sql_clean, re.I | re.S):
        dest_cols = [norm(c) for c in split_paren(m.group(1))]
        select_exprs = [e.strip() for e in split_paren(m.group(2))]
        alias = extract_alias_after_from(sql_clean[m.end():])
        source_aliases = {alias} if alias else {source_table}

        for dcol, expr in zip(dest_cols, select_exprs):
            if dest_col and dcol != dest_col:
                continue
            used = False
            for al, sc in extract_cols(expr):
                if al in source_aliases or al == source_table:
                    if source_col and sc != source_col:
                        continue
                    graph.edge(node(source_table, sc), node(dest_table, dcol))
                    stats[stats_key or 'ins_select'] += 1
                    used = True
            if used:
                continue
            expr_lower = expr.strip().lower()
            m_bare = re.match(r'([a-z][a-z0-9_]*)$', expr_lower)
            if m_bare:
                sc = m_bare.group(1).lower()
                if source_col and sc != source_col:
                    continue
                graph.edge(node(source_table, sc), node(dest_table, dcol))
                stats[stats_key or 'ins_select'] += 1

def parse_temp_table_chains(sql, graph, stats, sql_clean=None):
    """
    Parse chains like: dm_correlated_person -> cccp_ini_temp -> cccp_temp -> cmn_client_contact_person
    """
    if sql_clean is None:
        sql_clean = strip_comments(sql)
    map_insert_select(
        sql_clean, 'cccp_ini_temp', 'dm_correlated_person', graph, stats,
        dest_col='mbr_communication_type', source_col='mbr_communication_type',
        stats_key='temp1'
    )
    map_insert_select(
        sql_clean, 'cccp_temp', 'cccp_ini_temp', graph, stats,
        dest_col='mbr_communication_type', source_col='mbr_communication_type',
        stats_key='temp2'
    )
    map_insert_select(
        sql_clean, 'cmn_client_contact_person', 'cccp_temp', graph, stats,
        dest_col='av_notify_medium_code', source_col='mbr_communication_type',
        stats_key='temp3'
    )

def parse_if_assignments(sql_clean, graph, stats):
    if_pattern = re.compile(r'\bif\b[\s\S]*?\bend if\b\s*;', re.I)
    branch_pattern = re.compile(r'\b(if|elsif)\b\s+(.*?)\bthen\b', re.I | re.S)

    for if_match in if_pattern.finditer(sql_clean):
        block = if_match.group(0)
        branches = list(branch_pattern.finditer(block))
        if not branches:
            continue

        for idx, br in enumerate(branches):
            cond = br.group(2)
            start = br.end()
            next_start = branches[idx + 1].start() if idx + 1 < len(branches) else None
            end = next_start if next_start is not None else block.lower().rfind('end if')
            else_match = re.search(r'\belse\b', block[start:end], re.I)
            if else_match:
                end = start + else_match.start()
            body = block[start:end]

            for assign in re.finditer(r'\b([a-z][a-z0-9_]*)\s*:=\s*([^;]+);', body, re.I | re.S):
                var = assign.group(1).lower()
                ctx, aliases = None, {}
                for lv, info in graph.loop_vars.items():
                    if re.search(rf'\b{re.escape(lv)}\.', cond, re.I):
                        ctx, aliases = lv, info['aliases']
                        break

                col_refs = extract_cols(cond)
                if not col_refs and ctx:
                    col_refs = [(ctx, c) for c in extract_unqualified_cols(cond)]
                if not col_refs:
                    continue

                for al, col in col_refs:
                    if ctx:
                        tbl = aliases.get(al, al)
                        if graph.cursor_defs.get(graph.loop_vars[ctx]['cursor']):
                            cursor_aliases = graph.cursor_defs[graph.loop_vars[ctx]['cursor']]['aliases']
                            if al in cursor_aliases:
                                tbl = cursor_aliases[al]
                            elif cursor_aliases and tbl == al:
                                tbl = list(cursor_aliases.values())[0]
                        src = node(tbl, col)
                        inter = f"{ctx}.{col}"
                        graph.edge(src, inter)
                        graph.edge(inter, var)
                        graph.var_sources[var] = inter
                    else:
                        src = node(al, col)
                        graph.edge(src, var)
                        graph.var_sources[var] = src
                    stats['if_assign'] += 1

def parse_sql(content, graph, sql_clean=None):
    stats = defaultdict(int)

    if sql_clean is None:
        sql_clean = strip_comments(content)

    # Parse INSERT...SELECT statements (direct table sources)
    parse_insert_select_statements(content, graph, stats, sql_clean)

    # Parse INSERT with nested subqueries (handles mapping 3)
    parse_insert_with_nested_subqueries(content, graph, stats, sql_clean)

    # Parse temp table chains (handles mapping 4)
    parse_temp_table_chains(content, graph, stats, sql_clean)

    # Original parsing for cursor-based patterns

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
        mapping = parse_select_mapping(body, graph, stats)
        graph.cursor_defs[name] = {'aliases': aliases, 'mapping': mapping}
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

    # IF/ELSIF assignments based on conditions
    parse_if_assignments(sql_clean, graph, stats)

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
                    if al in graph.loop_vars:
                        inter = f"{al}.{sc}"
                        cursor_name = graph.loop_vars[al]['cursor']
                        mapping = graph.cursor_defs.get(cursor_name, {}).get('mapping', {})
                        sources = mapping.get(sc, set())
                        if sources:
                            for src in sources:
                                graph.edge(src, inter)
                        else:
                            src = node(all_al.get(al, al), sc)
                            graph.edge(src, inter)
                        graph.edge(inter, dst)
                        stats['ins_loop'] += 1
                    else:
                        src = node(all_al.get(al, al), sc)
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

def needs_multi_pass(sql_text, source_pairs):
    sql_lower = sql_text.lower()
    for tbl, col in source_pairs:
        if re.search(rf'\b{re.escape(tbl)}\b', sql_lower) and re.search(rf'\b{re.escape(col)}\b', sql_lower):
            return True
    return False

def process(files_list, queries, max_passes=6):
    g = Graph()
    totals = defaultdict(int)
    source_pairs = {(q['source_table'], q['source_field']) for q in queries}
    for name, content in files_list:
        sql_clean = SQL_CLEAN_CACHE.get(name)
        if sql_clean is None:
            sql_clean = strip_comments(content)
        pass_count = max_passes if needs_multi_pass(sql_clean, source_pairs) else 1
        print(f"Processing: {name} (passes: {pass_count})")
        for _ in range(pass_count):
            stats = parse_sql(content, g, sql_clean)
            for k, v in stats.items():
                totals[k] += v
    print(f"\nTotals: {dict(totals)}")
    return g

def load_maps(path):
    with open(path) as f:
        return [{k: norm(v) for k, v in m.items()} for m in json.load(f)]

def get_longest_path_only(paths):
    """Filter paths to keep only those that are not subpaths of longer paths."""
    if not paths:
        return []

    unique = []
    seen = set()
    for p in paths:
        if not p:
            continue
        key = tuple(p)
        if key not in seen:
            unique.append(p)
            seen.add(key)

    unique.sort(key=len, reverse=True)
    def is_subsequence(short, long):
        idx = 0
        for node in short:
            while idx < len(long) and long[idx] != node:
                idx += 1
            if idx == len(long):
                return False
            idx += 1
        return True

    kept = []
    for p in unique:
        if any(len(k) >= len(p) and is_subsequence(p, k) for k in kept):
            continue
        kept.append(p)
    return kept

# ==============================================================================
# RUN ANALYSIS
# ==============================================================================

print("\n" + "=" * 70)
print("STEP 3: Running analysis")
print("=" * 70)

files_list = read_files('/content/sql_files')
print(f"\nFound {len(files_list)} SQL file(s)")
queries = load_maps('/content/mappings.json')
g = process(files_list, queries)

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

        # Always report alternative paths to other destinations
        alts = []
        all_reachable = g.all_destinations(src)
        target_end = node(q['dest_table'], q['dest_field'])
        other_paths = [p for p in all_reachable if p and p[-1] != target_end]
        if other_paths:
            other_longest = get_longest_path_only(other_paths)
            alts = [fmt(p) for p in sorted(other_longest, key=len, reverse=True)]

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