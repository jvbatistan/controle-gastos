# Finch API

API Rails responsável por autenticação, cartões, categorias, transações, faturas, pagamentos, dashboard e classificação automática do Finch.

## Requisitos

- Ruby 3.2.6
- PostgreSQL
- Bundler

## Configuração local

Copie `.env.example` para `.env` e configure os dois shards writers e um banco descartável de teste:

```env
DATABASE_URL_DEVEL=postgresql://USER:PASSWORD@HOST:PORT/finch_development
DATABASE_URL=postgresql://USER:PASSWORD@HOST:PORT/finch_production
DATABASE_URL_TEST=postgresql://USER:PASSWORD@HOST:PORT/finch_test
```

`DATABASE_URL_DEVEL` representa o banco local com dados fictícios. `DATABASE_URL` representa o Supabase com dados reais. Em um processo Rails executado como `production`, configure também `DATABASE_URL_LOCAL` se o switch para um PostgreSQL local estiver disponível nessa topologia.

O ambiente de dados fica na sessão e começa sempre em `local`. Os pools `local` e `supabase` são criados no boot, mas a aplicação nunca altera variáveis de ambiente ou restabelece conexões durante uma request.

Após autenticação, `GET /api/data_environment` retorna apenas o ambiente, disponibilidade da conexão, compatibilidade do schema e permissão de troca. `POST /api/data_environment/switch` recebe `{ "environment": "local" | "supabase" }` e exige o header interno `X-Finch-Data-Environment-Switch: confirmed`. Uma troca válida encerra a autenticação, reinicia a sessão, grava o destino e exige novo login; falhas preservam o ambiente e o login atuais.

`DATABASE_URL_TEST` é obrigatória para qualquer boot com `RAILS_ENV=test` e precisa apontar para um banco exclusivo cujo nome contenha `test` como segmento, por exemplo `finch_test` ou `test_finch`. Se `DATABASE_URL_TEST_SUPABASE` for informada, ela passa pelo mesmo guard antes de qualquer conexão.

O boot de teste é interrompido antes de migrations ou limpeza quando:

- `DATABASE_URL_TEST` está ausente;
- o nome do banco não identifica claramente um banco de teste;
- uma URL de teste aponta para o mesmo host, porta e banco de `DATABASE_URL`, `DATABASE_URL_DEVEL`, `DATABASE_URL_DEVELOPMENT`, `DATABASE_URL_LOCAL` ou `DATABASE_URL_PRODUCTION`.

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

O ambiente development começa no shard local (`DATABASE_URL_DEVEL`), mantendo o Supabase (`DATABASE_URL`) disponível para troca autorizada pela interface:

```bash
bin/dev
```

Nunca reutilize uma URL de desenvolvimento ou produção em `DATABASE_URL_TEST`.

## Migrations por shard

Migrations nunca são executadas durante a troca de ambiente. Verifique e aplique cada destino explicitamente:

```bash
bin/rails db:migrate:status:local
bin/rails db:migrate:local
bin/rails db:migrate:status:supabase
bin/rails db:migrate:supabase
```

Confirme sempre o destino antes de migrar o Supabase. A API bloqueia o switch quando o conjunto de versões em `schema_migrations` não corresponde exatamente às migrations disponíveis no código.
