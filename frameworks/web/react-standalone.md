# React (standalone) — Profile de Segurança

> Para apps React **sem** meta-framework (Vite+React, Create React App, parcel+React, Webpack+React). Para Next.js/Remix ver profiles próprios. Para React Native ver `mobile/react-native.md`.

## Deteção
- `package.json` com `react` em deps **sem** `next`, `@remix-run`, `react-native`
- `index.html` com `<div id="root">`
- `src/App.jsx`/`tsx` ou `src/main.tsx` (Vite)

## Modelo de ameaça (SPA-only)

- **Tudo no bundle JS é público.** Secrets, API endpoints, lógica de UI — visível em `view-source`.
- **Backend é a única defesa real.** Validação client-side é só UX.
- **localStorage é vulnerável a XSS.** Para tokens preferir cookies HttpOnly + Secure.
- **Build artifacts**: source maps em prod = código original visível.

## XSS — antipatterns React

```jsx
// BAD — dangerouslySetInnerHTML com input do user
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// GOOD — sanitizar com DOMPurify
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userContent) }} />

// MELHOR — usar texto escapado
<div>{userContent}</div>
```

```jsx
// BAD — atributo `href` com input não validado
<a href={userUrl}>link</a>  // userUrl = "javascript:alert(1)" → XSS

// GOOD — validar scheme
function safeUrl(url) {
  try {
    const u = new URL(url, window.location.origin);
    return ['http:', 'https:', 'mailto:'].includes(u.protocol) ? url : '#';
  } catch { return '#'; }
}
<a href={safeUrl(userUrl)}>link</a>
```

```jsx
// BAD — `style` prop com input
<div style={{ background: userBg }} />  // pode injetar CSS

// GOOD — validar formato (cor, etc.)
const validColor = /^#[0-9a-f]{6}$/i.test(userBg) ? userBg : '#000';
<div style={{ background: validColor }} />
```

## Refs a DOM com PII

```jsx
// BAD — ref a input com password, depois logado/enviado
const passRef = useRef();
useEffect(() => {
  console.log('Pass entered:', passRef.current?.value);  // logs com PII
}, []);
```

## State management — secrets

```jsx
// BAD — token em localStorage
localStorage.setItem('token', jwt);
// Vulnerável a XSS — qualquer XSS extrai

// MELHOR — cookie HttpOnly definido pelo backend
// Frontend nunca toca no token

// Se mesmo precisares no client (SPAs sem backend control):
// - sessionStorage (perde em close)
// - In-memory state (perde em refresh, melhor)
const [token, setToken] = useState(null);
```

```jsx
// BAD — Redux store com PII serializada
const reducer = (state, action) => {
  if (action.type === 'LOGIN') {
    return { ...state, password: action.payload.password };  // !!
  }
};
// Redux DevTools Time Travel mostra password

// GOOD — nunca persistir secrets em store
```

## Hooks pitfalls

```jsx
// BAD — useEffect com secret no deps array → log no devtools
useEffect(() => {
  fetch('/api', { headers: { Authorization: `Bearer ${token}` } });
}, [token]);  // React DevTools mostra token

// GOOD — usar ref para secrets, não dep
const tokenRef = useRef(token);
useEffect(() => { tokenRef.current = token; }, [token]);
```

## React Router

```jsx
// BAD — open redirect
const params = new URLSearchParams(useLocation().search);
const next = params.get('next');
useEffect(() => { window.location.href = next; }, [next]);

// GOOD — validar
const ALLOWED = ['/dashboard', '/profile'];
useEffect(() => {
  if (next && ALLOWED.includes(next)) {
    navigate(next);
  }
}, [next]);
```

## Forms

```jsx
// BAD — sem validação client-side AND server-side
<input value={email} onChange={e => setEmail(e.target.value)} />
// Backend deve revalidar — client é só UX

// GOOD — validation com lib (react-hook-form + zod)
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const schema = z.object({
  email: z.string().email(),
  password: z.string().min(12),
});

const { register, handleSubmit } = useForm({ resolver: zodResolver(schema) });
```

## Build / deploy

```javascript
// vite.config.ts — production
export default defineConfig({
  build: {
    sourcemap: false,           // sem source maps em prod
    minify: 'terser',
    terserOptions: {
      compress: { drop_console: true },  // remove console.log
      mangle: { toplevel: true },
    },
  },
  define: {
    // Secrets NUNCA aqui — vão para o bundle
    // Use VITE_PUBLIC_* para coisas públicas (API URL, etc.)
  },
});
```

## Environment variables

```bash
# .env (Vite)
VITE_API_URL=https://api.meusite.tld   # OK — public
VITE_API_KEY=sk_live_xxx               # !! BAD — qualquer VITE_* vai para bundle

# Para CRA: REACT_APP_* tem mesma exposição
```

## Common antipatterns

### `eval` / `Function()` para configuração dinâmica
- RCE via XSS.

### Componentes que aceitam JSX como prop sem trust
```jsx
function Modal({ children }) { return <div>{children}</div>; }
// Caller pode passar componentes maliciosos se houver auth bypass
```

### `localStorage` para sessões
- XSS = roubo de sessão imediato.

### React DevTools acessíveis em produção
- Vê state inteiro. Build deve disable.

### CSP `'unsafe-inline'` permitido
- React por default não precisa em scripts (usa nonces se SSR).

### `target="_blank"` sem `rel="noopener noreferrer"`
- Tab nabbing.

```jsx
<a href={url} target="_blank" rel="noopener noreferrer">link</a>
```

### URLs com tokens
- Tokens em query strings → referrer leak, browser history, logs.

## Quick wins

- [ ] React 18+
- [ ] `npm audit` sem Críticos
- [ ] `dangerouslySetInnerHTML` apenas com DOMPurify
- [ ] `safeUrl` wrapper para todos os hrefs com input
- [ ] Validação com Zod + react-hook-form
- [ ] Tokens em cookies HttpOnly do backend (não localStorage)
- [ ] Source maps **off** em production build
- [ ] `console.log` removido em production
- [ ] Sem secrets em `VITE_*` / `REACT_APP_*` env vars
- [ ] `target="_blank"` sempre com `rel="noopener noreferrer"`
- [ ] CSP definida no servidor que serve o HTML
- [ ] React DevTools desativados em produção (automático em build minified)
- [ ] State management sem secrets persistidos
- [ ] React Router: validar next/redirect URLs
- [ ] Plus: ver `linguagens/javascript-typescript.md`
