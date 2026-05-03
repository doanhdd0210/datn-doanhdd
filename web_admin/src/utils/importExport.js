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

// ─── Topics Excel ─────────────────────────────────────────────────────────────

const TOPICS_COLS = ['title', 'description', 'icon', 'color', 'order', 'isActive']

export function exportTopicsExcel(data, filename = 'topics_export.xlsx') {
  const rows = data.map(t => ({ title: t.title ?? '', description: t.description ?? '', icon: t.icon ?? '', color: t.color ?? '', order: t.order ?? 0, isActive: t.isActive ?? true }))
  const ws = XLSX.utils.json_to_sheet(rows, { header: TOPICS_COLS })
  ws['!cols'] = [20, 30, 8, 10, 8, 8].map(wch => ({ wch }))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Topics')
  XLSX.writeFile(wb, filename)
}

export function downloadTopicsSampleExcel() {
  exportTopicsExcel([{ title: 'Java Cơ Bản', description: 'Biến, kiểu dữ liệu, vòng lặp...', icon: '☕', color: '#F89820', order: 1, isActive: true }], 'topics_template.xlsx')
}

export function importTopicsExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const rows = XLSX.utils.sheet_to_json(XLSX.read(e.target.result, { type: 'array' }).Sheets[XLSX.read(e.target.result, { type: 'array' }).SheetNames[0]], { defval: '' })
        if (!rows.length) throw new Error('File Excel trống')
        resolve(rows.map(r => ({ title: String(r.title ?? ''), description: String(r.description ?? ''), icon: String(r.icon ?? '📚'), color: String(r.color ?? '#58CC02'), order: Number(r.order) || 0, isActive: String(r.isActive).toLowerCase() !== 'false' })))
      } catch (err) { reject(new Error('File Excel không hợp lệ: ' + err.message)) }
    }
    reader.readAsArrayBuffer(file)
  })
}

// ─── Lessons Excel ────────────────────────────────────────────────────────────

const LESSONS_COLS = ['topicId', 'title', 'summary', 'content', 'xpReward', 'estimatedMinutes', 'order', 'isActive']

export function exportLessonsExcel(data, filename = 'lessons_export.xlsx') {
  const rows = data.map(l => ({ topicId: l.topicId ?? '', title: l.title ?? '', summary: l.summary ?? '', content: l.content ?? '', xpReward: l.xpReward ?? 10, estimatedMinutes: l.estimatedMinutes ?? 5, order: l.order ?? 0, isActive: l.isActive ?? true }))
  const ws = XLSX.utils.json_to_sheet(rows, { header: LESSONS_COLS })
  ws['!cols'] = [16, 24, 30, 40, 10, 14, 8, 8].map(wch => ({ wch }))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Lessons')
  XLSX.writeFile(wb, filename)
}

export function downloadLessonsSampleExcel() {
  exportLessonsExcel([{ topicId: 'TOPIC_ID_HERE', title: 'Bài 1: Biến và kiểu dữ liệu', summary: 'Giới thiệu biến, int, String...', content: '', xpReward: 10, estimatedMinutes: 5, order: 1, isActive: true }], 'lessons_template.xlsx')
}

export function importLessonsExcel(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: 'array' })
        const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: '' })
        if (!rows.length) throw new Error('File Excel trống')
        resolve(rows.map(r => ({ topicId: String(r.topicId ?? ''), title: String(r.title ?? ''), summary: String(r.summary ?? ''), content: String(r.content ?? ''), xpReward: Number(r.xpReward) || 10, estimatedMinutes: Number(r.estimatedMinutes) || 5, order: Number(r.order) || 0, isActive: String(r.isActive).toLowerCase() !== 'false' })))
      } catch (err) { reject(new Error('File Excel không hợp lệ: ' + err.message)) }
    }
    reader.readAsArrayBuffer(file)
  })
}

// ─── Questions Excel ──────────────────────────────────────────────────────────

const QUESTIONS_COLS = ['lessonId', 'questionText', 'optionA', 'optionB', 'optionC', 'optionD', 'correctAnswerIndex', 'explanation', 'points', 'order']

export function exportQuestionsExcel(data, filename = 'questions_export.xlsx') {
  const rows = data.map(q => ({ lessonId: q.lessonId ?? '', questionText: q.questionText ?? '', optionA: q.options?.[0] ?? '', optionB: q.options?.[1] ?? '', optionC: q.options?.[2] ?? '', optionD: q.options?.[3] ?? '', correctAnswerIndex: q.correctAnswerIndex ?? 0, explanation: q.explanation ?? '', points: q.points ?? 10, order: q.order ?? 0 }))
  const ws = XLSX.utils.json_to_sheet(rows, { header: QUESTIONS_COLS })
  ws['!cols'] = [16, 36, 20, 20, 20, 20, 16, 28, 8, 8].map(wch => ({ wch }))
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Questions')
  XLSX.writeFile(wb, filename)
}

export function downloadQuestionsSampleExcel() {
  exportQuestionsExcel([{ lessonId: 'LESSON_ID_HERE', questionText: 'Kiểu dữ liệu nào lưu số nguyên trong Java?', options: ['int', 'float', 'String', 'boolean'], correctAnswerIndex: 0, explanation: 'int là kiểu số nguyên cơ bản trong Java', points: 10, order: 1 }], 'questions_template.xlsx')
}

export function importQuestionsExcel(file, defaultLessonId = '') {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => {
      try {
        const wb = XLSX.read(e.target.result, { type: 'array' })
        const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: '' })
        if (!rows.length) throw new Error('File Excel trống')
        resolve(rows.map(r => ({ lessonId: String(r.lessonId || defaultLessonId), questionText: String(r.questionText ?? ''), options: [String(r.optionA ?? ''), String(r.optionB ?? ''), String(r.optionC ?? ''), String(r.optionD ?? '')], correctAnswerIndex: Number(r.correctAnswerIndex) || 0, explanation: String(r.explanation ?? ''), points: Number(r.points) || 10, order: Number(r.order) || 0 })))
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
