const state = {
  actions: [],
  controls: [],
  selectedJobId: null,
  pollTimer: null,
  theme: "night",
  activeTab: "guided",
  guideStep: 0,
  terminalBusy: false,
};

const guideSteps = [
  {
    phase: "Observe",
    title: "Confirm pod readiness",
    goal: "Use kubectl to compare pod READY and STATUS values.",
    commands: ["kubectl -n incident-lab get pods"],
    matchers: ["get pods"],
    coaching: "A pod can be Running while failing readiness. Start by checking the READY column.",
    nextCheck: "Next check: pod events",
  },
  {
    phase: "Diagnose",
    title: "Inspect probe events",
    goal: "Describe the pod and look for readiness probe failures in Events.",
    commands: ["kubectl -n incident-lab describe pod -l app.kubernetes.io/name=podinfo"],
    matchers: ["describe pod"],
    coaching: "Describe output connects symptoms to Kubernetes events, including probe failures and container state.",
    nextCheck: "Next check: service endpoints",
  },
  {
    phase: "Diagnose",
    title: "Check service endpoints",
    goal: "Confirm whether the Service has ready pods behind it.",
    commands: ["kubectl -n incident-lab get endpoints podinfo"],
    matchers: ["get endpoints"],
    coaching: "If endpoints are empty or reduced, traffic through the Service has fewer healthy targets.",
    nextCheck: "Next check: application logs",
  },
  {
    phase: "Observe",
    title: "Read application logs",
    goal: "Check whether the app is failing or Kubernetes is rejecting readiness.",
    commands: ["kubectl -n incident-lab logs deploy/podinfo --tail=100"],
    matchers: ["logs"],
    coaching: "Logs help separate application failures from Kubernetes probe configuration issues.",
    nextCheck: "Next check: restore readiness",
  },
  {
    phase: "Act",
    title: "Restore readiness",
    goal: "Run the lab recovery script, then wait for rollout health.",
    commands: ["scripts/lab.sh scenario readiness restore", "kubectl -n incident-lab rollout status deploy/podinfo"],
    matchers: ["restore-readiness", "rollout status"],
    coaching: "Recovery is only complete after the Deployment rolls out and ready endpoints return.",
    nextCheck: "Next check: final validation",
  },
  {
    phase: "Validate",
    title: "Validate healthy service",
    goal: "Confirm pods and endpoints are healthy after the fix.",
    commands: ["kubectl -n incident-lab get pods", "kubectl -n incident-lab get endpoints podinfo"],
    matchers: ["get pods", "get endpoints"],
    coaching: "Close the incident only after both workload health and routing targets look normal.",
    nextCheck: "Scenario complete",
  },
];

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
    title: "OOMKilled Runbook",
    detail: "Diagnose memory pressure and container restarts.",
    href: "/runbooks/oom-killed.md",
  },
  {
    title: "Service Discovery Runbook",
    detail: "Trace healthy pods that receive no Service traffic.",
    href: "/runbooks/service-discovery-broken.md",
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

function switchTab(tab) {
  state.activeTab = tab;
  document.querySelectorAll(".tab-button").forEach((button) => {
    const isActive = button.dataset.tab === tab;
    button.classList.toggle("is-active", isActive);
    button.setAttribute("aria-pressed", String(isActive));
  });
  document.querySelectorAll(".tab-panel").forEach((panel) => {
    panel.classList.toggle("is-active", panel.id === `tab-${tab}`);
  });
}

function statusChip(label, tone = "neutral") {
  return `<span class="status-chip tone-${tone}">${label}</span>`;
}

function renderStatusChips(status) {
  const chips = document.getElementById("labStatusChips");
  if (!chips) return;
  const appPods = status.workloads?.app?.pods || [];
  const readyPods = appPods.filter((pod) => pod.ready.startsWith("1/1")).length;
  const clusterTone = status.cluster?.reachable ? "good" : "danger";
  const podTone = appPods.length && readyPods === appPods.length ? "good" : "warn";
  const grafanaTone = status.localAccess?.grafana?.listening ? "good" : "warn";
  chips.innerHTML = [
    statusChip(status.cluster?.reachable ? "Cluster reachable" : "Cluster offline", clusterTone),
    statusChip(appPods.length ? `Podinfo ${readyPods}/${appPods.length}` : "Podinfo not deployed", podTone),
    statusChip(status.localAccess?.grafana?.listening ? "Grafana open" : "Grafana closed", grafanaTone),
  ].join("");
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
  const nextTheme = state.theme === "night" ? "day" : "night";
  button.textContent = state.theme === "night" ? "☀" : "☾";
  button.title = `Switch to ${nextTheme} theme`;
  button.setAttribute("aria-label", `Switch to ${nextTheme} theme`);
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

  const timestamp = document.getElementById("statusTimestamp");
  timestamp.classList.remove("loading-copy");
  timestamp.textContent = `Last refreshed: ${formatTimestamp(status.generatedAt)}`;
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

function actionButton(action) {
  const button = document.createElement("button");
  button.className = `action-button ${action.dangerous ? "danger" : ""}`;
  button.title = action.command;
  button.innerHTML = `
    <span class="action-icon" aria-hidden="true">${action.icon || "•"}</span>
    <span class="action-copy">
      <span class="action-label">${action.label}</span>
      <span class="action-description">${action.description}</span>
      <span class="action-command">${action.command}</span>
    </span>
  `;
  button.addEventListener("click", () => triggerAction(action.slug));
  return button;
}

function renderActionGroup(gridId, actions, emptyText) {
  const grid = document.getElementById(gridId);
  grid.innerHTML = "";
  if (!actions.length) {
    grid.innerHTML = `<p class="empty-state">${emptyText}</p>`;
    return;
  }
  actions.forEach((action) => grid.appendChild(actionButton(action)));
}

function renderActions(status) {
  const actions = status.actions || [];
  state.controls = actions.filter((action) => action.group !== "scenario");
  state.actions = actions.filter((action) => action.group === "scenario");
  renderActionGroup("controlsGrid", state.controls, "No lab controls are available.");
  renderActionGroup("actionsGrid", state.actions, "No scenario actions are available.");
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

function currentGuideStep() {
  return guideSteps[Math.min(state.guideStep, guideSteps.length - 1)];
}

function renderGuidedSteps() {
  const wrapper = document.getElementById("guidedSteps");
  if (!wrapper) return;
  wrapper.innerHTML = "";
  guideSteps.forEach((step, index) => {
    const item = document.createElement("button");
    item.type = "button";
    item.className = "step-item";
    if (index < state.guideStep) item.classList.add("is-complete");
    if (index === state.guideStep) item.classList.add("is-current");
    item.innerHTML = `
      <span class="step-index">${index + 1}</span>
      <span class="step-copy">
        <span class="step-phase">${step.phase}</span>
        <span class="step-title">${step.title}</span>
      </span>
    `;
    item.addEventListener("click", () => {
      state.guideStep = index;
      renderGuide();
    });
    wrapper.appendChild(item);
  });
}

function renderCommandSuggestions(step) {
  const list = document.getElementById("suggestionList");
  list.innerHTML = "";
  step.commands.forEach((command) => {
    const button = document.createElement("button");
    button.className = "command-chip";
    button.type = "button";
    button.textContent = command;
    button.title = "Fill terminal input";
    button.addEventListener("click", () => fillTerminal(command));
    list.appendChild(button);
  });
}

function renderGuide() {
  const step = currentGuideStep();
  setText("currentStepTitle", step.title);
  setText("currentStepGoal", step.goal);
  setText("coachingText", step.coaching);
  setText("nextCheck", step.nextCheck);
  renderGuidedSteps();
  renderCommandSuggestions(step);
}

function fillTerminal(command) {
  const input = document.getElementById("terminalInput");
  input.value = command;
  input.focus();
}

function appendTerminalEntry(command, payload) {
  const output = document.getElementById("terminalOutput");
  const entry = document.createElement("article");
  entry.className = `terminal-entry status-${payload.status}`;

  const commandLine = document.createElement("div");
  commandLine.className = "terminal-command";
  commandLine.textContent = `$ ${command}`;

  const pre = document.createElement("pre");
  pre.className = "terminal-result";
  pre.textContent = payload.output || "(no output)";

  const meta = document.createElement("div");
  meta.className = "terminal-meta";
  meta.textContent = `${payload.status} | exit ${payload.returncode} | ${payload.durationMs || 0}ms`;

  const hint = document.createElement("p");
  hint.className = "terminal-hint";
  hint.textContent = payload.hint || "Use this output to choose the next check.";

  entry.append(commandLine, pre, meta, hint);
  output.appendChild(entry);
  output.scrollTop = output.scrollHeight;
}

function commandMatchesStep(command, step) {
  const normalized = command.toLowerCase();
  return step.matchers.some((matcher) => normalized.includes(matcher));
}

function advanceGuideForCommand(command, payload) {
  const step = currentGuideStep();
  if (payload.status === "confirmation_required") {
    setText("terminalStatus", "Command needs confirmation before it runs.");
    return;
  }
  if (payload.status === "canceled") {
    setText("terminalStatus", "Command canceled before execution.");
    return;
  }
  if (payload.status === "blocked") {
    setText("terminalStatus", "Command blocked by the lab allowlist.");
    return;
  }
  if (payload.status === "failed") {
    setText("terminalStatus", "Command ran but returned an error. Use the output before moving on.");
    return;
  }
  if (commandMatchesStep(command, step)) {
    if (state.guideStep < guideSteps.length - 1) {
      state.guideStep += 1;
      setText("terminalStatus", `Good observation. Moving to: ${currentGuideStep().title}.`);
    } else {
      setText("terminalStatus", "Readiness scenario validated.");
    }
    renderGuide();
    return;
  }
  setText("terminalStatus", "Command completed. The guide is still waiting for the current check.");
}

async function postTerminalCommand(command, confirmed = false) {
  const response = await fetch("/api/terminal", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ command, confirmed }),
  });
  if (!response.ok) throw new Error(`Terminal request failed: ${response.status}`);
  return response.json();
}

async function runTerminalCommand(command) {
  if (state.terminalBusy) return;
  state.terminalBusy = true;
  const runButton = document.getElementById("terminalRunButton");
  runButton.disabled = true;
  setText("terminalStatus", "Running command...");
  try {
    let payload = await postTerminalCommand(command);
    if (payload.status === "confirmation_required") {
      const shouldRun = window.confirm(`${payload.output}\n\n${command}`);
      if (!shouldRun) {
        payload = {
          status: "canceled",
          returncode: 130,
          durationMs: 0,
          output: "Command canceled before execution.",
          hint: "No cluster changes were made.",
        };
      } else {
        setText("terminalStatus", "Running confirmed command...");
        payload = await postTerminalCommand(command, true);
      }
    }
    appendTerminalEntry(command, payload);
    advanceGuideForCommand(command, payload);
    fetchStatus();
  } catch (error) {
    appendTerminalEntry(command, {
      status: "failed",
      returncode: 1,
      durationMs: 0,
      output: String(error),
      hint: "The console server could not run this command.",
    });
    setText("terminalStatus", "Terminal request failed.");
  } finally {
    state.terminalBusy = false;
    runButton.disabled = false;
  }
}

async function fetchStatus() {
  const timestamp = document.getElementById("statusTimestamp");
  timestamp.classList.add("loading-copy");
  timestamp.textContent = "Checking lab state...";
  try {
    const response = await fetch("/api/status");
    if (!response.ok) throw new Error(`Status request failed: ${response.status}`);
    const status = await response.json();
    renderStatusChips(status);
    updateServiceLinks(status);
    renderOverview(status);
    renderResources(status);
    renderActions(status);
    renderPlayground();
    renderScreenshots(status);
    fetchJobs();
  } catch (error) {
    timestamp.classList.remove("loading-copy");
    timestamp.textContent = "Status unavailable. Check the console server.";
    document.getElementById("labStatusChips").innerHTML = statusChip("Console offline", "danger");
    document.getElementById("overviewGrid").innerHTML = "";
    document.getElementById("controlsGrid").innerHTML = `<p class="empty-state">Unable to load lab controls.</p>`;
    document.getElementById("actionsGrid").innerHTML = `<p class="empty-state">Unable to load scenario actions.</p>`;
  }
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
document.querySelectorAll(".tab-button").forEach((button) => {
  button.addEventListener("click", () => switchTab(button.dataset.tab));
});
document.getElementById("terminalForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const input = document.getElementById("terminalInput");
  const command = input.value.trim();
  if (!command) return;
  input.value = "";
  runTerminalCommand(command);
});
document.querySelectorAll(".fill-command").forEach((button) => {
  button.addEventListener("click", () => fillTerminal(button.dataset.command));
});

applyTheme(storedTheme() || "night");
switchTab("guided");
renderGuide();
appendTerminalEntry("welcome", {
  status: "info",
  returncode: 0,
  durationMs: 0,
  output:
    "Start by typing a real kubectl command. Suggested commands fill the prompt, but you choose when to run them.",
  hint: "Mutation commands are allowed when they explicitly stay in the incident-lab namespace.",
});
fetchStatus();
