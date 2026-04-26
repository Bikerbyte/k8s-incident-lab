const state = {
  actions: [],
  selectedJobId: null,
  pollTimer: null,
  theme: "night",
};

const playgroundLinks = [
  {
    title: "Readiness Runbook",
    detail: "Diagnose pods that run but never become ready.",
    href: "/runbooks/readiness-failure.md",
  },
  {
    title: "High Error Runbook",
    detail: "Follow the HTTP 500 investigation path.",
    href: "/runbooks/high-error-rate.md",
  },
  {
    title: "Self-Healing Runbook",
    detail: "Watch Kubernetes recreate a deleted pod.",
    href: "/runbooks/pod-self-healing.md",
  },
  {
    title: "Architecture Notes",
    detail: "Review the lab components and observability flow.",
    href: "/docs/architecture.md",
  },
  {
    title: "Demo Flow",
    detail: "Run the project as a guided incident demo.",
    href: "/docs/demo-flow.md",
  },
  {
    title: "Alerts Guide",
    detail: "See which Prometheus alerts map to each scenario.",
    href: "/docs/alerts.md",
  },
  {
    title: "Troubleshooting",
    detail: "Use a quick checklist when local access or pods look wrong.",
    href: "/docs/troubleshooting.md",
  },
];

function setText(id, value) {
  document.getElementById(id).textContent = value;
}

function storedTheme() {
  try {
    return localStorage.getItem("lab-console-theme");
  } catch {
    return null;
  }
}

function storeTheme(theme) {
  try {
    localStorage.setItem("lab-console-theme", theme);
  } catch {
    return;
  }
}

function applyTheme(theme) {
  state.theme = theme === "day" ? "day" : "night";
  document.documentElement.dataset.theme = state.theme;
  const button = document.getElementById("themeToggleButton");
  button.textContent = state.theme === "night" ? "Day Theme" : "Night Theme";
  button.setAttribute("aria-pressed", String(state.theme === "day"));
  storeTheme(state.theme);
}

function formatTimestamp(epochSeconds) {
  if (!epochSeconds) return "Unknown time";
  return new Date(epochSeconds * 1000).toLocaleString();
}

function metricCard(label, value, tone = "neutral", detail = "") {
  const article = document.createElement("article");
  article.className = `metric-card tone-${tone}`;
  article.innerHTML = `
    <p class="metric-label">${label}</p>
    <div class="metric-value">${value}</div>
    <p class="metric-detail">${detail}</p>
  `;
  return article;
}

function renderOverview(status) {
  const grid = document.getElementById("overviewGrid");
  grid.innerHTML = "";

  const minikube = status.minikube || {};
  const cluster = status.cluster || {};
  const appPods = status.workloads?.app?.pods || [];
  const monitoringPods = status.workloads?.monitoring?.pods || [];

  grid.appendChild(
    metricCard(
      "Minikube",
      minikube.host || "Unknown",
      minikube.host === "Running" ? "good" : "warn",
      `kubelet: ${minikube.kubelet || "?"}, apiserver: ${minikube.apiserver || "?"}`
    )
  );

  grid.appendChild(
    metricCard(
      "Kubernetes API",
      cluster.reachable ? "Reachable" : "Offline",
      cluster.reachable ? "good" : "danger",
      `${(cluster.nodes || []).length} node(s)`
    )
  );

  const readyAppPods = appPods.filter((pod) => pod.ready.startsWith("1/1")).length;
  grid.appendChild(
    metricCard(
      "Podinfo Pods",
      `${readyAppPods}/${appPods.length || 0}`,
      readyAppPods === appPods.length && appPods.length > 0 ? "good" : "warn",
      "Ready / total"
    )
  );

  const readyMonitoringPods = monitoringPods.filter((pod) => !pod.ready.startsWith("0/")).length;
  grid.appendChild(
    metricCard(
      "Monitoring Pods",
      `${readyMonitoringPods}/${monitoringPods.length || 0}`,
      readyMonitoringPods === monitoringPods.length && monitoringPods.length > 0 ? "good" : "warn",
      "Healthy / total"
    )
  );

  const grafanaOpen = status.localAccess?.grafana?.listening;
  const podinfoOpen = status.localAccess?.podinfo?.listening;
  const prometheusOpen = status.localAccess?.prometheus?.listening;
  grid.appendChild(
    metricCard(
      "Grafana Local Access",
      grafanaOpen ? "Open" : "Closed",
      grafanaOpen ? "good" : "warn",
      status.localAccess?.grafana?.url || "http://localhost:3000"
    )
  );
  grid.appendChild(
    metricCard(
      "Podinfo Local Access",
      podinfoOpen ? "Open" : "Closed",
      podinfoOpen ? "good" : "warn",
      status.localAccess?.podinfo?.url || "http://localhost:9898"
    )
  );
  grid.appendChild(
    metricCard(
      "Prometheus Local Access",
      prometheusOpen ? "Open" : "Closed",
      prometheusOpen ? "good" : "warn",
      status.localAccess?.prometheus?.url || "http://localhost:9090"
    )
  );

  setText("statusTimestamp", `Last refreshed: ${formatTimestamp(status.generatedAt)}`);
}

function updateServiceLinks(status) {
  const services = {
    grafanaLink: status.localAccess?.grafana,
    prometheusLink: status.localAccess?.prometheus,
    podinfoLink: status.localAccess?.podinfo,
  };

  Object.entries(services).forEach(([id, service]) => {
    const link = document.getElementById(id);
    if (!link || !service) return;
    link.href = service.url;
    link.classList.toggle("is-online", Boolean(service.listening));
    link.classList.toggle("is-offline", !service.listening);
    link.title = service.listening ? `${service.url} is listening` : `${service.url} is not listening yet`;
  });
}

function resourceTable(title, rows, columns) {
  const wrapper = document.createElement("div");
  if (!rows.length) {
    wrapper.innerHTML = `<p class="empty-state">No ${title.toLowerCase()} found.</p>`;
    return wrapper;
  }

  const table = document.createElement("table");
  table.className = "resource-table";
  const thead = document.createElement("thead");
  thead.innerHTML = `<tr>${columns.map((column) => `<th>${column.label}</th>`).join("")}</tr>`;
  table.appendChild(thead);
  const tbody = document.createElement("tbody");
  rows.forEach((row) => {
    const tr = document.createElement("tr");
    tr.innerHTML = columns.map((column) => `<td>${row[column.key] ?? ""}</td>`).join("");
    tbody.appendChild(tr);
  });
  table.appendChild(tbody);
  wrapper.appendChild(table);
  return wrapper;
}

function renderResources(status) {
  const appSummary = document.getElementById("appSummary");
  const monitoringSummary = document.getElementById("monitoringSummary");

  appSummary.innerHTML = "";
  monitoringSummary.innerHTML = "";

  const app = status.workloads?.app || {};
  const monitoring = status.workloads?.monitoring || {};

  appSummary.appendChild(
    resourceTable("deployments", app.deployments || [], [
      { key: "name", label: "Deployment" },
      { key: "ready", label: "Ready" },
      { key: "updated", label: "Updated" },
      { key: "available", label: "Available" },
    ])
  );
  appSummary.appendChild(
    resourceTable("pods", app.pods || [], [
      { key: "name", label: "Pod" },
      { key: "ready", label: "Ready" },
      { key: "phase", label: "Phase" },
      { key: "restarts", label: "Restarts" },
    ])
  );

  monitoringSummary.appendChild(
    resourceTable("pods", monitoring.pods || [], [
      { key: "name", label: "Pod" },
      { key: "ready", label: "Ready" },
      { key: "phase", label: "Phase" },
      { key: "restarts", label: "Restarts" },
    ])
  );
  monitoringSummary.appendChild(
    resourceTable("services", monitoring.services || [], [
      { key: "name", label: "Service" },
      { key: "type", label: "Type" },
      { key: "ports", label: "Ports" },
    ])
  );
}

function renderActions(status) {
  state.actions = status.actions || [];
  const grid = document.getElementById("actionsGrid");
  grid.innerHTML = "";
  state.actions.forEach((action) => {
    const button = document.createElement("button");
    button.className = `action-button ${action.dangerous ? "danger" : ""}`;
    button.innerHTML = `
      <span class="action-label">${action.label}</span>
      <span class="action-description">${action.description}</span>
      <span class="action-command">${action.command}</span>
    `;
    button.addEventListener("click", () => triggerAction(action.slug));
    grid.appendChild(button);
  });
}

function renderPlayground() {
  const grid = document.getElementById("playgroundGrid");
  grid.innerHTML = "";
  playgroundLinks.forEach((link) => {
    const anchor = document.createElement("a");
    anchor.className = "playground-link";
    anchor.href = link.href;
    anchor.target = "_blank";
    anchor.rel = "noreferrer";
    anchor.innerHTML = `
      <span class="playground-title">${link.title}</span>
      <span class="playground-detail">${link.detail}</span>
    `;
    grid.appendChild(anchor);
  });
}

function renderScreenshots(status) {
  const grid = document.getElementById("screenshotsGrid");
  grid.innerHTML = "";
  (status.screenshots || []).forEach((shot) => {
    const article = document.createElement("article");
    article.className = "screenshot-card";
    article.innerHTML = `
      <a href="${shot.url}" target="_blank" rel="noreferrer">
        <img src="${shot.url}" alt="${shot.title}">
      </a>
      <div class="screenshot-meta">
        <h3>${shot.title}</h3>
        <p>${shot.name}</p>
      </div>
    `;
    grid.appendChild(article);
  });
}

async function fetchStatus() {
  const response = await fetch("/api/status");
  const status = await response.json();
  updateServiceLinks(status);
  renderOverview(status);
  renderResources(status);
  renderActions(status);
  renderPlayground();
  renderScreenshots(status);
  fetchJobs();
}

async function triggerAction(slug) {
  const response = await fetch(`/api/actions/${slug}`, { method: "POST" });
  const payload = await response.json();
  const job = payload.job;
  state.selectedJobId = job.id;
  setText("jobLabel", `${job.label} started`);
  renderJob(job);
  pollSelectedJob();
}

function renderJob(job) {
  setText("jobMeta", `${job.label} | ${job.status} | started ${formatTimestamp(job.createdAt)}`);
  document.getElementById("jobOutput").textContent = job.output || "Waiting for output...";
}

async function fetchJob(jobId) {
  const response = await fetch(`/api/jobs/${jobId}`);
  if (!response.ok) return null;
  return response.json();
}

function renderJobs(payload) {
  const jobs = payload.jobs || [];
  const list = document.getElementById("jobsList");
  list.innerHTML = "";
  setText("jobsSummary", jobs.length ? `${jobs.length} recent job(s)` : "No jobs have run in this console session.");

  if (!jobs.length) {
    list.innerHTML = `<p class="empty-state">Run an action to create job history.</p>`;
    return;
  }

  jobs.forEach((job) => {
    const button = document.createElement("button");
    button.className = `job-row status-${job.status}`;
    button.type = "button";
    button.innerHTML = `
      <span class="job-row-title">${job.label}</span>
      <span class="job-row-meta">${job.status} | ${formatTimestamp(job.createdAt)}</span>
    `;
    button.addEventListener("click", () => {
      state.selectedJobId = job.id;
      renderJob(job);
      pollSelectedJob();
    });
    list.appendChild(button);
  });
}

async function fetchJobs() {
  const response = await fetch("/api/jobs");
  if (!response.ok) return;
  renderJobs(await response.json());
}

async function pollSelectedJob() {
  if (!state.selectedJobId) return;
  if (state.pollTimer) window.clearTimeout(state.pollTimer);
  const job = await fetchJob(state.selectedJobId);
  if (!job) return;
  renderJob(job);
  if (job.status === "running") {
    state.pollTimer = window.setTimeout(pollSelectedJob, 1500);
  } else {
    fetchStatus();
  }
}

document.getElementById("themeToggleButton").addEventListener("click", () => {
  applyTheme(state.theme === "night" ? "day" : "night");
});
document.getElementById("refreshStatusButton").addEventListener("click", fetchStatus);
document.getElementById("pollJobsButton").addEventListener("click", () => {
  pollSelectedJob();
  fetchJobs();
});

applyTheme(storedTheme() || "night");
fetchStatus();
