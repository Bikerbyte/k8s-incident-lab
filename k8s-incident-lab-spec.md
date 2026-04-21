# K8s Incident Lab / SRE Playground 專案規格書

## 1. 專案定位

### 專案名稱
- `k8s-incident-lab`

### 專案目標
建立一個可在 `K3s / Kubernetes` 上部署的輕量化 incident lab，用來展示以下能力：
- Kubernetes 基本部署與維運
- Monitoring / Logging / Dashboard 建置
- 常見 incident scenario 模擬
- Troubleshooting 與 runbook 撰寫

### 專案原則
- 以 `小而完整` 為主，不追求大而全
- 以 `MVP 先完成` 為優先，再考慮加分項
- 以 `可展示、可部署、可排障、可講故事` 為驗收標準
- 優先採用成熟 Open Source 元件，不重造輪子

---

## 2. 一句話版本

在 K3s 上部署一個可觀測的 demo service，串接 Prometheus、Grafana、Loki，並設計幾個可重現的故障情境，讓使用者能透過 metrics、logs 與 Kubernetes 狀態進行排障。

---

## 3. 技術選型

### 核心平台
- Kubernetes：`K3s`
- 執行環境：Ubuntu / VM / Multipass / 本機 Lab 皆可

### 應用服務
MVP 優先使用現成、輕量、易觀測的 demo app：
- 第一選擇：`Podinfo`
- 備選：簡單自製 API，例如 `Python Flask`

### Observability Stack
- Metrics：`Prometheus`
- Dashboard：`Grafana`
- Logs：`Loki`
- Log collection：`Promtail`

### 部署方式
- Observability stack：優先用 `Helm`
- Demo app：可用 `Kubernetes manifests` 或 `Helm chart`

---

## 4. 文件語言策略

為了兼顧 GitHub 展示與內部規劃，文件語言統一如下：

- `README`、公開說明、對外展示文件：`英文`
- `Spec`、草稿、實作備忘：`繁體中文`
- Runbook 可先用英文，保持專案整體對外一致性

---

## 5. MVP 範圍

### 5.1 Kubernetes 基本部署
- 建立獨立 namespace：`incident-lab`
- 部署 1 個 demo app
- 建立 Deployment
- 建立 Service
- 視環境加入 Ingress

### 5.2 Monitoring
- 安裝 Prometheus
- 安裝 Grafana
- Prometheus 可抓到 app 或 cluster metrics
- Grafana 有至少 1 個可用 dashboard

### 5.3 Logging
- 安裝 Loki
- 安裝 Promtail
- App logs 可集中收集到 Loki
- Grafana 可查詢 logs

### 5.4 Incident Scenarios
MVP 至少完成 3 個 scenario，建議優先：
- `Readiness Probe Failure`
- `High Error Rate`
- `Pod Self-healing`

### 5.5 Runbooks
每個 scenario 至少要有：
- Symptoms
- Where to Look
- Possible Cause
- Troubleshooting Steps
- Resolution
- Validation

### 5.6 README
README 需能讓陌生人快速理解：
- 專案目的
- 架構
- 技術選型
- 部署方式
- Dashboard 與 logs 如何查看
- Scenario 與 demo 流程
- Runbook 位置

---

## 6. 非目標

以下項目不列入 MVP：
- 完整 microservices 架構
- Service mesh
- Tracing（Tempo / Jaeger）
- GitOps
- 全自動 CI/CD
- HPA / KEDA
- Chaos Mesh 正式導入
- 雲端託管
- 多環境管理

---

## 7. 建議 Scenario 設計

### Scenario 1：Readiness Probe Failure
目的：
展示 pod 雖然存活，但因 readiness failure 導致無法正常接流量。

做法：
- 刻意設錯 readiness probe path
- 或讓 health endpoint 在特定條件下回傳非 200

觀察重點：
- `kubectl get pods`
- `kubectl describe pod`
- Ready 狀態
- Grafana availability / request failure
- Loki logs

### Scenario 2：High Error Rate
目的：
展示服務本身雖然還在跑，但錯誤率明顯升高。

做法：
- 提供會回傳 5xx 的 route
- 或透過參數切換成 error mode

觀察重點：
- Request count
- Error count / error rate
- Loki logs 關鍵字
- Pod 狀態是否仍正常

### Scenario 3：Pod Self-healing
目的：
展示 Deployment controller 的自癒能力。

做法：
- 手動刪除一個 pod

觀察重點：
- Pod recreate 行為
- Service 是否短暫受影響後恢復
- Dashboard 是否能看出 workload 波動

---

## 8. Dashboard 原則

Dashboard 不求花俏，但必須能回答排障問題。

### App Overview
至少包含：
- Request count
- Error count / error rate
- Response time（avg 或 p95）
- Ready replicas
- Pod restart count
- CPU / memory（若可取得）

### Cluster / Workload Overview
可包含：
- Namespace pod 狀態
- Pod restart trend
- Node resource usage

### 設計原則
每張圖都要能回答至少一個問題，例如：
- 服務是不是壞了？
- 是 readiness 問題還是 app 5xx？
- Pod 是否持續重啟？
- 是單點問題還是整體 workload 問題？

---

## 9. 建議 Repo 結構

```text
k8s-incident-lab/
├─ README.md
├─ docs/
│  ├─ architecture.md
│  ├─ scenarios.md
│  └─ screenshots/
├─ app/
│  └─ manifests/
├─ monitoring/
│  ├─ helm-values/
│  └─ dashboards/
├─ scenarios/
│  ├─ readiness-failure/
│  ├─ high-error-rate/
│  └─ pod-self-healing/
├─ runbooks/
└─ scripts/
```

---

## 10. 開發階段規劃

### Phase 1：基礎環境
- K3s 可正常使用
- Namespace 建立完成
- Demo app 可成功部署
- Service 可連通

### Phase 2：Observability
- Prometheus 可抓 metrics
- Grafana 可看 dashboard
- Loki / Promtail 可查 logs

### Phase 3：Scenario 實作
- 完成 readiness failure
- 完成 high error rate
- 完成 pod self-healing

### Phase 4：文件整理
- README
- Architecture docs
- Runbooks
- Screenshots

### Phase 5：收尾
- 清理 repo 結構
- 統一命名
- 補上 demo 截圖
- 列 future improvements

---

## 11. 驗收標準

- [ ] K3s 環境可正常運作
- [ ] 至少 1 個 app 成功部署到 K8s
- [ ] Prometheus 能抓到 metrics
- [ ] Grafana 有至少 1 個可用 dashboard
- [ ] Loki 可查詢 app logs
- [ ] 至少完成 3 個 incident scenarios
- [ ] 每個 scenario 都有 runbook
- [ ] README 足以讓陌生人理解專案內容
- [ ] Repo 結構清楚，適合放在 GitHub 展示

---

## 12. 未來可擴充項目

- Alertmanager
- Tracing（Tempo / Jaeger）
- Chaos Mesh
- GitHub Actions CI
- Ingress + TLS
- Synthetic checks
- 簡單的 incident trigger UI

---

## 13. 給 Codex 的實作原則

1. 先完成 MVP，不過度設計
2. 以 K3s 可執行為前提
3. 優先使用成熟 Open Source 元件
4. 專注在 observability、incident scenario、runbook
5. YAML、scripts、文件保持簡潔可維護
6. README 必須完整，因為它是 GitHub 展示入口
7. 任何明顯拉高複雜度的功能，先放入 future improvements

---

## 14. 最終要求

這個專案的價值不在元件多，而在於是否能把以下故事講完整：
- 服務怎麼被部署
- 問題怎麼被觀測到
- 問題怎麼被判斷
- 問題怎麼被修復

整體原則：`小而完整、可重現、可展示、可說明`
