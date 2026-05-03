import * as XLSX from 'xlsx'

const EXCEL_COLS = ['topicId', 'title', 'description', 'language', 'code', 'expectedOutput', 'xpReward', 'order', 'isActive']

// ─── Excel ────────────────────────────────────────────────────────────────────

export function exportExcel(data, filename) {
  const rows = data.map(s => ({
    topicId: s.topicId ?? '',
    title: s.title ?? '',
    description: s.description ?? '',
    language: s.language ?? 'java',
    code: s.code ?? '',
    expectedOutput: s.expectedOutput ?? '',
    xpReward: s.xpReward ?? 10,
    order: s.order ?? 0,
    isActive: s.isActive ?? true,
  }))
  const ws = XLSX.utils.json_to_sheet(rows, { header: EXCEL_COLS })
  ws['!cols'] = [16, 24, 30, 12, 40, 24, 10, 8, 8].map(wch => ({ wch }))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'CodeSnippets')
  XLSX.writeFile(wb, filename)
}

export function downloadSampleExcel() {
  const sample = [{
    topicId: 'TOPIC_ID_HERE',
    title: 'Đếm tần suất từ',
    description: 'Đếm số lần xuất hiện của mỗi từ trong câu',
    language: 'java',
    code: 'import java.util.*;\npublic class Main {\n    public static void main(String[] args) {\n        String s = "java la ngon ngu manh";\n        for (String w : s.split(" "))\n            System.out.println(w + ": 1");\n    }\n}',
    expectedOutput: 'java: 1\nla: 1\nngon: 1\ngu: 1\nmanh: 1',
    xpReward: 15,
    order: 1,
    isActive: true,
  }]
  exportExcel(sample, 'code_snippets_template.xlsx')
}

export function importExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: 'array' })
        const ws = wb.Sheets[wb.SheetNames[0]]
        const rows = XLSX.utils.sheet_to_json(ws, { defval: '' })
        if (!rows.length) throw new Error('File Excel trống')
        resolve(rows.map(r => ({
          topicId: String(r.topicId ?? ''),
          title: String(r.title ?? ''),
          description: String(r.description ?? ''),
          language: String(r.language ?? 'java'),
          code: String(r.code ?? ''),
          expectedOutput: String(r.expectedOutput ?? ''),
          xpReward: Number(r.xpReward) || 10,
          order: Number(r.order) || 0,
          isActive: r.isActive === false || String(r.isActive).toLowerCase() === 'false' ? false : true,
        })))
      } catch (err) { reject(new Error('File Excel không hợp lệ: ' + err.message)) }
    }
    reader.readAsArrayBuffer(file)
  })
}

// ─── Legacy (kept for other pages) ───────────────────────────────────────────

export function exportJson(data, filename) {
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}

export function exportCsv(rows, headers, filename) {
  const csv = [
    headers.join(','),
    ...rows.map(row => headers.map(h => {
      const val = String(row[h] ?? '').replace(/"/g, '""')
      return val.includes(',') || val.includes('\n') ? `"${val}"` : val
    }).join(','))
  ].join('\n')
  const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}

export function importJson(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try { resolve(JSON.parse(e.target.result)) }
      catch { reject(new Error('File JSON không hợp lệ')) }
    }
    reader.readAsText(file)
  })
}

export function importCsv(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const lines = e.target.result.split('\n').filter(l => l.trim())
        const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''))
        const rows = lines.slice(1).map(line => {
          const vals = line.split(',').map(v => v.trim().replace(/^"|"$/g, ''))
          return Object.fromEntries(headers.map((h, i) => [h, vals[i] ?? '']))
        })
        resolve(rows)
      } catch { reject(new Error('File CSV không hợp lệ')) }
    }
    reader.readAsText(file)
  })
}
