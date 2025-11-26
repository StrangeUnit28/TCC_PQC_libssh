.PHONY: help test bench clean test-pqc

help:
	@echo "Comandos disponíveis:"
	@echo "  make test       - Executa todos os benchmarks"
	@echo "  make bench      - Alias para 'make test'"
	@echo "  make test-pqc   - Testa mensagem cifrada PQC"
	@echo "  make clean      - Remove resultados antigos"

test:
	@SKIP_CLEANUP_PROMPT=true ./run_all_benchmarks.sh

bench: test

test-pqc:
	@./test_pqc.sh

clean:
	@rm -rf benchmark_results/*
	@echo "Resultados removidos"
