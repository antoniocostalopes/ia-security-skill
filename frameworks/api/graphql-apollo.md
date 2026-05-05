# GraphQL com Apollo — Profile de Segurança

> Já existe `analises/23-api-modernas.md` (overview) e `linguagens/graphql.md` (cheat-sheet). Este profile foca em **Apollo Server / Apollo Client** especificamente.

## Deteção
- `package.json` com `@apollo/server`, `apollo-server-express`, `apollo-server-fastify`
- `@apollo/client` no frontend

## Setup seguro — Apollo Server v4

```javascript
import { ApolloServer } from '@apollo/server';
import { ApolloServerPluginLandingPageDisabled } from '@apollo/server/plugin/disabled';
import depthLimit from 'graphql-depth-limit';
import costAnalysis from 'graphql-cost-analysis';

const server = new ApolloServer({
  typeDefs,
  resolvers,
  introspection: process.env.NODE_ENV !== 'production',
  validationRules: [
    depthLimit(7),
    costAnalysis({ maximumCost: 1000 }),
  ],
  plugins: [
    process.env.NODE_ENV === 'production'
      ? ApolloServerPluginLandingPageDisabled()
      : null,
    {
      requestDidStart: () => ({
        async willSendResponse({ response }) {
          // Strip sensitive errors em prod
          if (process.env.NODE_ENV === 'production') {
            response.body.singleResult.errors?.forEach(err => {
              if (!err.extensions?.code?.startsWith('USER_')) {
                err.message = 'Internal error';
                delete err.path;
                delete err.extensions?.stacktrace;
              }
            });
          }
        },
      }),
    },
  ].filter(Boolean),
  formatError: (formattedError, error) => {
    console.error(error);  // log internamente
    return formattedError;  // já sanitizado pelo plugin acima
  },
});
```

## Persisted queries

Pre-aprovar queries (cliente envia hash, server resolve):

```javascript
// Apollo Server APQ
import { ApolloServer } from '@apollo/server';
import { InMemoryLRUCache } from '@apollo/utils.keyvaluecache';

new ApolloServer({
  persistedQueries: {
    cache: new InMemoryLRUCache(),
    ttl: 900,  // 15 min
  },
});

// Cliente
import { createPersistedQueryLink } from '@apollo/client/link/persisted-queries';
import { sha256 } from 'crypto-hash';

const persistedLink = createPersistedQueryLink({ sha256 });
```

Em produção, idealmente **só** persisted queries (allowlist):
```javascript
// Bloqueia queries não pre-aprovadas
plugins: [{
  requestDidStart: async () => ({
    async didResolveOperation({ request, document }) {
      if (!request.extensions?.persistedQuery) {
        throw new Error('Only persisted queries allowed');
      }
    },
  }),
}],
```

## Auth context

```javascript
const server = new ApolloServer({ /* ... */ });

await startStandaloneServer(server, {
  context: async ({ req }) => {
    const token = req.headers.authorization?.replace('Bearer ', '');
    const user = token ? await verifyToken(token) : null;
    return { user, dataloaders: createDataLoaders() };
  },
});
```

## Resolvers com auth

```javascript
import { GraphQLError } from 'graphql';

function requireAuth(ctx) {
  if (!ctx.user) {
    throw new GraphQLError('Unauthenticated', {
      extensions: { code: 'USER_UNAUTHENTICATED' },
    });
  }
  return ctx.user;
}

function requireRole(role, ctx) {
  const user = requireAuth(ctx);
  if (user.role !== role) {
    throw new GraphQLError('Forbidden', {
      extensions: { code: 'USER_FORBIDDEN' },
    });
  }
  return user;
}

const resolvers = {
  Query: {
    user: async (_, { id }, ctx) => {
      requireAuth(ctx);
      return ctx.dataloaders.user.load(id);
    },
    adminAllUsers: async (_, __, ctx) => {
      requireRole('admin', ctx);
      return ctx.dataloaders.allUsers.load();
    },
  },
};
```

## DataLoader (anti N+1 + DoS)

```javascript
import DataLoader from 'dataloader';

function createDataLoaders() {
  return {
    user: new DataLoader(async (ids) => {
      const users = await db.user.findMany({ where: { id: { in: ids } } });
      return ids.map(id => users.find(u => u.id === id));
    }),
  };
}
```

## Operation limits (anti batching attack)

```javascript
const operationLimitPlugin = {
  async requestDidStart() {
    return {
      async didResolveOperation({ document }) {
        const totalSelections = countSelections(document);
        if (totalSelections > 50) {
          throw new GraphQLError('Too many operations');
        }
      },
    };
  },
};
```

## Field-level auth via diretivas

```graphql
directive @auth(requires: Role!) on FIELD_DEFINITION

enum Role { USER ADMIN }

type User {
  id: ID!
  name: String
  email: String @auth(requires: USER)  # só o próprio
  ssn: String @auth(requires: ADMIN)   # só admin
}
```

```javascript
import { mapSchema, getDirective, MapperKind } from '@graphql-tools/utils';

function authDirectiveTransformer(schema, directiveName = 'auth') {
  return mapSchema(schema, {
    [MapperKind.OBJECT_FIELD]: (fieldConfig) => {
      const authDirective = getDirective(schema, fieldConfig, directiveName)?.[0];
      if (authDirective) {
        const { resolve = defaultFieldResolver } = fieldConfig;
        fieldConfig.resolve = function (source, args, context, info) {
          if (!hasRole(context.user, authDirective.requires)) {
            throw new GraphQLError('Forbidden', { extensions: { code: 'USER_FORBIDDEN' } });
          }
          return resolve(source, args, context, info);
        };
      }
      return fieldConfig;
    },
  });
}
```

## Quick wins

- [ ] Apollo Server 4+
- [ ] Introspection desativado em prod
- [ ] `depthLimit` (5-7)
- [ ] `costAnalysis` com maximum cost
- [ ] Operation count limit (anti batching)
- [ ] Persisted queries em produção (idealmente exclusivo)
- [ ] Field-level auth via diretivas ou resolvers
- [ ] DataLoader para evitar N+1
- [ ] Error sanitization em produção (`USER_*` codes expostos, resto genérico)
- [ ] Apollo Studio Sandbox / GraphQL Playground desativados em prod
- [ ] Rate limit por user (não só por IP)
- [ ] Subscriptions com auth no `onConnect`
- [ ] Mutations com inputs separados por contexto (admin vs user)
- [ ] IDs opacos (UUID/Relay global IDs) em vez de sequenciais
