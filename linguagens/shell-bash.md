# Shell / Bash — Cartão de Segurança

> Shell scripts são frequentemente colas entre componentes. Variáveis não quotadas, `eval`, e injeção via paths/filenames com espaços ou caracteres especiais são as classes principais.

## Idiomas inseguros

### Variáveis não quotadas
```bash
# BAD — word splitting + glob expansion
file=$1
rm $file              # se file = "a b" → rm a b
cp $file /backup      # se file = "*.txt" → expande

# GOOD
rm "$file"
cp "$file" /backup
```

### `eval` com input
```bash
# BAD
cmd=$1
eval "$cmd"

# GOOD — nunca eval com input
# Se precisas de "comando configurável", usa allowlist:
case "$1" in
    backup)  do_backup ;;
    restore) do_restore ;;
    *)       echo "unknown"; exit 1 ;;
esac
```

### Comand substitution com `$()` em ambientes não confiáveis
```bash
# BAD — input no path passado para tool
result=$(grep "$pattern" "$file")  # se file = "; rm -rf /" → ainda OK porque está quotado

# Mas se constrói comando dinamicamente:
cmd="grep $pattern $file"
$cmd  # OUCH
```

### Pipes sem `set -o pipefail`
```bash
# BAD — pipeline pode falhar silenciosamente
curl https://api/x | jq '.data'
# Se curl falha, jq processa nada e exit 0

# GOOD
set -euo pipefail
curl https://api/x | jq '.data'
```

### `set -e` não é suficiente
```bash
# set -e pára em erro, mas tem buracos:
# - dentro de pipes (sem pipefail)
# - dentro de `if`, `&&`, `||`
# - em subshells

# Usar sempre:
set -euo pipefail
IFS=$'\n\t'   # word splitting só por newline e tab
```

### Globbing perigoso
```bash
# BAD — atacante cria ficheiro com nome "-rf"
rm *

# GOOD — usar `--` para terminar opções
rm -- *
# ou
find . -maxdepth 1 -type f -print0 | xargs -0 rm
```

### `cd` sem check de retorno
```bash
# BAD
cd /tmp/build
rm -rf *  # se cd falha, está em /tmp anterior — apaga aleatoriamente

# GOOD
cd /tmp/build || exit 1
rm -rf -- *
# ou
(cd /tmp/build && rm -rf -- *)  # subshell, se falha não afeta
```

### Temp files inseguros
```bash
# BAD — race condition
TMP=/tmp/foo.$$
echo data > "$TMP"  # atacante criou symlink antes

# GOOD
TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT
```

### Source de ficheiros não confiáveis
```bash
# BAD
source "$config_file"  # se config_file modificável → RCE

# GOOD — parse explícito (jq, awk, etc.)
api_key=$(jq -r '.api_key' "$config_file")
```

### `read` sem `-r`
```bash
# BAD — backslashes interpretados
read line

# GOOD
IFS= read -r line
```

### Curl pipe a shell
```bash
# CLÁSSICO MAU
curl https://example.com/install.sh | bash

# Marginalmente melhor
curl -sSL https://example.com/install.sh -o /tmp/install.sh
# inspecionar /tmp/install.sh
sha256sum /tmp/install.sh  # comparar com hash publicado
bash /tmp/install.sh
```

## Helpers seguros

| Necessidade | Use |
|---|---|
| Strict mode | `set -euo pipefail; IFS=$'\n\t'` |
| Temp file | `mktemp` |
| Random | `openssl rand -hex 32` |
| Hash compare | `[ "$(echo -n "$x" \| sha256sum)" = "$expected" ]` (não strict constant-time) |
| Quoted args | `"${var}"` sempre |
| Array de args | `cmd "${args[@]}"` |
| Allowlist | `case`/`if [[ "$x" == @(a\|b\|c) ]]` |
| Validation | regex match `[[ "$x" =~ ^[a-z0-9]+$ ]]` |

## Quoting cheat sheet

```bash
# Sempre quote variáveis
"$var"                  # expansão simples
"${var}"                # mais explícito
"${var:-default}"       # default se vazio
"${array[@]}"           # expande cada elemento como arg separado
"${!prefix*}"           # nomes de variáveis começando com prefix

# Nunca:
$var                    # word splitting + glob
${array[*]}             # junta com IFS
```

## Bash vs sh / dash

- `#!/bin/bash` permite features Bash-specific (`[[`, arrays, `=~`).
- `#!/bin/sh` é POSIX — em Debian/Ubuntu vai para `dash` (mais rigoroso).
- Scripts sysadmin podem rodar como qualquer dos dois — testar com ambos.

## Quick wins

- [ ] `set -euo pipefail` no topo de **todos** os scripts
- [ ] `IFS=$'\n\t'`
- [ ] Quote **todas** as variáveis: `"$var"` / `"${array[@]}"`
- [ ] Sem `eval` com input (usar `case` com allowlist)
- [ ] `--` antes de paths em comandos que aceitam flags
- [ ] `mktemp` para temp files (com `trap` para cleanup)
- [ ] `cd path || exit 1` sempre
- [ ] `read -r` sempre
- [ ] Validar input com regex strict no início do script
- [ ] `shellcheck` na CI sem warnings
- [ ] Não confiar em `PATH` herdado — usar paths absolutos para tools (`/usr/bin/curl`)
- [ ] `umask 077` para ficheiros sensíveis
- [ ] Nunca pipe `curl` direto para `bash` em production scripts
- [ ] Cuidar com IFS reset em fontes externas
- [ ] Drop privileges (`su`/`sudo -u`) se script corre como root mas faz user stuff
