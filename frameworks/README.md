# Frameworks — Profiles de Segurança

> Cada profile cobre o **delta específico do framework** sobre o cartão da linguagem. Auth, ORM/query builder, middleware, validation, helpers de segurança nativos.

## Quando carregar

A IA deteta o framework pelos manifests:

| Manifesto | Framework | Profile |
|---|---|---|
| `composer.json` + `wp-config.php` | WordPress | `web/php-wordpress.md` |
| `composer.json` + `artisan` | Laravel | `web/php-laravel.md` |
| `composer.json` + `bin/console` + `symfony/*` | Symfony | `web/php-symfony.md` |
| `package.json` + `express` | Express | `web/node-express.md` |
| `package.json` + `fastify` | Fastify | `web/node-fastify.md` |
| `package.json` + `@nestjs/core` | NestJS | `web/node-nestjs.md` |
| `package.json` + `next` | Next.js | `web/node-nextjs.md` |
| `package.json` + `nuxt` | Nuxt | `web/node-nuxt.md` |
| `package.json` + `@remix-run` | Remix | `web/node-remix.md` |
| `package.json` + `@sveltejs/kit` | SvelteKit | `web/node-sveltekit.md` |
| `package.json` + `@adonisjs/core` | AdonisJS | `web/node-adonisjs.md` |
| `package.json` + `react` (sem next/remix) | React standalone | `web/react-standalone.md` |
| `package.json` + `vue` (sem nuxt) | Vue 3 standalone | `web/vue-standalone.md` |
| `package.json` + `@angular/core` | Angular | `web/angular.md` |
| `package.json` + `astro` | Astro | `web/astro.md` |
| HTML com `hx-*` attributes | HTMX | `web/htmx.md` |
| `package.json` + `hono` | Hono | `runtime/hono.md` |
| `bun.lockb` | Bun runtime | `runtime/bun.md` |
| `deno.json` / `deno.lock` | Deno runtime | `runtime/deno.md` |
| `package.json` + `@trpc/server` | tRPC | `api/trpc.md` |
| `manage.py` + `django` em deps | Django | `web/python-django.md` |
| `requirements.txt` + `flask` | Flask | `web/python-flask.md` |
| `requirements.txt` + `fastapi` | FastAPI | `web/python-fastapi.md` |
| `pom.xml`/`build.gradle` + `spring-boot` | Spring Boot | `web/java-spring-boot.md` |
| `pom.xml`/`build.gradle` + `quarkus` | Quarkus | `web/java-quarkus.md` |
| `.csproj` + `Microsoft.AspNetCore.App` | ASP.NET Core | `web/dotnet-aspnet-core.md` |
| `.csproj` + `Microsoft.AspNetCore.Components` | Blazor | `web/dotnet-blazor.md` |
| `Gemfile` + `rails` | Rails | `web/ruby-rails.md` |
| `go.mod` + `gin`/`echo` | Gin/Echo | `web/go-gin-echo.md` |
| `mix.exs` + `phoenix` | Phoenix | `web/elixir-phoenix.md` |
| `Cargo.toml` + `actix-web`/`axum` | Actix/Axum | `web/rust-actix-axum.md` |
| `openapi.yaml`/`swagger.json` | REST com spec | `api/rest-openapi.md` |
| `apollo` em deps | Apollo GraphQL | `api/graphql-apollo.md` |
| `.proto` files + `grpc` | gRPC | `api/grpc.md` |

## Estrutura de cada profile

1. **Deteção** — como confirmar o framework
2. **Auth & AuthZ** — sistema de auth nativo + patterns
3. **ORM / Query patterns** — como o ORM se comporta
4. **Middleware / Pipeline** — order matters
5. **Common antipatterns** — bugs típicos do framework
6. **Helpers seguros nativos** — usar o que o framework já oferece
7. **Quick wins** — checklist específica
