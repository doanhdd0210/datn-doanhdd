import { useState, useEffect, useRef, useCallback } from 'react'
import { Activity, CheckCircle, XCircle, Clock, Wifi, WifiOff, RefreshCw } from 'lucide-react'

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'
const PING_INTERVAL_MS = 10 * 60 * 1000 // 10 phút
const MAX_LOGS = 100

export default function ServerMonitorPage() {
  const [logs, setLogs] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('server_monitor_logs') || '[]')
    } catch { return [] }
  })
  const [pinging, setPinging] = useState(false)
  const timerRef = useRef(null)
  const countdownRef = useRef(null)
  const [nextPingIn, setNextPingIn] = useState(PING_INTERVAL_MS / 1000)

  const ping = useCallback(async () => {
    setPinging(true)
    const start = Date.now()
    let entry
    try {
      const res = await fetch(`${BASE_URL}/health`, { signal: AbortSignal.timeout(10000) })
      const ms = Date.now() - start
      entry = {
        id: start,
        time: new Date().toISOString(),
        status: res.ok ? 'ok' : 'error',
        code: res.status,
        ms,
      }
    } catch (e) {
      entry = {
        id: start,
        time: new Date().toISOString(),
        status: 'error',
        code: 0,
        ms: Date.now() - start,
        error: e.message,
      }
    }
    setLogs(prev => {
      const updated = [entry, ...prev].slice(0, MAX_LOGS)
      localStorage.setItem('server_monitor_logs', JSON.stringify(updated))
      return updated
    })
    setPinging(false)
    setNextPingIn(PING_INTERVAL_MS / 1000)
  }, [])

  useEffect(() => {
    ping()
    timerRef.current = setInterval(ping, PING_INTERVAL_MS)
    return () => clearInterval(timerRef.current)
  }, [ping])

  useEffect(() => {
    countdownRef.current = setInterval(() => {
      setNextPingIn(prev => (prev <= 1 ? PING_INTERVAL_MS / 1000 : prev - 1))
    }, 1000)
    return () => clearInterval(countdownRef.current)
  }, [])

  const successCount = logs.filter(l => l.status === 'ok').length
  const errorCount = logs.filter(l => l.status === 'error').length
  const uptime = logs.length ? Math.round((successCount / logs.length) * 100) : 0
  const avgMs = logs.filter(l => l.status === 'ok').length
    ? Math.round(logs.filter(l => l.status === 'ok').reduce((a, b) => a + b.ms, 0) / logs.filter(l => l.status === 'ok').length)
    : 0
  const lastStatus = logs[0]?.status

  const formatTime = (iso) => {
    const d = new Date(iso)
    return d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) +
      ' ' + d.toLocaleDateString('vi-VN')
  }

  const formatCountdown = (s) => {
    const m = Math.floor(s / 60)
    const sec = s % 60
    return `${m}:${String(sec).padStart(2, '0')}`
  }

  return (
    <div style={{ maxWidth: 900 }}>
      {/* Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 16, marginBottom: 24 }}>
        <StatCard
          label="Trạng thái"
          value={lastStatus === 'ok' ? 'Online' : lastStatus === 'error' ? 'Offline' : '…'}
          Icon={lastStatus === 'ok' ? Wifi : WifiOff}
          color={lastStatus === 'ok' ? '#ecfdf5' : lastStatus === 'error' ? '#fef2f2' : '#f8fafc'}
          iconColor={lastStatus === 'ok' ? '#16a34a' : lastStatus === 'error' ? '#dc2626' : '#94a3b8'}
        />
        <StatCard label="Uptime" value={`${uptime}%`} Icon={Activity} color="#e8f0fe" iconColor="#3b82f6" />
        <StatCard label="Thành công" value={successCount} Icon={CheckCircle} color="#ecfdf5" iconColor="#16a34a" />
        <StatCard label="Lỗi" value={errorCount} Icon={XCircle} color="#fef2f2" iconColor="#dc2626" />
        <StatCard label="Avg response" value={avgMs ? `${avgMs}ms` : '…'} Icon={Clock} color="#fef9c3" iconColor="#ca8a04" />
      </div>

      {/* Ping next + manual */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 20 }}>
        <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 10, padding: '10px 18px', fontSize: 14, color: '#475569' }}>
          Ping tiếp theo: <strong style={{ color: '#1e293b' }}>{formatCountdown(nextPingIn)}</strong>
        </div>
        <button
          onClick={ping}
          disabled={pinging}
          style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: '10px 18px', borderRadius: 10, border: 'none',
            background: '#1a73e8', color: '#fff', cursor: pinging ? 'not-allowed' : 'pointer',
            fontSize: 14, fontWeight: 600, opacity: pinging ? 0.7 : 1,
          }}
        >
          <RefreshCw size={14} style={{ animation: pinging ? 'spin 1s linear infinite' : 'none' }} />
          {pinging ? 'Đang ping…' : 'Ping ngay'}
        </button>
        {logs.length > 0 && (
          <button
            onClick={() => { setLogs([]); localStorage.removeItem('server_monitor_logs') }}
            style={{ padding: '10px 18px', borderRadius: 10, border: '1px solid #e2e8f0', background: '#fff', cursor: 'pointer', fontSize: 14, color: '#dc2626' }}
          >
            Xoá log
          </button>
        )}
      </div>

      {/* Log table */}
      <div style={{ background: '#fff', border: '1px solid #e2e8f0', borderRadius: 12, overflow: 'hidden' }}>
        <div style={{ padding: '14px 20px', borderBottom: '1px solid #e2e8f0', fontWeight: 600, color: '#1e293b', fontSize: 15 }}>
          Lịch sử ping ({logs.length})
        </div>
        {logs.length === 0 ? (
          <div style={{ padding: 40, textAlign: 'center', color: '#94a3b8' }}>Chưa có dữ liệu</div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: '#f8fafc', color: '#64748b', textAlign: 'left' }}>
                  <th style={th}>Thời gian</th>
                  <th style={th}>Trạng thái</th>
                  <th style={th}>HTTP</th>
                  <th style={th}>Response time</th>
                  <th style={th}>Ghi chú</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log, i) => (
                  <tr key={log.id} style={{ borderBottom: '1px solid #f1f5f9', background: i % 2 === 0 ? '#fff' : '#fafafa' }}>
                    <td style={td}>{formatTime(log.time)}</td>
                    <td style={td}>
                      <span style={{
                        display: 'inline-flex', alignItems: 'center', gap: 4,
                        padding: '2px 10px', borderRadius: 20, fontSize: 12, fontWeight: 600,
                        background: log.status === 'ok' ? '#dcfce7' : '#fee2e2',
                        color: log.status === 'ok' ? '#16a34a' : '#dc2626',
                      }}>
                        {log.status === 'ok' ? <CheckCircle size={11} /> : <XCircle size={11} />}
                        {log.status === 'ok' ? 'OK' : 'Error'}
                      </span>
                    </td>
                    <td style={td}>{log.code || '—'}</td>
                    <td style={td}>{log.ms}ms</td>
                    <td style={{ ...td, color: '#dc2626', fontSize: 12 }}>{log.error || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <style>{`@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }`}</style>
    </div>
  )
}

function StatCard({ label, value, Icon, color, iconColor }) {
  return (
    <div style={{ background: color, borderRadius: 12, padding: '20px 24px', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <Icon size={28} color={iconColor} strokeWidth={1.75} />
      <p style={{ margin: 0, fontSize: 28, fontWeight: 700, color: '#1e293b' }}>{value}</p>
      <p style={{ margin: 0, fontSize: 13, color: '#64748b' }}>{label}</p>
    </div>
  )
}

const th = { padding: '10px 16px', fontWeight: 600, fontSize: 12, textTransform: 'uppercase', letterSpacing: 0.5 }
const td = { padding: '10px 16px', color: '#374151' }
