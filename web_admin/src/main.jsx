import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'

// Reset CSS cơ bản
const style = document.createElement('style')
style.textContent = `
  *, *::before, *::after { box-sizing: border-box; }
  body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
  input:focus { border-color: #1a73e8 !important; outline: none; }
  button:disabled { opacity: 0.6; cursor: not-allowed; }
  @keyframes spin { to { transform: rotate(360deg); } }
`
document.head.appendChild(style)

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
