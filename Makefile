.PHONY: test lint integration check

test:
	vim -Nu NONE -U NONE -i NONE -n -es -S test/run.vim

lint:
	vim -Nu NONE -U NONE -i NONE -n -es -S test/compile.vim

integration:
	bash test/run-integration.sh

check: lint test
