# Grafana 使用指南

這份文件從 lab 已經跑起來、Grafana 已經可以用瀏覽器打開開始說明。

Grafana URL:

```text
http://localhost:3000
```

登入帳號:

```text
admin / admin
```

如果 Grafana 問你要不要改密碼，這個本機 lab 可以先跳過。

## 開啟 Podinfo Dashboard

登入後照這樣找:

1. 點左側選單的 **Dashboards**。
2. 打開 **Incident Lab / Podinfo Overview**。
3. 右上角時間範圍先選 **Last 15 minutes** 或 **Last 1 hour**。
4. 確認右上角有自動刷新。這個 dashboard 預設每 `15s` 更新一次。

這個 dashboard 來自:

```text
monitoring/dashboards/podinfo-overview-dashboard.yaml
```

## 第一排數字卡怎麼看

第一排是「現在狀態」，適合先用來判斷是不是正在故障。

### Ready Replicas

目前有幾個 Podinfo replica 是 Ready。

正常值通常是:

```text
2
```

### Unready Pods

目前有幾個 Pod 是 Not Ready。

正常值是:

```text
0
```

如果你跑了 readiness failure，這裡通常會變成:

```text
1
```

這個 panel 比單看 Ready Replicas 更直覺，因為 rollout 卡住時，舊 Pod 可能仍然是 Ready，但新 Pod 是 Not Ready。

### Unavailable Replicas

Deployment 目前有幾個 replica 不可用。

正常值是:

```text
0
```

readiness failure 時通常會變成:

```text
1
```

### Ready Service Endpoints

目前 Service 可以轉送流量的 ready endpoint 數量。

正常值通常是:

```text
2
```

如果 readiness failure 只影響新 Pod，這裡可能還是 `2`，代表舊 Pod 仍然可以接流量。

## 趨勢圖怎麼看

### Request Rate

這張圖表示 Podinfo 每秒收到多少 HTTP request。

適合用來判斷:

- 服務現在有沒有流量。
- 跑 `scripts/generate-errors.sh` 之後，流量有沒有上升。
- 流量是不是突然停止。

背後的 Prometheus query:

```promql
sum(rate(http_requests_total{namespace="incident-lab"}[5m]))
```

### Error Ratio

這張圖表示 HTTP `5xx` 錯誤比例。

適合用來判斷:

- 使用者是否正在遇到 server error。
- high error rate 情境有沒有成功觸發。
- 停止錯誤流量後，錯誤比例有沒有降回來。

背後的 Prometheus query:

```promql
sum(rate(http_requests_total{namespace="incident-lab",status=~"5.."}[5m])) / clamp_min(sum(rate(http_requests_total{namespace="incident-lab"}[5m])), 0.001)
```

### Deployment Replica State

這張圖把 Deployment 的 replica 狀態畫在一起。

適合用來判斷:

- `total replicas`: Deployment 目前總共管理幾個 replica。
- `ready replicas`: 已經 Ready 的 replica。
- `unavailable replicas`: 不可用的 replica。
- `updated replicas`: 新 ReplicaSet 裡已更新的 replica。

readiness failure 時常見狀態:

```text
total replicas = 3
ready replicas = 2
unavailable replicas = 1
updated replicas = 1
```

這代表 Kubernetes 正在嘗試 rolling update，但新的 Pod 因為 readiness probe 失敗，不能變成 Ready。

### Pod Readiness

這張圖會把每個 Pod 的 Ready / Not Ready 狀態畫出來。

適合用來判斷:

- 哪一顆 Pod 是 Ready。
- 哪一顆 Pod 是 Not Ready。
- readiness failure 時新 Pod 是否一直卡在 Not Ready。

### Pod Restarts

這張圖表示每個 Podinfo pod 的 restart 次數。

適合用來判斷:

- Pod 是否有 crash 後重啟。
- self-healing 情境中是否有 Pod 被替換。
- Kubernetes 是否正在自動修復 workload。

背後的 Prometheus query:

```promql
sum by (pod) (kube_pod_container_status_restarts_total{namespace="incident-lab",container="podinfo"})
```

## 用 Explore 查 Metrics

Dashboard 是固定視角。你想自己查 Prometheus 指標時，用 **Explore**。

操作方式:

1. 點左側選單的 **Explore**。
2. datasource 選 **Prometheus**。
3. 貼上 query。
4. 點 **Run query**。

可以先試這個:

```promql
up{namespace="incident-lab"}
```

其他常用 query:

```promql
kube_pod_status_ready{namespace="incident-lab",condition="true"}
```

```promql
sum by (status) (rate(http_requests_total{namespace="incident-lab"}[5m]))
```

```promql
kube_deployment_status_replicas{namespace="incident-lab",deployment="podinfo"}
```

## 用 Explore 查 Logs

Metrics 告訴你「有問題」，logs 通常幫你看「為什麼」。這個 lab 的 logs 會進 Loki。

操作方式:

1. 點左側選單的 **Explore**。
2. datasource 選 **Loki**。
3. 查 lab namespace 的 logs:

```logql
{namespace="incident-lab"}
```

如果想縮小到 Podinfo，可以試:

```logql
{namespace="incident-lab", app="podinfo"}
```

如果 `{namespace="incident-lab", app="podinfo"}` 沒有結果，就先用 `{namespace="incident-lab"}`，再從 Grafana 顯示的 label 或 log 內容裡看 pod 名稱。

常用 LogQL 篩選:

```logql
{namespace="incident-lab"} |= "500"
```

```logql
{namespace="incident-lab"} |= "ready"
```

```logql
{namespace="incident-lab"} |~ "error|fail|panic"
```

## 三個情境要看哪裡

### Readiness Failure

觸發:

```bash
scripts/trigger-readiness-failure.sh
```

Grafana 看:

- **Ready Replicas** 應該會下降。
- **Request Rate** 可能下降，因為沒有 Ready 的 Pod 可以接流量。
- Loki 可能會看到 readiness 或 health check 相關 logs。

Terminal 確認:

```bash
kubectl -n incident-lab get pods
kubectl -n incident-lab get endpoints podinfo
```

修復:

```bash
scripts/restore-readiness.sh
```

### High Error Rate

觸發:

```bash
scripts/generate-errors.sh
```

Grafana 看:

- **Request Rate** 應該會上升。
- **Error Ratio** 應該會上升。
- **Ready Replicas** 通常仍然健康。
- Loki 可以看到造成錯誤的 request。

常用 Loki query:

```logql
{namespace="incident-lab"} |= "500"
```

停止:

```text
Ctrl+C
```

### Pod Self-Healing

觸發:

```bash
scripts/trigger-pod-self-healing.sh
```

Grafana 看:

- **Ready Replicas** 可能短暫下降，然後恢復。
- **Pod Restarts** 不一定會增加，因為刪掉 Pod 跟 container crash restart 不完全一樣。
- Loki 可能看到舊 Pod 和新 Pod 的 logs。

Terminal 觀察:

```bash
kubectl -n incident-lab get pods -w
```

## 一個簡單排查流程

遇到問題時可以照這個順序:

1. 先看 **Ready Replicas**，確認 Kubernetes 是否還認為服務可用。
2. 再看 **Request Rate**，確認是否有流量。
3. 再看 **Error Ratio**，確認 app 是否正在回錯誤。
4. 打開 **Explore > Loki**，用 `{namespace="incident-lab"}` 查同一段時間的 logs。
5. 回到 terminal 用 `kubectl get pods`、`kubectl describe`、`kubectl logs` 交叉確認。

核心想法是: 用 Grafana 發現症狀，用 Prometheus metrics 和 Loki logs 解釋發生了什麼。

## 常見問題

### 打不開 Grafana

重新開 port-forward:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

然後打開:

```text
http://localhost:3000
```

完整排查流程可以看:

```text
docs/troubleshooting.md
```

### 找不到 Dashboard

重新套用 dashboard:

```bash
kubectl apply -f monitoring/dashboards/podinfo-overview-dashboard.yaml
```

### Loki 查不到 Logs

先確認 Promtail 有跑:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=promtail
kubectl -n monitoring logs daemonset/promtail --tail=100
```
