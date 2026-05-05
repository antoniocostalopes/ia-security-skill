# Vue 3 (standalone) — Profile de Segurança

> Para apps Vue **sem** meta-framework (Vite+Vue puro). Para Nuxt ver `node-nuxt.md`.

## Deteção
- `package.json` com `vue` em deps **sem** `nuxt`
- `vite.config.ts` com `@vitejs/plugin-vue`

## Modelo de ameaça (SPA Vue)

Mesma situação que React standalone:
- Bundle JS público
- Backend é defesa real
- Tokens em cookies HttpOnly preferidos sobre localStorage
- Source maps off em prod

## XSS — antipatterns Vue

```vue
<!-- BAD — v-html com input do user -->
<template>
  <div v-html="userContent"></div>
</template>

<!-- GOOD — texto escapado por default -->
<template>
  <div>{{ userContent }}</div>
</template>

<!-- Se HTML rico for necessário, sanitizar -->
<template>
  <div v-html="sanitized"></div>
</template>
<script setup>
import DOMPurify from 'dompurify';
import { computed } from 'vue';
const props = defineProps(['userContent']);
const sanitized = computed(() => DOMPurify.sanitize(props.userContent));
</script>
```

```vue
<!-- BAD — :href com input não validado -->
<a :href="userUrl">link</a>  <!-- userUrl = "javascript:alert(1)" -->

<!-- GOOD -->
<a :href="safeUrl(userUrl)">link</a>
<script setup>
function safeUrl(url) {
  try {
    const u = new URL(url, window.location.origin);
    return ['http:', 'https:', 'mailto:'].includes(u.protocol) ? url : '#';
  } catch { return '#'; }
}
</script>
```

## Composables com state sensível

```javascript
// BAD — composable que expõe token reativamente
export function useAuth() {
  const token = ref(localStorage.getItem('token'));
  // Reactive ref — qualquer componente pode ler
  return { token };
}

// GOOD — manter token apenas em memória, sem persistência
export function useAuth() {
  const token = ref(null);
  // Login → setToken; Logout → clear
  // Backend faz cookie HttpOnly auth
  return { token, login, logout };
}
```

## Pinia (state management)

```javascript
// BAD — store com PII persistida
import { defineStore } from 'pinia';

export const useUserStore = defineStore('user', {
  state: () => ({
    email: '',
    password: '',  // !! nunca persistir
    token: '',     // !! XSS exfiltrate
  }),
  persist: true,  // persiste tudo em localStorage
});

// GOOD — só dados não-sensíveis
export const useUserStore = defineStore('user', {
  state: () => ({
    email: '',
    name: '',
  }),
  persist: { paths: ['email', 'name'] },  // explicit allowlist
});
```

## Vue Router

```javascript
// BAD — open redirect
router.push(route.query.next);

// GOOD — validar
const ALLOWED = ['/dashboard', '/profile'];
const next = route.query.next;
if (next && ALLOWED.includes(next)) router.push(next);
else router.push('/');
```

## Form validation

```vue
<!-- VeeValidate + Yup ou Zod -->
<script setup>
import { useForm } from 'vee-validate';
import { object, string } from 'yup';

const schema = object({
  email: string().email().required(),
  password: string().min(12).required(),
});

const { handleSubmit, errors } = useForm({ validationSchema: schema });
</script>
```

## Common antipatterns

### `v-html` sem sanitização
- XSS direto.

### Refs com password / PII em vue-devtools
- Vue DevTools (mesmo em prod se não disabled) mostra refs.

### Slots dinâmicos com input
- Pode injetar componentes.

### `compile()` (runtime template compilation) com input
- SSTI client-side.

### Watchers sem cleanup
- Memory leak; não é segurança direta mas degrada.

### `fetch` direto com tokens em headers
```javascript
// BAD
fetch('/api', { headers: { Authorization: 'Bearer ' + localStorage.getItem('token') } });
// Token em localStorage = XSS-exfiltratable

// GOOD — backend define cookie HttpOnly, fetch usa credentials: 'include'
fetch('/api', { credentials: 'include' });
```

## Quick wins

- [ ] Vue 3.4+
- [ ] `npm audit` sem Críticos
- [ ] `v-html` apenas com DOMPurify
- [ ] `:href` com `safeUrl` wrapper para input
- [ ] Pinia stores sem secrets persistidos
- [ ] VeeValidate / Vuelidate para forms
- [ ] Tokens em cookies HttpOnly (não localStorage)
- [ ] Vue Router: validar URLs em redirect
- [ ] `v-on` events sem `eval`-like patterns
- [ ] Source maps off em prod
- [ ] CSP no servidor
- [ ] DevTools off em prod
- [ ] Plus: ver `linguagens/javascript-typescript.md`
