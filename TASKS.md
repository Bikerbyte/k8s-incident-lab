\# K8s Incident Lab 強化任務清單



\## 背景與目標



這個 repo (`k8s-incident-lab`) 是我求職用的 side project，目標職位是 \*\*SRE 工程師 / DevOps 工程師 / 系統工程師 / 雲端工程師\*\*，求職地點雙北。



目前的痛點是：專案內容本身已經不錯（K3s + Podinfo + Prometheus/Grafana/Loki + 3 個 incident scenarios + runbooks + 本地 console），但面試官打開 GitHub 在 30 秒內看不出來它有多強，因為：



1\. 沒有截圖、沒有 demo GIF

2\. README 開頭太工程師口吻，沒有突出「對應職務的能力」

3\. 只在本機跑，缺乏 production-like 訊號（沒 CI、沒上雲、沒 IaC）

4\. 三個情境太入門（readiness failure / self-healing / 500 errors），缺少真正會在 production 燒到人的場景



這份文件分三層任務，\*\*按順序執行\*\*。每完成一層，先讓我 review 再進下一層。



\---



\## 執行原則



\- 每個任務做完，update README 對應段落，並 commit 一次，commit message 用 conventional commits 格式 (`feat:`, `docs:`, `chore:` ...)

\- 遇到不確定的設計決策（例如要不要動既有的 dashboard JSON），停下來問我，不要自作主張改大架構

\- 所有新增的 shell script 都要過 `bash -n` 語法檢查；新增的 Python 要過 `py\_compile`；新增的 manifest 要過 `kubectl apply --dry-run=client`

\- 新增情境一律遵循現有 repo 結構：`scenarios/<name>/README.md` + `runbooks/<name>.md` + `scripts/trigger-<name>.sh` + `scripts/restore-<name>.sh`（如果需要）

\- 所有對外文件（README、scenario README、runbook）用\*\*英文\*\*；內部備忘、commit message 可以用英文或繁中

\- \*\*不要\*\*動 `console/` 底下任何東西，那是已經調好的，不要動到

\- \*\*不要\*\*改 `monitoring/dashboards/podinfo-overview-dashboard.yaml` 的既有 panel，只能新增

\- 每個新情境都要在 `monitoring/alerts/podinfo-alerts.yaml` 加對應 alert rule

\- 每個 trigger script 必須有對應的 restore（除非該情境本質是自癒，例如 pod self-healing）



\---



\## Layer 1：包裝現有 lab（先做這層，CP 值最高）



目標：不寫新功能，純粹讓現有的東西「被看見」。



\### Task 1.1：補上關鍵截圖



在 `docs/screenshots/` 補齊以下檔案（檔名照下面寫，README 已有對應引用）：



\- `lab-console.png` — 開 `scripts/run-console.sh` 後的瀏覽器畫面

\- `grafana-normal.png` — 正常狀態的 Podinfo Overview dashboard

\- `readiness-failure.png` — 跑完 `scripts/trigger-readiness-failure.sh` 後 Grafana 上 Unready Pods=1、Unavailable Replicas=1 的畫面

\- `high-error-rate.png` — `scripts/generate-errors.sh` 跑到一半時的 Error Ratio 上升曲線

\- `loki-500-logs.png` — Grafana Explore 用 `{namespace="incident-lab"} |= "500"` 查到的結果

\- `prometheus-alerts-firing.png` — `http://localhost:9090/alerts` 上 alert 處於 firing 狀態的截圖

\- `pod-self-healing.png` — 刪 pod 後 Kubernetes 自動建新 pod 的 `kubectl get pods` watch 畫面



執行方式：

\- Grafana 類截圖優先用既有的 `scripts/capture-grafana-screenshot.sh`

\- 其他類截圖直接系統截圖即可

\- 截圖請設定 Grafana time range = Last 15 minutes

\- 截圖檔案放在 `docs/screenshots/`，加進 git tracked



\*\*注意\*\*：這個任務需要實際跑 cluster 才能截圖。如果環境跑不起來（minikube/k3s 沒裝、kubectl 連不到），把這個 task 標記為 BLOCKED 並列出環境需求，往下做其他可以做的 task。



\### Task 1.2：錄 demo GIF / asciicast



錄一段 60–90 秒的 demo，放在 `docs/demo.gif`（或 `docs/demo.cast`，asciinema 格式）。



劇本：

1\. 開新 terminal，跑 `scripts/status.sh` 顯示 lab healthy（3 秒）

2\. 跑 `scripts/trigger-readiness-failure.sh`（5 秒）

3\. 切到 browser，秀 Grafana dashboard 上的數字變化（15 秒）

4\. 切回 terminal，跑 `kubectl -n incident-lab get pods` 和 `kubectl -n incident-lab get endpoints podinfo`（10 秒）

5\. 跑 `scripts/restore-readiness.sh`（10 秒）

6\. 跑 `kubectl -n incident-lab get pods` 確認恢復（5 秒）



如果環境跑不起來，跳過這個任務，標記為 BLOCKED。



\### Task 1.3：重寫 README 開頭



把 `README.md` 開頭從現在的：



> A lightweight Kubernetes incident lab built on K3s for practicing deployment, observability, troubleshooting, and runbook-driven incident response.



改成兩個段落 + 一張 hero 圖：



\*\*第一段：能力定位\*\*（兩到三句話）。用 SRE 職務的語言寫，強調這個 lab 在練什麼能力，而不是用什麼工具。範例方向：「This project simulates production-grade incident response on Kubernetes. It demonstrates observability-driven debugging, runbook-driven recovery, and reproducible failure scenarios — the core daily work of an SRE.」



\*\*第二段：技術棧\*\*。一句話列出 K3s / Podinfo / Prometheus / Grafana / Loki / Promtail / PrometheusRule alerts。



\*\*Hero 圖\*\*：在開頭兩段下方嵌入 `docs/demo.gif`（如果 Task 1.2 完成）或 `docs/screenshots/grafana-normal.png`（fallback）。



\### Task 1.4：新增 README 段落「What This Project Demonstrates」



在 README 的 "What This Demonstrates" 段落改寫成「能力 ↔ 職務」對照表，用 markdown table，欄位：`Capability` / `What I Built` / `Why It Matters in Production`。



範例列：



| Capability | What I Built | Why It Matters in Production |

| --- | --- | --- |

| Observability stack design | Prometheus + Grafana + Loki + Promtail + PrometheusRule alerts | First-line evidence during any incident |

| Runbook-driven incident response | 3 reproducible scenarios with paired runbooks | Reduces MTTR and shortens on-call ramp-up |

| Alert authoring | Custom PrometheusRule with `for` durations | Separates signal from noise |

| Self-service operator console | Local Python console with guided terminal | Lowers barrier for new SRE team members |



這張表非常重要，\*\*這是面試官會直接拿來當 talking points 的段落\*\*。寫完後我會 review。



\### Task 1.5：把量化指標寫進 README



在 README 「What This Demonstrates」下方加一個小段「Outcomes」，用 bullet list 寫量化結果。風格參考我履歷上的寫法：



\- `Reduced mean-time-to-detect from manual inspection to <30s via 3 PrometheusRule alerts.`

\- `Codified 3 incident scenarios into reproducible runbooks, each recoverable in <60s.`

\- `Built a local web console exposing 10+ lab actions with audit trail of every triggered job.`

\- （根據實際情況補充其他）



寫之前先讀過整個 repo 確認數字是真的，\*\*不要編造\*\*。如果不確定某個數字，先用 placeholder `<TBD: 實際測一次>` 標記，告訴我哪些需要實測。



\### Task 1.6：commit + push



把上面任務的成果分成乾淨的幾個 commit：

\- `docs: add screenshots for grafana, alerts, and lab console`

\- `docs: add demo gif`

\- `docs: rewrite README with capability framing and outcomes`



\---



\## Layer 1 完成 → 停下來讓我 review



\---



\## Layer 2：升級情境深度（差異化關鍵）



目標：加入 2–3 個真實 production 痛點情境，把這個 lab 從「會用 K8s」拉到「有 SRE sense」。



\### Task 2.1：OOMKilled 情境



新增 scenario `oom-killed`。



需求：

\- 部署一個會吃記憶體的 sidecar 或新的 deployment（建議用 polinux/stress 或自己用 podinfo 的 `/stress/memory` endpoint）

\- 設定刻意過低的 memory limit

\- 觀察指標：`kube\_pod\_container\_status\_last\_terminated\_reason="OOMKilled"`、container restart count

\- 新 alert：`PodinfoFrequentOOMKills`，觸發條件設成 10 分鐘內 OOMKilled 次數 > 2



檔案清單：

\- `scenarios/oom-killed/README.md`

\- `runbooks/oom-killed.md`

\- `scripts/trigger-oom-killed.sh` + `.ps1`

\- `scripts/restore-oom-killed.sh` + `.ps1`

\- 更新 `monitoring/alerts/podinfo-alerts.yaml` 加新 rule

\- 更新主 `README.md` 的 Incident Scenarios 段落

\- 更新 `docs/scenarios.md` 的 Scenario Index 表



Runbook 必須涵蓋：

\- 怎麼分辨 OOMKilled vs 應用層 crash

\- `requests` vs `limits` 的差異

\- 何時該調高 limit、何時該找 memory leak

\- 怎麼用 `kubectl top` 和 `container\_memory\_working\_set\_bytes` 看趨勢



\### Task 2.2：DNS / Service Discovery 故障情境



新增 scenario `service-discovery-broken`。



需求：

\- 故意把 `podinfo` Service 的 selector label 改錯（例如 `app.kubernetes.io/name: podinfo-typo`）

\- 觀察結果：endpoints 變空、service 還在但流量打不進去

\- 對比情境：app 看起來健康、pod 看起來健康，但 Service 沒有 endpoint

\- 新 alert：`PodinfoServiceHasNoEndpoints`，觸發條件 `kube\_endpoint\_address\_available{namespace="incident-lab",endpoint="podinfo"} == 0`（或等效 query）



檔案清單：同 Task 2.1 結構。



Runbook 必須涵蓋：

\- 為什麼「pod healthy + service exists」還是會中斷

\- Service selector / Pod label 的關聯

\- 怎麼用 `kubectl get endpoints` 和 `kubectl describe svc` 排查

\- 這類錯誤在真實環境最常見的觸發原因（label 改錯、Helm template bug、ArgoCD diff）



\### Task 2.3：Rolling Update 卡住 + Rollback 情境（選做，看時間）



新增 scenario `stuck-rollout`。



需求：

\- 故意把 image tag 改成不存在的 tag（例如 `ghcr.io/stefanprodan/podinfo:does-not-exist`）

\- 設定 `progressDeadlineSeconds: 60` 讓 rollout 真的會 fail

\- 觀察 `kubectl rollout status` 會 timeout、舊 ReplicaSet 還在服務

\- 教學 `kubectl rollout undo` 怎麼用

\- 新 alert：`PodinfoRolloutStuck`，用 `kube\_deployment\_status\_condition{condition="Progressing",status="false"}` 之類



檔案清單：同上。



\### Task 2.4：更新主 README 和 docs/scenarios.md



新情境加完後：

\- 主 README 的 "Incident Scenarios" 段落要列出 5 個情境（原 3 + 新 2 或 3）

\- `docs/scenarios.md` 的 Scenario Index 表要更新

\- `console/server.py` 的 `ACTIONS` dict 如果要加新 scenario 的按鈕，\*\*先問我\*\*（這會動到 console，我想保留控制權）



\---



\## Layer 2 完成 → 停下來讓我 review



\---



\## Layer 3：production-like 訊號（最後做）



目標：讓 repo 看起來像「真的在跑」而不是「跑過一次」。



\### Task 3.1：GitHub Actions CI



新增 `.github/workflows/ci.yml`，內容：



\- `shellcheck` 跑所有 `scripts/\*.sh`

\- `bash -n` 跑所有 `scripts/\*.sh`（既有的 `scripts/validate.sh` 已經有，整合進 CI）

\- `python3 -m py\_compile console/server.py`

\- `node --check console/static/app.js`（如果 runner 有 node）

\- `kubectl apply --dry-run=client` 跑所有 manifests（用 kind cluster 或純 client mode）

\- `yamllint` 跑所有 `.yaml`（給一份合理的 `.yamllint.yml` config，不要太嚴）



trigger 設成 push to main + pull\_request。



成功後在 README 開頭加 CI badge。



\### Task 3.2：Terraform IaC（把 lab 上雲，選做）



這個比較大，\*\*先不要動手做\*\*，產出一份 `docs/cloud-deployment-plan.md`，內容：



\- 評估 AWS EKS、OCI OKE（我有兩張 Oracle 證照）、k3s on EC2 spot 三個方案

\- 列出每個方案的 monthly cost estimate（free tier 限制）

\- 建議哪個方案，理由是什麼

\- 列出要寫的 Terraform 檔案結構



寫完讓我選方向。



\### Task 3.3：SLO Dashboard



在 `monitoring/dashboards/` 新增 `podinfo-slo-dashboard.yaml`（一樣是 ConfigMap）。



包含 panels：

\- Availability SLI（`1 - error\_ratio`）30 天 trend

\- Error budget remaining（假設 SLO = 99.5%）

\- Burn rate（短窗 vs 長窗）



寫一份 `docs/slo.md` 解釋這個 dashboard 怎麼看、SLO 怎麼定的、為什麼選 99.5%。



\---



\## 全部完成後的最後一步



更新 README 末段「Future Improvements」，把已完成的項目劃掉或移除，補上新的 future items（例如 Tempo tracing、Alertmanager routing、chaos mesh、HPA scenario）。



\---



\## 給你的提醒



1\. 我履歷上量化指標的寫法（「Reduced X by Y」、「Codified N scenarios」）請套用到 README 各段，\*\*這個專案的賣點不是技術，是「能用 SRE 語言講影響力」\*\*

2\. 任何時候你覺得「這個設計有更好的做法」，\*\*先問我\*\*再動手，不要自己決定

3\. 跑不起來的 task 一律標記 BLOCKED，列出原因，不要假裝跑過

4\. 全部做完後產一份 `WORK\_LOG.md`，列出每個任務的完成狀態、commit hash、跑不起來的 BLOCKED 原因，方便我事後 review

