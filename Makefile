.PHONY: console deploy monitoring port-forward stop-port-forward status alerts validate cleanup

console:
	scripts/run-console.sh

deploy:
	scripts/deploy-app.sh

monitoring:
	scripts/install-monitoring.sh

port-forward:
	scripts/port-forward.sh

stop-port-forward:
	scripts/stop-port-forward.sh

status:
	scripts/status.sh

alerts:
	scripts/show-alerts.sh

validate:
	scripts/validate.sh

cleanup:
	scripts/cleanup.sh
