# REST API com OpenAPI / Swagger — Profile de Segurança

## Deteção
- `openapi.yaml`/`openapi.json` ou `swagger.yaml`/`swagger.json`
- Anotações OpenAPI (`@OpenAPIDefinition`, `@OperationDescription`, etc.)

## Schema-driven security

OpenAPI permite **declarar** segurança no schema. Aproveitar isso:

```yaml
openapi: 3.1.0

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    apiKey:
      type: apiKey
      in: header
      name: X-API-Key

security:
  - bearerAuth: []  # default para todas as rotas

paths:
  /users:
    get:
      security: [{bearerAuth: []}]  # ou explicit
      responses:
        '200':
          content:
            application/json:
              schema: { $ref: '#/components/schemas/UserList' }

  /public/health:
    get:
      security: []  # explicitamente público
      responses:
        '200':
          content: ...
```

## Validação contract vs implementação

A spec deve corresponder ao código. Drift cria vulns invisíveis.

### Validação automática
- **Server:** middleware que valida request contra schema (express-openapi-validator, Connexion para Python, openapi-validator-go).
- **CI:** comparar spec com código gerado a partir do código (Spectral, openapi-diff).

### Padrões a verificar
- Endpoint na spec mas não implementado, ou inverso (shadow endpoints).
- Schema permite campos que código não esperava (mass assignment).
- `securitySchemes` definido mas não aplicado em endpoints.
- Responses documentadas vs reais (códigos, schemas).

## Schema — design seguro

### Inputs com strict validation
```yaml
components:
  schemas:
    CreateUser:
      type: object
      additionalProperties: false  # rejeita extra fields
      required: [name, email]
      properties:
        name: { type: string, minLength: 1, maxLength: 100 }
        email: { type: string, format: email, maxLength: 254 }
        role:
          type: string
          enum: [user, guest]  # admin NÃO disponível via API pública
```

### Outputs sem campos sensíveis
```yaml
UserPublic:
  type: object
  properties:
    id: { type: integer }
    name: { type: string }
    # SEM password_hash, SEM email (a menos que contexto justifique)
```

### Pagination obrigatória
```yaml
ListResponse:
  type: object
  properties:
    items:
      type: array
      items: { $ref: '#/components/schemas/Item' }
      maxItems: 100  # cap server-side
    total: { type: integer }
    page: { type: integer, minimum: 1 }
```

### Rate limit headers documentados
```yaml
responses:
  '200':
    headers:
      X-RateLimit-Limit: { schema: { type: integer } }
      X-RateLimit-Remaining: { schema: { type: integer } }
      X-RateLimit-Reset: { schema: { type: integer } }
  '429':
    description: Too Many Requests
    headers:
      Retry-After: { schema: { type: integer } }
```

## Versioning

```yaml
servers:
  - url: https://api.meusite.tld/v2
```

- Manter `v1` enquanto há clients, mas marcar como `deprecated: true`.
- Plano de sunset documentado.
- `Sunset` header HTTP (RFC 8594) para sinalizar deprecation.

## Common antipatterns

### `additionalProperties: true` ou ausente
- Mass assignment via campos extra.

### Sem `format` em strings
- `email`, `uri`, `uuid`, `date`, `date-time` ajudam a validar.

### Endpoints sem `security`
- Default herda do top-level, mas se top-level for `[]` → tudo público.

### Swagger UI em produção
```javascript
// Express
if (process.env.NODE_ENV !== 'production') {
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec));
}
```

### Specs em endpoints `/openapi.json` sem auth
- Expõe estrutura completa da API a varredores.

### `oneOf`/`anyOf` complexos
- Atacante explora ambiguidade. Preferir `discriminator` explícito.

### `description` com info sensível
- Exemplos com dados reais, paths internos, etc.

### Output schemas que incluem `password`, `internalNotes`
- Documentação de endpoint diz que devolve esses campos = spec confirma vuln.

## Helpers / tools

| Tool | Para |
|---|---|
| **Spectral** | Linting de OpenAPI |
| **openapi-diff** | Detect breaking changes |
| **express-openapi-validator** | Runtime validation (Node) |
| **connexion** | Python — validation + dispatch |
| **swagger-codegen** / **openapi-generator** | Gerar clients/server |
| **Schemathesis** | Property-based testing baseado em spec |
| **42Crunch** | API security audit |

## Quick wins

- [ ] OpenAPI 3.1+
- [ ] `securitySchemes` definido + aplicado em endpoints
- [ ] `additionalProperties: false` em todos os request bodies
- [ ] `format` em strings (email, uri, uuid, etc.)
- [ ] `minLength`/`maxLength` em strings
- [ ] `minimum`/`maximum` em números
- [ ] `enum` para campos com valores fixos
- [ ] Pagination com `maxItems`
- [ ] Rate limit headers documentados
- [ ] Spec validada por Spectral na CI
- [ ] Runtime validation de requests contra schema
- [ ] Swagger UI desativado em prod ou autenticado
- [ ] `/openapi.json` autenticado em prod
- [ ] Schemathesis ou similar para fuzzing baseado em spec
- [ ] Versioning + deprecation policy
- [ ] Output schemas sem campos sensíveis
