
// Requires window.supabase from CDN <script> in index.html (loads before modules)
// Requires window.APP_CONFIG from config.js

if (!window.APP_CONFIG?.supabaseUrl || !window.APP_CONFIG?.supabaseKey) {
  document.body.innerHTML = `<div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0f172a;color:white;font-family:Arial,sans-serif;padding:40px"><div style="max-width:600px;background:#111827;padding:40px;border-radius:20px;border:1px solid #374151"><h1 style="margin-top:0">Configuration Missing</h1><p style="color:#d1d5db">Create a <code>config.js</code> file based on <code>config.example.js</code>, then reload.</p></div></div>`;
  throw new Error('APP_CONFIG not found — copy config.example.js to config.js');
}

export const sb = window.supabase.createClient(
  window.APP_CONFIG.supabaseUrl,
  window.APP_CONFIG.supabaseKey,
  { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } }
);