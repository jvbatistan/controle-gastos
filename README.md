# Finch API

API Rails responsável por autenticação, cartões, categorias, transações, faturas, pagamentos, dashboard e classificação automática do Finch.

## Requisitos

- Ruby 3.2.6
- PostgreSQL
- Bundler

## Configuração local

Copie `.env.example` para `.env` e configure URLs diferentes para desenvolvimento e teste:

```env
DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/finch_development
DATABASE_URL_TEST=postgresql://USER:PASSWORD@HOST:PORT/finch_test
```

`DATABASE_URL_TEST` é obrigatória para qualquer boot com `RAILS_ENV=test` e precisa apontar para um banco exclusivo cujo nome contenha `test` como segmento, por exemplo `finch_test` ou `test_finch`.

O boot de teste é interrompido antes de migrations ou limpeza quando:

- `DATABASE_URL_TEST` está ausente;
- o nome do banco não identifica claramente um banco de teste;
- ela aponta para o mesmo host, porta e banco de `DATABASE_URL`, `DATABASE_URL_DEVEL`, `DATABASE_URL_DEVELOPMENT` ou `DATABASE_URL_PRODUCTION`.

Credenciais e parâmetros de query diferentes não tornam o mesmo banco seguro para testes.

## Instalação

```bash
bin/setup
```

O script prepara apenas o ambiente de desenvolvimento. A criação/preparação do banco de teste deve ser feita explicitamente depois de conferir `DATABASE_URL_TEST`.

## Testes

Confira primeiro se a URL de teste aponta para um banco descartável e execute:

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
```

O guard de segurança pode ser testado isoladamente, sem carregar Rails ou conectar ao PostgreSQL:

```bash
bundle exec rspec spec/lib/test_database_safety_spec.rb
```

## Desenvolvimento

O ambiente development continua usando somente `DATABASE_URL`:

```bash
bin/dev
```

Nunca reutilize uma URL de desenvolvimento ou produção em `DATABASE_URL_TEST`.
