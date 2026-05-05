# GraphQL — Cartão de Segurança

> Já há módulo `analises/23-api-modernas.md` com a base. Este cartão é o cheat-sheet específico.

## Padrões perigosos

### Introspection em produção
```javascript
// Apollo
new ApolloServer({
  typeDefs, resolvers,
  introspection: process.env.NODE_ENV !== 'production',
});
```

### Query depth
```javascript
const depthLimit = require('graphql-depth-limit');
new ApolloServer({
  validationRules: [depthLimit(7)],
});
```

### Query complexity / cost analysis
```javascript
const costAnalysis = require('graphql-cost-analysis');
new ApolloServer({
  validationRules: [
    costAnalysis({
      maximumCost: 1000,
      defaultCost: 1,
      variables: req.body.variables,
    }),
  ],
});
```

### Field-level authorization
```javascript
// BAD — auth só na query top-level
const resolvers = {
  Query: {
    user: (_, { id }, ctx) => {
      requireAuth(ctx);
      return getUser(id);
    },
  },
};
// User type devolve ssn, email — qualquer um autenticado vê tudo

// GOOD — auth por field
const resolvers = {
  User: {
    ssn: (parent, _, ctx) => {
      if (ctx.user.id !== parent.id && !ctx.user.isAdmin) return null;
      return parent.ssn;
    },
    email: (parent, _, ctx) => {
      if (ctx.user.id !== parent.id) return null;
      return parent.email;
    },
  },
};
```

### Mutation input com mass assignment
```graphql
# BAD
input UpdateUserInput {
  name: String
  email: String
  role: Role  # !! atacante pode promover
  isActive: Boolean
}
mutation { updateUser(id: 1, input: { name: "x", role: ADMIN }) }

# GOOD — inputs separados por contexto
input UpdateUserSelfInput {
  name: String
  bio: String
}
input UpdateUserAdminInput {
  name: String
  role: Role
  isActive: Boolean
}

type Mutation {
  updateMyProfile(input: UpdateUserSelfInput!): User
  adminUpdateUser(id: ID!, input: UpdateUserAdminInput!): User
}
```

### Batching attacks
```graphql
# Atacante envia 1000 mutations num só request
mutation {
  m1: login(email: "a@b.com", password: "1") { ok }
  m2: login(email: "a@b.com", password: "2") { ok }
  m3: login(email: "a@b.com", password: "3") { ok }
  # ... ×1000 — bypassa rate limit por request
}
```

Mitigação: limitar **operations** por request, não só requests por minute.

```javascript
// Apollo Server plugin
const operationLimit = {
  requestDidStart: () => ({
    didResolveOperation({ document }) {
      const operations = document.definitions
        .filter(d => d.kind === 'OperationDefinition')
        .reduce((sum, op) => sum + op.selectionSet.selections.length, 0);
      if (operations > 50) throw new Error('Too many operations');
    },
  }),
};
```

### Aliases para amplificar
```graphql
{
  a: user(id: 1) { name }
  b: user(id: 1) { name }
  c: user(id: 1) { name }
  # ...x10000 — DoS por DB load
}
```

Mitigação: cost analysis (cada field tem custo, total < limit).

### Error message leakage
```javascript
// BAD — devolve stack trace, paths
new ApolloServer({
  formatError: (err) => err,
});

// GOOD — em produção, sanitizar
new ApolloServer({
  formatError: (err) => {
    if (process.env.NODE_ENV === 'production') {
      // expor só erros explicitamente marcados
      if (err.extensions?.code === 'BAD_USER_INPUT' ||
          err.extensions?.code === 'UNAUTHENTICATED') {
        return err;
      }
      console.error(err);  // log internamente
      return new Error('Internal server error');
    }
    return err;
  },
});
```

### N+1 queries
- Não é segurança direta, mas amplifica DoS.
- Usar DataLoader ou similar para batch.

### Subscriptions sem auth
```javascript
// BAD
new ApolloServer({
  subscriptions: { onConnect: () => true },
});

// GOOD
new ApolloServer({
  subscriptions: {
    onConnect: (params) => {
      const user = verifyToken(params.authToken);
      if (!user) throw new Error('Unauthenticated');
      return { user };
    },
  },
});
```

### Persisted queries
- Allowlist de queries pré-aprovadas, identificadas por hash.
- Cliente envia só hash, server resolve.
- Bloqueia ataques arbitrários (atacante só pode chamar queries permitidas).

```javascript
// Apollo APQ + persisted queries
import { createPersistedQueryLink } from '@apollo/client/link/persisted-queries';
const link = createPersistedQueryLink({ sha256 });
```

### Federation / Gateway specific
- Subgraphs devem validar auth em cada query (gateway pode falhar a propagar).
- `_entities` resolver é frequentemente esquecido sem auth.

## Resolvers — padrões

```javascript
// Wrapper de auth
const requireAuth = (resolver) => (parent, args, ctx, info) => {
  if (!ctx.user) throw new AuthenticationError('Login required');
  return resolver(parent, args, ctx, info);
};

const requireRole = (role, resolver) => (parent, args, ctx, info) => {
  if (!ctx.user || ctx.user.role !== role) throw new ForbiddenError();
  return resolver(parent, args, ctx, info);
};

const resolvers = {
  Mutation: {
    createPost: requireAuth(async (_, { input }, ctx) => { ... }),
    deleteUser: requireRole('ADMIN', async (_, { id }) => { ... }),
  },
};
```

## Schema design

### Avoid leaking enumerations
```graphql
# BAD — devolve { user: null } para IDs não existentes vs erro para IDs existentes mas sem permissão
# atacante distingue → enumeration

# GOOD — sempre devolver mesma resposta para "não existe" e "sem permissão"
type Query {
  user(id: ID!): User  # devolve null em ambos os casos, não erro
}
```

### IDs opacos (não sequenciais)
```graphql
# BAD — IDs sequenciais permitem scrape
type User { id: ID! }  # 1, 2, 3...

# GOOD — UUIDs
type User { id: ID! }  # "550e8400-e29b-..."
# Ou Relay-style global IDs (base64 de "User:123")
```

## Quick wins

- [ ] Introspection desativado em produção
- [ ] `depthLimit(7)` ou similar
- [ ] Cost analysis com `maximumCost` adequado
- [ ] Operations por request limitadas
- [ ] Field-level auth em campos sensíveis
- [ ] DTOs/inputs separados por contexto (admin vs user)
- [ ] DataLoader para evitar N+1
- [ ] Error sanitization em produção
- [ ] Subscriptions com auth no `onConnect`
- [ ] Persisted queries em produção (idealmente)
- [ ] Mesma resposta para "não existe" e "sem permissão" em queries
- [ ] IDs opacos (UUID/Relay) em vez de sequenciais
- [ ] Logging estruturado de queries com user, duration, complexity
- [ ] Rate limit por user (não só por IP)
