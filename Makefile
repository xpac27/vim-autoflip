.PHONY: test lint check

test:
	vim -Nu NONE -U NONE -i NONE -n -es -S test/run.vim

lint:
	vim -Nu NONE -U NONE -i NONE -n -es -S test/compile.vim

check: lint test

