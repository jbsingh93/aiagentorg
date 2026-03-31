/* ===================================================================
   OrgAgent Dashboard — Client-Side JavaScript
   Tab switching, API fetch, polling, D3 org chart, Chart.js budget,
   kanban rendering, thread view, activity stream, approval actions.
   =================================================================== */

(function () {
  'use strict';

  // -------------------------------------------------------------------
  // Config
  // -------------------------------------------------------------------
  const POLL_INTERVAL = 5000; // 5 seconds
  const API           = '/api';

  // -------------------------------------------------------------------
  // State cache (avoids redundant re-renders when data hasn't changed)
  // -------------------------------------------------------------------
  let cache = {};
  let budgetChart        = null;
  let overviewBudgetChart = null;
  let auditPage          = 1;

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------
  function $(sel)  { return document.querySelector(sel); }
  function $$(sel) { return document.querySelectorAll(sel); }

  async function api(path) {
    try {
      const res = await fetch(API + path);
      if (!res.ok) return null;
      return await res.json();
    } catch (_) { return null; }
  }

  async function apiPost(path, body) {
    try {
      const res = await fetch(API + path, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      return await res.json();
    } catch (_) { return null; }
  }

  function esc(str) {
    const d = document.createElement('div');
    d.textContent = str || '';
    return d.innerHTML;
  }

  function fmtDate(d) {
    if (!d) return '';
    const dt = new Date(d);
    if (isNaN(dt.getTime())) return String(d);
    return dt.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function fmtTime(d) {
    if (!d) return '';
    const dt = new Date(d);
    if (isNaN(dt.getTime())) return String(d).slice(11, 16);
    return dt.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  }

  function fmtCurrency(val, currency) {
    if (val === null || val === undefined) return '--';
    const sym = { USD: '$', EUR: '\u20AC', GBP: '\u00A3', DKK: 'DKK ', SEK: 'SEK ', NOK: 'NOK ' };
    const prefix = sym[currency] || (currency ? currency + ' ' : '$');
    return prefix + Number(val).toFixed(2);
  }

  function statusDotClass(status) {
    const s = (status || '').toLowerCase().replace(/ /g, '-');
    return 'status-dot status-' + s;
  }

  function badgeClass(type) {
    const t = (type || 'message').toLowerCase().replace(/ /g, '-');
    return 'badge badge-' + t;
  }

  // -------------------------------------------------------------------
  // Tab switching
  // -------------------------------------------------------------------
  function initTabs() {
    $$('.tab').forEach(btn => {
      btn.addEventListener('click', () => {
        $$('.tab').forEach(b => b.classList.remove('active'));
        $$('.tab-panel').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');
        const panel = $('#panel-' + btn.dataset.tab);
        if (panel) panel.classList.add('active');
        // Trigger render for newly visible panel
        loadActivePanel();
      });
    });
  }

  function activeTab() {
    const btn = document.querySelector('.tab.active');
    return btn ? btn.dataset.tab : 'overview';
  }

  // -------------------------------------------------------------------
  // Clock
  // -------------------------------------------------------------------
  function tickClock() {
    const el = $('#headerClock');
    if (el) {
      const now = new Date();
      el.textContent = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }
  }

  // -------------------------------------------------------------------
  // OVERVIEW panel
  // -------------------------------------------------------------------
  async function loadOverview() {
    const [agents, tasks, approvals, messages, budget] = await Promise.all([
      api('/agents'),
      api('/tasks'),
      api('/approvals'),
      api('/messages'),
      api('/budget'),
    ]);

    // Agent count
    const activeAgents = (agents || []).filter(a => a.status === 'active');
    $('#statAgentCount').textContent   = activeAgents.length;

    // Task counts
    const taskList    = tasks || [];
    const activeTasks = taskList.filter(t => t.status === 'active');
    const doneTasks   = taskList.filter(t => t.status === 'done');
    $('#statActiveTaskCount').textContent = activeTasks.length;
    $('#statDoneTaskCount').textContent   = doneTasks.length;

    // Pending approvals
    $('#statPendingCount').textContent = (approvals || []).length;

    // Budget
    const b = budget || {};
    $('#statBudgetSpent').textContent = fmtCurrency(b.spent, b.currency);

    // Threads
    const threads = messages || [];
    const activeThreads = threads.filter(t => t.status === 'active');
    $('#statThreadCount').textContent = activeThreads.length;

    // Recent activity (mini-table)
    const audit = await api('/audit?limit=8');
    const el = $('#overviewActivity');
    if (audit && audit.entries && audit.entries.length) {
      el.innerHTML = '<table class="data-table"><thead><tr><th>Time</th><th>Agent</th><th>Action</th><th>Details</th></tr></thead><tbody>' +
        audit.entries.map(e =>
          `<tr><td>${esc(fmtTime(e.timestamp))}</td><td>${esc(e.agent)}</td><td>${esc(e.action)}</td><td>${esc((e.details || '').slice(0, 60))}</td></tr>`
        ).join('') + '</tbody></table>';
    } else {
      el.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x1F4CB;</div>No activity yet. Run /onboard to get started.</div>';
    }

    // Overview budget donut
    renderOverviewBudgetChart(b);
  }

  function renderOverviewBudgetChart(b) {
    const canvas = $('#overviewBudgetChart');
    if (!canvas) return;
    const spent     = b.spent || 0;
    const remaining = (b.total || 0) - spent;

    if (overviewBudgetChart) overviewBudgetChart.destroy();

    overviewBudgetChart = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: ['Spent', 'Remaining'],
        datasets: [{
          data: [spent, Math.max(0, remaining)],
          backgroundColor: ['#f85149', '#3fb950'],
          borderWidth: 0,
        }],
      },
      options: {
        cutout: '65%',
        plugins: {
          legend: { display: true, position: 'bottom', labels: { color: '#8b949e', font: { size: 11 } } },
        },
        responsive: true,
        maintainAspectRatio: true,
      },
    });
  }

  // -------------------------------------------------------------------
  // ORG CHART panel (D3 tree)
  // -------------------------------------------------------------------
  async function loadOrgChart() {
    const data = await api('/orgchart');
    const container = $('#orgchartTree');
    container.innerHTML = '';

    if (!data || !data.tree) {
      container.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x1F333;</div>No orgchart found. Run /onboard to bootstrap the organisation.</div>';
      return;
    }

    const root = d3.hierarchy(data.tree, d => d.children);

    const width  = container.clientWidth || 800;
    const nodeH  = 60;
    const height = Math.max(400, (root.descendants().length) * nodeH);

    const svg = d3.select(container)
      .append('svg')
      .attr('width', width)
      .attr('height', height);

    const g = svg.append('g').attr('transform', 'translate(60, 30)');

    const treeLayout = d3.tree().size([height - 60, width - 180]);
    treeLayout(root);

    // Links
    g.selectAll('.link')
      .data(root.links())
      .join('path')
      .attr('class', 'link')
      .attr('d', d3.linkHorizontal()
        .x(d => d.y)
        .y(d => d.x));

    // Nodes
    const node = g.selectAll('.node')
      .data(root.descendants())
      .join('g')
      .attr('class', 'node')
      .attr('transform', d => `translate(${d.y},${d.x})`);

    // Node circles — coloured by status
    node.append('circle')
      .attr('r', 6)
      .attr('fill', d => {
        const s = (d.data.status || '').toLowerCase();
        if (s === 'active') return '#3fb950';
        if (s === 'human')  return '#bc8cff';
        if (s.includes('pending')) return '#d29922';
        if (s === 'terminated') return '#f85149';
        return '#8b949e';
      })
      .attr('stroke', '#30363d');

    // Labels
    node.append('text')
      .attr('dy', '0.31em')
      .attr('x', d => d.children ? -12 : 12)
      .attr('text-anchor', d => d.children ? 'end' : 'start')
      .text(d => d.data.name + (d.data.title ? ' — ' + d.data.title : ''));
  }

  // -------------------------------------------------------------------
  // AGENTS panel
  // -------------------------------------------------------------------
  async function loadAgents() {
    const agents = await api('/agents');
    const el     = $('#agentsList');

    if (!agents || agents.length === 0) {
      el.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x1F916;</div>No agents found.</div>';
      return;
    }

    el.innerHTML = agents.map(a => `
      <div class="agent-card" data-agent="${esc(a.name)}">
        <div class="agent-card-header">
          <span class="agent-emoji">${a.emoji || '&#x1F916;'}</span>
          <div>
            <div class="agent-name">${esc(a.name)}</div>
            <div class="agent-title">${esc(a.title)}</div>
          </div>
        </div>
        <div class="agent-meta">
          <span><span class="${statusDotClass(a.status)}"></span> ${esc(a.status)}</span>
          <span>${esc(a.model)}</span>
          ${a.department ? '<span>' + esc(a.department) + '</span>' : ''}
        </div>
      </div>
    `).join('');

    // Click to expand detail
    el.querySelectorAll('.agent-card').forEach(card => {
      card.addEventListener('click', () => showAgentDetail(card.dataset.agent));
    });

    // Also populate the "Send To" dropdown in the threads panel
    populateSendTo(agents);
  }

  async function showAgentDetail(name) {
    const detail = await api('/agent/' + encodeURIComponent(name));
    const el     = $('#agentDetail');
    if (!detail) { el.style.display = 'none'; return; }
    el.style.display = 'block';

    const identity = detail.identity ? detail.identity.data : {};
    const soul     = detail.soul ? detail.soul.body : '';
    const state    = detail.currentState ? detail.currentState.data : null;

    el.innerHTML = `
      <h2>${identity.emoji || ''} ${esc(identity.title || name)}</h2>
      <div class="agent-meta" style="margin-bottom:12px">
        <span><span class="${statusDotClass(identity.status)}"></span> ${esc(identity.status || '')}</span>
        <span>Model: ${esc(identity.model || '')}</span>
        <span>Reports to: ${esc(identity.reports_to || '')}</span>
      </div>
      ${soul ? '<h3>Soul</h3><pre>' + esc(soul.trim()) + '</pre>' : ''}
      ${state ? '<h3>Current State</h3><pre>' + esc(JSON.stringify(state, null, 2)) + '</pre>' : ''}
      <h3>Tasks (${detail.tasks.length})</h3>
      ${detail.tasks.length ? '<ul>' + detail.tasks.map(t => `<li><strong>${esc(t.title || t.id)}</strong> — ${esc(t._status || t.status)}</li>`).join('') + '</ul>' : '<p class="empty-state">No tasks</p>'}
      <h3>Reports (${detail.reports.length})</h3>
      ${detail.reports.length ? '<ul>' + detail.reports.map(r => `<li>${esc(r.file)}</li>`).join('') + '</ul>' : '<p class="empty-state">No reports</p>'}
    `;
  }

  // -------------------------------------------------------------------
  // TASKS panel (Kanban)
  // -------------------------------------------------------------------
  async function loadTasks() {
    const tasks = await api('/tasks');

    const buckets = { backlog: [], active: [], done: [] };
    (tasks || []).forEach(t => {
      const s = t.status || t._dir || 'backlog';
      if (buckets[s]) buckets[s].push(t);
      else if (s === 'blocked') buckets.active.push(t);
      else buckets.backlog.push(t);
    });

    for (const [status, list] of Object.entries(buckets)) {
      const el = $(`#kanban-${status}`);
      if (!el) continue;

      if (list.length === 0) {
        el.innerHTML = '<div class="empty-state" style="padding:20px 0">No tasks</div>';
        continue;
      }

      el.innerHTML = list.map(t => `
        <div class="kanban-card priority-${esc(t.priority)}">
          <div class="kanban-card-title">${esc(t.title)}</div>
          <div class="kanban-card-meta">
            <span>${esc(t.assignedTo)}</span>
            <span>${t.deadline ? fmtDate(t.deadline) : ''}</span>
          </div>
        </div>
      `).join('');
    }
  }

  // -------------------------------------------------------------------
  // THREADS panel
  // -------------------------------------------------------------------
  async function loadThreads() {
    const dept  = $('#threadDeptFilter') ? $('#threadDeptFilter').value : '';
    const query = dept ? '?department=' + encodeURIComponent(dept) : '';
    const threads = await api('/messages' + query);
    const el = $('#threadsList');

    if (!threads || threads.length === 0) {
      el.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x1F4AC;</div>No threads found.</div>';
      return;
    }

    // Collect unique departments for filter
    const depts = new Set();
    threads.forEach(t => { if (t.department) depts.add(t.department); });
    const select = $('#threadDeptFilter');
    if (select) {
      const current = select.value;
      // Only rebuild options if set changed
      const optionVals = Array.from(select.options).map(o => o.value).sort().join(',');
      const newVals = ['', ...Array.from(depts).sort()].join(',');
      if (optionVals !== newVals) {
        select.innerHTML = '<option value="">All</option>' + Array.from(depts).sort().map(d => `<option value="${esc(d)}">${esc(d)}</option>`).join('');
        select.value = current;
      }
    }

    el.innerHTML = threads.map((t, idx) => `
      <div class="thread-card" data-idx="${idx}">
        <div class="thread-header" data-idx="${idx}">
          <div>
            <span class="thread-topic">${esc(t.topic)}</span>
            <span class="thread-dept">${esc(t.department)}</span>
          </div>
          <div class="thread-meta">${t.messageCount || t.messages.length} msgs &middot; ${fmtDate(t.lastActivity || t.created)}</div>
        </div>
        <div class="thread-messages" id="thread-msgs-${idx}">
          ${t.messages.map(m => `
            <div class="message-block">
              <div class="message-routing">
                ${esc(m.from)} &rarr; ${esc(m.to)}
                <span class="${badgeClass(m.type)}">${esc(m.type)}</span>
                <span class="message-timestamp">${fmtTime(m.timestamp)}</span>
              </div>
              <div class="message-body">${esc(m.body)}</div>
            </div>
          `).join('')}
        </div>
      </div>
    `).join('');

    // Collapse / expand threads
    el.querySelectorAll('.thread-header').forEach(hdr => {
      hdr.addEventListener('click', () => {
        const msgs = $(`#thread-msgs-${hdr.dataset.idx}`);
        if (msgs) msgs.classList.toggle('open');
      });
    });
  }

  // Filter change
  if ($('#threadDeptFilter')) {
    $('#threadDeptFilter').addEventListener('change', loadThreads);
  }

  // -------------------------------------------------------------------
  // BUDGET panel
  // -------------------------------------------------------------------
  async function loadBudget() {
    const b = await api('/budget');
    if (!b) return;

    // Summary stats
    const el = $('#budgetSummary');
    el.innerHTML = `
      <div class="budget-stat"><span class="budget-stat-label">Total</span><span class="budget-stat-value">${fmtCurrency(b.total, b.currency)}</span></div>
      <div class="budget-stat"><span class="budget-stat-label">Allocated</span><span class="budget-stat-value">${fmtCurrency(b.allocated, b.currency)}</span></div>
      <div class="budget-stat"><span class="budget-stat-label">Spent</span><span class="budget-stat-value" style="color:var(--accent-red)">${fmtCurrency(b.spent, b.currency)}</span></div>
      <div class="budget-stat"><span class="budget-stat-label">Remaining</span><span class="budget-stat-value" style="color:var(--accent-green)">${fmtCurrency(b.remaining, b.currency)}</span></div>
    `;

    // Donut chart
    renderBudgetDonut(b);

    // Agent table
    const tbl = $('#budgetAgentsTable');
    if (b.agents && b.agents.length) {
      tbl.innerHTML = `<table class="data-table"><thead><tr><th>Agent</th><th>Role</th><th>Budget</th><th>Spent</th><th>Remaining</th><th>Model</th></tr></thead><tbody>` +
        b.agents.map(a => `<tr><td>${esc(a.agent)}</td><td>${esc(a.role)}</td><td>${fmtCurrency(a.budget, b.currency)}</td><td>${fmtCurrency(a.spent, b.currency)}</td><td>${fmtCurrency(a.remaining, b.currency)}</td><td>${esc(a.model)}</td></tr>`).join('') +
        '</tbody></table>';
    } else {
      tbl.innerHTML = '<div class="empty-state">No budget allocations.</div>';
    }

    // Transactions
    const txEl = $('#budgetTransactions');
    if (b.recentTransactions && b.recentTransactions.length) {
      txEl.innerHTML = `<table class="data-table"><thead><tr><th>Time</th><th>Agent</th><th>Action</th><th>Cost</th><th>Running Total</th></tr></thead><tbody>` +
        b.recentTransactions.map(t => `<tr><td>${esc(fmtTime(t.timestamp))}</td><td>${esc(t.agent)}</td><td>${esc(t.action)}</td><td>${fmtCurrency(t.cost, b.currency)}</td><td>${fmtCurrency(t.runningTotal, b.currency)}</td></tr>`).join('') +
        '</tbody></table>';
    } else {
      txEl.innerHTML = '<div class="empty-state">No transactions recorded.</div>';
    }
  }

  function renderBudgetDonut(b) {
    const canvas = $('#budgetDonutChart');
    if (!canvas) return;
    const spent     = b.spent || 0;
    const allocated = (b.allocated || 0) - spent;
    const unalloc   = (b.total || 0) - (b.allocated || 0);

    if (budgetChart) budgetChart.destroy();

    budgetChart = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: ['Spent', 'Allocated (unspent)', 'Unallocated'],
        datasets: [{
          data: [spent, Math.max(0, allocated), Math.max(0, unalloc)],
          backgroundColor: ['#f85149', '#58a6ff', '#3fb950'],
          borderWidth: 0,
        }],
      },
      options: {
        cutout: '60%',
        plugins: {
          legend: { position: 'bottom', labels: { color: '#8b949e', font: { size: 11 } } },
        },
        responsive: true,
        maintainAspectRatio: true,
      },
    });
  }

  // -------------------------------------------------------------------
  // BOARD (approvals) panel
  // -------------------------------------------------------------------
  async function loadApprovals() {
    const list = await api('/approvals');
    const el   = $('#approvalsList');

    if (!list || list.length === 0) {
      el.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x2705;</div>No pending approvals.</div>';
      return;
    }

    el.innerHTML = list.map(a => `
      <div class="approval-card" data-id="${esc(a.id)}">
        <div class="approval-header">
          <div>
            <span class="approval-type">${esc(a.type)}</span>
            <strong style="margin-left:8px">${esc(a.id)}</strong>
          </div>
          <span style="font-size:0.78rem;color:var(--text-secondary)">Proposed by ${esc(a.proposedBy)} &middot; ${fmtDate(a.date)}</span>
        </div>
        <div class="approval-summary">${esc(a.summary)}</div>
        <div class="approval-actions">
          <button class="btn btn-green approve-btn" data-id="${esc(a.id)}">Approve</button>
          <button class="btn btn-red reject-btn" data-id="${esc(a.id)}">Reject</button>
        </div>
      </div>
    `).join('');

    // Wire up buttons
    el.querySelectorAll('.approve-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        btn.disabled = true;
        btn.textContent = 'Approving...';
        await apiPost('/approvals/' + encodeURIComponent(btn.dataset.id) + '/approve', {});
        loadApprovals();
      });
    });

    el.querySelectorAll('.reject-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const reason = prompt('Rejection reason (optional):');
        btn.disabled = true;
        btn.textContent = 'Rejecting...';
        await apiPost('/approvals/' + encodeURIComponent(btn.dataset.id) + '/reject', { reason: reason || '' });
        loadApprovals();
      });
    });
  }

  // -------------------------------------------------------------------
  // ACTIVITY (audit log) panel
  // -------------------------------------------------------------------
  async function loadAudit() {
    const data = await api('/audit?page=' + auditPage + '&limit=50');
    const el   = $('#auditTable');

    if (!data || !data.entries || data.entries.length === 0) {
      el.innerHTML = '<div class="empty-state"><div class="empty-state-icon">&#x1F4DC;</div>No audit entries.</div>';
      return;
    }

    el.innerHTML = `<table class="data-table"><thead><tr><th>Timestamp</th><th>Agent</th><th>Action</th><th>Target</th><th>Details</th></tr></thead><tbody>` +
      data.entries.map(e => `<tr><td>${esc(e.timestamp)}</td><td>${esc(e.agent)}</td><td>${esc(e.action)}</td><td>${esc(e.target)}</td><td>${esc(e.details)}</td></tr>`).join('') +
      '</tbody></table>';

    $('#auditPageInfo').textContent = `Page ${data.page} of ${Math.ceil(data.total / 50) || 1}`;
    $('#auditPrev').disabled = data.page <= 1;
    $('#auditNext').disabled = (data.page * 50) >= data.total;
  }

  // Pagination
  if ($('#auditPrev')) {
    $('#auditPrev').addEventListener('click', () => { auditPage = Math.max(1, auditPage - 1); loadAudit(); });
  }
  if ($('#auditNext')) {
    $('#auditNext').addEventListener('click', () => { auditPage += 1; loadAudit(); });
  }

  // -------------------------------------------------------------------
  // Send as Board form
  // -------------------------------------------------------------------
  function populateSendTo(agents) {
    const sel = $('#sendTo');
    if (!sel) return;
    sel.innerHTML = (agents || []).map(a => `<option value="${esc(a.name)}">${a.emoji || ''} ${esc(a.name)}</option>`).join('');
  }

  if ($('#boardSendForm')) {
    $('#boardSendForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const to   = $('#sendTo').value;
      const body = $('#sendBody').value;
      if (!to || !body) return;

      // The dashboard doesn't have a POST /api/messages endpoint by spec,
      // so we log it as a board directive note and refresh.
      alert('Board message to ' + to + ' noted. In a live org, the /message skill handles delivery through the filesystem.');
      $('#sendBody').value = '';
    });
  }

  // -------------------------------------------------------------------
  // Master load dispatcher
  // -------------------------------------------------------------------
  async function loadActivePanel() {
    const tab = activeTab();
    switch (tab) {
      case 'overview': await loadOverview(); break;
      case 'orgchart': await loadOrgChart(); break;
      case 'agents':   await loadAgents();   break;
      case 'tasks':    await loadTasks();    break;
      case 'threads':  await loadThreads();  break;
      case 'budget':   await loadBudget();   break;
      case 'board':    await loadApprovals(); break;
      case 'activity': await loadAudit();    break;
    }
  }

  // -------------------------------------------------------------------
  // WebSocket — Real-time updates from file watcher
  // -------------------------------------------------------------------
  let ws = null;
  let wsReconnectTimer = null;
  let wsConnected = false;

  // Map of file-change categories to which panels need refreshing
  const CATEGORY_PANELS = {
    threads:    ['threads', 'overview'],
    tasks:      ['tasks', 'overview'],
    agents:     ['agents', 'overview', 'orgchart'],
    budget:     ['budget', 'overview'],
    audit:      ['activity'],
    approvals:  ['board', 'overview'],
    activity:   ['activity', 'agents'],
    messages:   ['threads'],
    orgchart:   ['orgchart', 'overview', 'agents'],
    connectors: ['overview'],
    skills:     ['overview'],
    general:    ['overview']
  };

  function connectWebSocket() {
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    ws = new WebSocket(`${protocol}//${location.host}`);

    ws.onopen = () => {
      wsConnected = true;
      console.log('[WS] Connected — real-time updates active');
      updateConnectionStatus(true);
    };

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);

        if (data.type === 'file-change') {
          const tab = activeTab();
          const panelsToRefresh = CATEGORY_PANELS[data.category] || ['overview'];

          // Only refresh if the active panel needs it
          if (panelsToRefresh.includes(tab)) {
            loadActivePanel();
          }

          // Always show a subtle flash indicator
          showChangeIndicator(data);
        }
      } catch (e) {
        console.warn('[WS] Parse error:', e);
      }
    };

    ws.onclose = () => {
      wsConnected = false;
      console.log('[WS] Disconnected — falling back to polling');
      updateConnectionStatus(false);
      // Reconnect after 3 seconds
      wsReconnectTimer = setTimeout(connectWebSocket, 3000);
    };

    ws.onerror = () => {
      ws.close();
    };
  }

  function updateConnectionStatus(connected) {
    const indicator = $('#ws-status');
    if (indicator) {
      indicator.className = connected ? 'ws-connected' : 'ws-disconnected';
      indicator.title = connected ? 'Real-time: connected' : 'Real-time: reconnecting...';
    }
  }

  function showChangeIndicator(data) {
    // Flash the relevant tab to show something changed
    const tabMap = {
      threads: 'threads', tasks: 'tasks', agents: 'agents',
      budget: 'budget', audit: 'activity', approvals: 'board',
      activity: 'activity', messages: 'threads', orgchart: 'orgchart'
    };
    const tabName = tabMap[data.category];
    if (tabName) {
      const tabBtn = document.querySelector(`.tab-btn[data-tab="${tabName}"]`);
      if (tabBtn && !tabBtn.classList.contains('active')) {
        tabBtn.classList.add('tab-flash');
        setTimeout(() => tabBtn.classList.remove('tab-flash'), 1500);
      }
    }
  }

  // -------------------------------------------------------------------
  // Fallback Polling (only when WebSocket is disconnected)
  // -------------------------------------------------------------------
  function startFallbackPolling() {
    setInterval(async () => {
      if (!wsConnected) {
        await loadActivePanel();
      }
    }, POLL_INTERVAL);
  }

  // -------------------------------------------------------------------
  // Init
  // -------------------------------------------------------------------
  function init() {
    initTabs();
    tickClock();
    setInterval(tickClock, 1000);

    // Org name in header
    api('/budget').then(b => {
      // budget response may include config info; we also try agents
      // For now just show "Dashboard"
    });

    loadActivePanel();

    // Connect WebSocket for real-time updates
    connectWebSocket();

    // Fallback polling every 5s (only fires when WS is disconnected)
    startFallbackPolling();
  }

  // Wait for DOM
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
