#!/usr/bin/env python3
"""
Knowledge Base RAG Query Engine

Retrieves relevant chunks from qmd index and generates answers
using Antigravity LLM API.

Usage:
  python3 rag_query.py "your question here"
  python3 rag_query.py "question" --collection kb-articles
  python3 rag_query.py "question" --top-k 10 --model gemini-3.1-pro-high
  python3 rag_query.py "question" --retrieve-only  # just show chunks, no LLM
  python3 rag_query.py "question" --json            # JSON output
"""

import argparse
import json
import subprocess
import sys
import os
import urllib.request
from typing import Optional, List, Dict

ANTIGRAVITY_URL = os.environ.get("ANTIGRAVITY_URL", "http://127.0.0.1:8045/v1/chat/completions")
ANTIGRAVITY_KEY = os.environ.get("ANTIGRAVITY_KEY", "")
DEFAULT_MODEL = "gemini-3.1-pro-high"

import re

# Stop words for Chinese BM25 query extraction
CN_STOP_WORDS = set("的 了 在 是 我 有 和 就 不 人 都 一 一个 上 也 很 到 说 要 去 你 会 着 没有 看 好 自己 这 他 她 它 们 那 "
                     "什么 怎么 如何 哪些 为什么 多少 对 关于 有什么 有哪些 吗 呢 吧 啊 嘛 呀 哦 哈 嗯 么".split())

def extract_keywords(query: str) -> str:
    """Extract keywords from natural language query for BM25 search.
    Strips question patterns and common particles, then segments Chinese text.
    """
    q = query
    # Remove Chinese question patterns
    q = re.sub(r'(有什么|有哪些|是什么|怎么样|如何|为什么|怎么|多少|哪些|什么样的?)', ' ', q)
    # Remove particles and prepositions
    q = re.sub(r'(对于|关于|以及|而且|但是|因为|所以|或者|还是|虽然|如果)', ' ', q)
    # Remove single-char particles/prepositions (aggressive but effective for BM25)
    for particle in '对在的了吗呢吧啊嘛呀与和跟从把被给让向往':
        q = q.replace(particle, ' ')
    # Remove subjective/evaluation words that rarely appear in source text
    q = re.sub(r'(看法|观点|想法|意见|态度|评价|认为|觉得|分析|讨论|介绍|描述|提到|说过)', ' ', q)
    # Remove punctuation
    q = re.sub(r'[,，。？！、；：""（）\[\]【】《》]', ' ', q)
    # Segment: insert space at CJK/ASCII boundaries and between CJK bigrams
    # This helps BM25 tokenize Chinese text properly
    q = _segment_for_bm25(q)
    # Remove single CJK characters (too noisy for BM25, kills results)
    tokens = q.split()
    tokens = [t for t in tokens if not (len(t) == 1 and '\u4e00' <= t <= '\u9fff')]
    q = ' '.join(tokens)
    # Collapse whitespace
    q = re.sub(r'\s+', ' ', q).strip()
    return q if q else query


def _segment_for_bm25(text: str) -> str:
    """Insert spaces between CJK characters to help BM25 tokenize.
    Simply adds a space between every 2 CJK characters (non-overlapping).
    E.g., '开源商业化' -> '开源 商业 化'
    ASCII words are kept as-is.
    """
    result = []
    i = 0
    while i < len(text):
        ch = text[i]
        if '\u4e00' <= ch <= '\u9fff':
            # CJK: collect sequence
            cjk_start = i
            while i < len(text) and '\u4e00' <= text[i] <= '\u9fff':
                i += 1
            cjk_seq = text[cjk_start:i]
            # Split into 2-char words (non-overlapping)
            words = [cjk_seq[j:j+2] for j in range(0, len(cjk_seq), 2)]
            result.extend(words)
        else:
            start = i
            while i < len(text) and not ('\u4e00' <= text[i] <= '\u9fff'):
                i += 1
            result.append(text[start:i])
    return ' '.join(result)


SYSTEM_PROMPT = """你是一个知识库问答助手。基于检索到的上下文片段回答用户的问题。

规则：
1. 只基于提供的上下文回答，不编造信息
2. 如果上下文不足以回答，明确说明
3. 引用来源文件（用 [source: 文件路径] 格式）
4. 回答要简洁、准确、有结构
5. 如果多个来源有相关信息，综合回答并分别标注来源"""


def qmd_search(query: str, top_k: int = 8, collection: Optional[str] = None, mode: str = "hybrid") -> List[Dict]:
    """Run qmd search and parse results.
    mode: 'hybrid' (vector + BM25 merged, default), 'vsearch' (vector only), 'search' (BM25 only)
    """
    if mode == "hybrid":
        # Run both vsearch and BM25, merge and deduplicate
        return _hybrid_search(query, top_k, collection)

    cmd = ["qmd", mode, query, "-n", str(top_k), "--json"]
    if collection:
        cmd.extend(["-c", collection])

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        print(f"qmd error: {result.stderr}", file=sys.stderr)
        return []

    try:
        data = json.loads(result.stdout)
        return data if isinstance(data, list) else data.get("results", [])
    except json.JSONDecodeError:
        print(f"Failed to parse qmd JSON output", file=sys.stderr)
        return []


def _hybrid_search(query: str, top_k: int, collection: Optional[str] = None) -> List[Dict]:
    """Merge vector and BM25 results using Reciprocal Rank Fusion (RRF).
    RRF normalizes across different scoring scales (vector 0.5-0.7 vs BM25 0.01-0.3).
    """
    fetch_k = top_k + 4

    def _run(search_mode: str, q: str = query) -> List[Dict]:
        cmd = ["qmd", search_mode, q, "-n", str(fetch_k), "--json"]
        if collection:
            cmd.extend(["-c", collection])
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            return []
        try:
            data = json.loads(result.stdout)
            return data if isinstance(data, list) else data.get("results", [])
        except json.JSONDecodeError:
            return []

    vector_results = _run("vsearch", query)
    # Run BM25 with extracted keywords
    bm25_query = extract_keywords(query)
    bm25_results = _run("search", bm25_query)
    # Also run BM25 with just the topic keywords (without proper nouns)
    # This catches chunks where the topic is discussed without repeating the entity name
    topic_query = re.sub(r'[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*', '', bm25_query).strip()
    topic_query = re.sub(r'\s+', ' ', topic_query).strip()
    if topic_query and topic_query != bm25_query:
        topic_results = _run("search", topic_query)
        bm25_results.extend(topic_results)

    # Interleave: take top vector results but insert BM25 hits early
    # BM25 finds precise keyword matches that vector misses (especially in long docs)
    seen_snippets = set()
    combined = []

    # Tag sources
    for chunk in vector_results:
        chunk["_source"] = "vector"
    for chunk in bm25_results:
        chunk["_source"] = "bm25"

    # Insert BM25 results at position 2 (after top vector hit, before the rest)
    # This ensures keyword matches from deep in long docs surface early
    vec_idx = 0
    bm25_idx = 0
    insert_bm25_after = 1  # insert BM25 results after first vector result

    while len(combined) < top_k:
        # First: take some vector results
        if vec_idx < len(vector_results) and (len(combined) < insert_bm25_after or bm25_idx >= len(bm25_results)):
            chunk = vector_results[vec_idx]
            vec_idx += 1
            snippet_fp = chunk.get("snippet", "")[:80]
            if snippet_fp not in seen_snippets:
                seen_snippets.add(snippet_fp)
                combined.append(chunk)
            continue

        # Then: insert BM25 results
        if bm25_idx < len(bm25_results):
            chunk = bm25_results[bm25_idx]
            bm25_idx += 1
            snippet_fp = chunk.get("snippet", "")[:80]
            if snippet_fp not in seen_snippets:
                seen_snippets.add(snippet_fp)
                combined.append(chunk)
            continue

        # Remaining vector results
        if vec_idx < len(vector_results):
            chunk = vector_results[vec_idx]
            vec_idx += 1
            snippet_fp = chunk.get("snippet", "")[:80]
            if snippet_fp not in seen_snippets:
                seen_snippets.add(snippet_fp)
                combined.append(chunk)
            continue

        break  # no more results

    return combined


def format_context(chunks: List[Dict]) -> str:
    """Format retrieved chunks into context string."""
    if not chunks:
        return "(无检索结果)"

    parts = []
    for i, chunk in enumerate(chunks, 1):
        source = chunk.get("file", chunk.get("docId", chunk.get("path", "unknown")))
        score = chunk.get("score", 0)
        snippet = chunk.get("snippet", chunk.get("text", ""))
        title = chunk.get("title", "")
        # Clean up source for display
        source = source.replace("qmd://", "")
        header = f"--- Chunk {i} [{source}] (score: {score:.2f})"
        if title:
            header += f" | {title}"
        header += " ---"
        parts.append(f"{header}\n{snippet}")

    return "\n\n".join(parts)


def llm_generate(question: str, context: str, model: str = DEFAULT_MODEL) -> str:
    """Call Antigravity LLM API to generate answer."""
    user_content = f"""## 检索到的上下文

{context}

## 用户问题

{question}"""

    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content}
        ],
        "temperature": 0.3,
        "max_tokens": 2048
    }).encode("utf-8")

    req = urllib.request.Request(
        ANTIGRAVITY_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {ANTIGRAVITY_KEY}"
        },
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        return f"LLM 调用失败: {e}"


def main():
    parser = argparse.ArgumentParser(description="Knowledge Base RAG Query")
    parser.add_argument("query", help="Question to ask")
    parser.add_argument("-c", "--collection", help="Limit search to specific collection")
    parser.add_argument("-k", "--top-k", type=int, default=8, help="Number of chunks to retrieve (default: 8)")
    parser.add_argument("-m", "--model", default=DEFAULT_MODEL, help=f"LLM model (default: {DEFAULT_MODEL})")
    parser.add_argument("--mode", choices=["hybrid", "vsearch", "query", "search"], default="hybrid",
                        help="Search mode: hybrid (vector+BM25 merged, default), vsearch (vector only), query (reranker, slow), search (BM25 only)")
    parser.add_argument("--retrieve-only", action="store_true", help="Only retrieve, skip LLM generation")
    parser.add_argument("--json", action="store_true", dest="json_output", help="Output as JSON")
    args = parser.parse_args()

    # Step 1: Retrieve
    chunks = qmd_search(args.query, top_k=args.top_k, collection=args.collection, mode=args.mode)
    context = format_context(chunks)

    if args.retrieve_only:
        if args.json_output:
            print(json.dumps(chunks, ensure_ascii=False, indent=2))
        else:
            print(f"Retrieved {len(chunks)} chunks for: {args.query}\n")
            print(context)
        return

    # Step 2: Generate
    answer = llm_generate(args.query, context, model=args.model)

    if args.json_output:
        output = {
            "query": args.query,
            "model": args.model,
            "chunks_retrieved": len(chunks),
            "sources": list(set(c.get("docId", "") for c in chunks)),
            "answer": answer
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    else:
        print(answer)


if __name__ == "__main__":
    main()
