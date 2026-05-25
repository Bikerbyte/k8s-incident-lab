.PHONY: console deploy monitoring port-forward stop-port-forward status alerts validate cleanup

console:
	scripts/lab.sh console

deploy:
	scripts/lab.sh deploy

monitoring:
	scripts/lab.sh monitoring

port-forward:
	scripts/lab.sh access

stop-port-forward:
	scripts/lab.sh stop-access

status:
	scripts/lab.sh status

alerts:
	scripts/lab.sh alerts

validate:
	scripts/lab.sh validate

cleanup:
	scripts/lab.sh cleanup
